import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import '../models/additional_document.dart';
import '../services/api_client.dart';
import '../utils/api_config.dart';

class AdditionalDocumentsService {
  final ApiClient _apiClient = ApiClient();

  /// Find the lead for the authenticated user by email/phone.
  /// JHipster GET /api/leads returns a paginated list; filter client-side by email.
  Future<Map<String, dynamic>?> getLeadByUser(
    String email, {
    String? phone,
  }) async {
    try {
      final normalizedEmail = email.toLowerCase().trim();
      final normalizedPhone = phone?.trim();

      final response = await _apiClient.get(
        ApiConfig.leadsEndpoint,
        queryParameters: {'size': '50', 'sort': 'createdAt,desc'},
      );

      if (response.statusCode == 200) {
        final list = response.data as List<dynamic>;
        final phoneDigits = _digitsOnly(normalizedPhone);

        for (final item in list) {
          if (item is! Map) continue;
          final lead = Map<String, dynamic>.from(item);
          final leadEmail = (lead['email'] as String? ?? '').toLowerCase().trim();
          final leadPhone = (lead['phone'] as String? ?? '').trim();

          if (leadEmail.isNotEmpty && leadEmail == normalizedEmail) return _normalizeLead(lead);
          if (phoneDigits.isNotEmpty) {
            final leadDigits = _digitsOnly(leadPhone);
            if (leadDigits.isNotEmpty &&
                (leadDigits == phoneDigits || leadDigits.endsWith(phoneDigits) || phoneDigits.endsWith(leadDigits))) {
              return _normalizeLead(lead);
            }
          }
        }
      } else if (response.statusCode == 401) {
        throw Exception('Authentication required. Please log in again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied.');
      }

      if (kDebugMode) print('No lead found for $normalizedEmail');
      return null;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 401) throw Exception('Authentication required. Please log in again.');
      if (statusCode == 403) throw Exception('Access denied.');
      throw Exception('Network error. Please check your connection and try again.');
    } catch (e) {
      if (e.toString().contains('Access denied') || e.toString().contains('Authentication')) rethrow;
      throw Exception('Failed to get lead information. Please try again later.');
    }
  }

  /// Get lead by ID — JHipster GET /api/leads/{id}.
  Future<Map<String, dynamic>> getLead(String leadId) async {
    try {
      final response = await _apiClient.get('${ApiConfig.leadsEndpoint}/$leadId');
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      throw Exception('Lead not found');
    } catch (e) {
      throw Exception('Failed to get lead: $e');
    }
  }

  /// Get documents uploaded for a lead — JHipster GET /api/lead-documents?leadId.equals={id}.
  Future<List<UploadedDocument>> getLeadDocuments(String leadId) async {
    try {
      final response = await _apiClient.get(
        ApiConfig.leadDocumentsEndpoint,
        queryParameters: {'leadId.equals': leadId, 'size': '100', 'sort': 'uploadedAt,desc'},
      );

      if (response.statusCode == 200) {
        final list = response.data as List<dynamic>;
        return list
            .map((item) {
              try {
                return UploadedDocument.fromJson(_jhipsterDocToLegacy(item as Map<String, dynamic>));
              } catch (e) {
                if (kDebugMode) print('Error parsing document: $e');
                return null;
              }
            })
            .whereType<UploadedDocument>()
            .toList();
      }

      return [];
    } catch (e) {
      if (kDebugMode) print('Error in getLeadDocuments: $e');
      throw Exception('Failed to get documents: $e');
    }
  }

  /// Backward-compatible wrapper used by legacy screens.
  Future<List<UploadedDocument>> getUserDocuments(String leadId) {
    return getLeadDocuments(leadId);
  }

  /// DELETE /api/lead-documents/:id — used to replace a regenerated summary PDF without duplicates.
  Future<void> deleteLeadDocument(String documentId) async {
    final id = documentId.trim();
    if (id.isEmpty) return;
    try {
      await _apiClient.delete('${ApiConfig.leadDocumentsEndpoint}/$id');
    } on DioException catch (e) {
      if (kDebugMode) {
        print('deleteLeadDocument failed: ${e.response?.statusCode} $e');
      }
      rethrow;
    }
  }

  /// Removes existing rows whose `documentKey` matches [documentKey] (Flutter upload type string).
  Future<void> removeLeadDocumentsWithDocumentKey(String leadId, String documentKey) async {
    try {
      final docs = await getLeadDocuments(leadId);
      for (final d in docs) {
        if (leadDocumentTypeMatches(d.documentType, documentKey)) {
          try {
            await deleteLeadDocument(d.id);
          } catch (_) {
            // Best-effort; continue so a fresh upload can still proceed.
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('removeLeadDocumentsWithDocumentKey: $e');
    }
  }

  /// Upload an additional document — JHipster POST /api/lead-documents (multipart).
  Future<Map<String, dynamic>> uploadAdditionalDocument({
    required String filePath,
    required String fileName,
    required String documentType,
    required String leadId,
    List<int>? fileBytes,
    /// Shown in CRM / lists (e.g. same as rejected doc + " · Reuploaded"). Backend uses this instead of raw filename when set.
    String? displayName,
  }) async {
    try {
      MultipartFile multipartFile;

      if (kIsWeb) {
        if (fileBytes == null) throw Exception('File bytes required for web upload');
        final contentType = _inferContentType(fileName);
        multipartFile = MultipartFile.fromBytes(
          fileBytes,
          filename: fileName,
          contentType: DioMediaType.parse(contentType),
        );
      } else {
        multipartFile = await MultipartFile.fromFile(filePath, filename: fileName);
      }

      final formData = FormData.fromMap({
        'file': multipartFile,
        'documentType': documentType,
        'leadId': leadId,
        if (displayName != null && displayName.trim().isNotEmpty) 'displayName': displayName.trim(),
      });

      final response = await _apiClient.post(
        ApiConfig.leadDocumentsUploadEndpoint,
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data as Map);
      }

      throw Exception('Failed to upload document');
    } catch (e) {
      throw Exception('Failed to upload document: $e');
    }
  }

  static String _digitsOnly(String? s) => (s ?? '').replaceAll(RegExp(r'\D'), '');

  /// Normalize JHipster lead map so id is always a String (JHipster returns int).
  static Map<String, dynamic> _normalizeLead(Map<String, dynamic> lead) {
    return {...lead, 'id': lead['id']?.toString() ?? ''};
  }

  /// Convert JHipster LeadDocumentDTO shape to the legacy shape UploadedDocument.fromJson expects.
  static Map<String, dynamic> _jhipsterDocToLegacy(Map<String, dynamic> doc) {
    final docType = doc['documentType'];
    final docTypeStr = docType == null ? '' : docType.toString();
    final docKeyRaw = doc['documentKey'] ?? doc['document_key'];
    final docKeyStr = docKeyRaw == null ? '' : docKeyRaw.toString().trim();
    final folderStr =
        docKeyStr.isNotEmpty ? docKeyStr : docTypeStr;
    final statusRaw = doc['status'];
    final statusStr = statusRaw == null ? 'pending' : statusRaw.toString();
    return {
      'id': doc['id']?.toString() ?? '',
      'name': doc['name'] ?? doc['documentName'] ?? doc['fileName'] ?? '',
      'folder': folderStr,
      'category': folderStr,
      'status': statusStr.toLowerCase(),
      'url': doc['fileUrl'] ?? doc['url'] ?? '',
      'uploadedAt': doc['uploadedAt'] ?? doc['createdAt'] ?? '',
      'size': doc['fileSize'] == null ? '' : doc['fileSize'].toString(),
    };
  }

  static String _inferContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    return 'image/jpeg';
  }
}
