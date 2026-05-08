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

        for (final item in list) {
          if (item is! Map) continue;
          final lead = Map<String, dynamic>.from(item);
          final leadEmail = (lead['email'] as String? ?? '').toLowerCase().trim();
          final leadPhone = (lead['phone'] as String? ?? '').trim();

          if (leadEmail.isNotEmpty && leadEmail == normalizedEmail) return _normalizeLead(lead);
          if (normalizedPhone != null && leadPhone.isNotEmpty && leadPhone == normalizedPhone) return _normalizeLead(lead);
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

  /// Get documents uploaded for a lead — JHipster GET /api/lead-documents?leadId={id}.
  Future<List<UploadedDocument>> getUserDocuments(String userId) async {
    try {
      final response = await _apiClient.get(
        ApiConfig.leadDocumentsEndpoint,
        queryParameters: {'leadId.equals': userId, 'size': '100'},
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
      if (kDebugMode) print('Error in getUserDocuments: $e');
      throw Exception('Failed to get documents: $e');
    }
  }

  /// Upload an additional document — JHipster POST /api/lead-documents (multipart).
  Future<Map<String, dynamic>> uploadAdditionalDocument({
    required String filePath,
    required String fileName,
    required String documentType,
    required String leadId,
    List<int>? fileBytes,
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

  /// Normalize JHipster lead map so id is always a String (JHipster returns int).
  static Map<String, dynamic> _normalizeLead(Map<String, dynamic> lead) {
    return {...lead, 'id': lead['id']?.toString() ?? ''};
  }

  /// Convert JHipster LeadDocumentDTO shape to the legacy shape UploadedDocument.fromJson expects.
  static Map<String, dynamic> _jhipsterDocToLegacy(Map<String, dynamic> doc) {
    return {
      'id': doc['id']?.toString() ?? '',
      'name': doc['documentName'] ?? doc['fileName'] ?? '',
      'folder': doc['documentType'] ?? '',
      'category': doc['documentType'] ?? '',
      'status': (doc['status'] as String? ?? 'pending').toLowerCase(),
      'url': doc['fileUrl'] ?? doc['url'] ?? '',
      'created_at': doc['uploadedAt'] ?? doc['createdAt'] ?? '',
    };
  }

  static String _inferContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    return 'image/jpeg';
  }
}
