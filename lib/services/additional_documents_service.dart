import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import '../models/additional_document.dart';
import '../services/api_client.dart';
import '../utils/api_config.dart';

class AdditionalDocumentsService {
  final ApiClient _apiClient = ApiClient();

  /// Find the lead for the authenticated user by email/phone.
  ///
  /// Uses server-side JHipster criteria (`email.equals`, `phone.equals`) instead of
  /// scanning the newest 50 leads globally — otherwise the wrong lead is returned as
  /// the CRM grows and [additionalDocumentRequirements] never reach the app.
  Future<Map<String, dynamic>?> getLeadByUser(
    String email, {
    String? phone,
    String? preferredLeadId,
  }) async {
    try {
      final normalizedEmail = email.toLowerCase().trim();
      final phoneDigits = _digitsOnly(phone);
      final preferredId = preferredLeadId?.trim();

      if (preferredId != null && preferredId.isNotEmpty) {
        try {
          final byId = await getLead(preferredId);
          if (_leadMatchesUser(byId, normalizedEmail, phoneDigits)) {
            return _normalizeLead(byId);
          }
        } catch (_) {
          // Fall through to criteria search.
        }
      }

      // Server-authoritative resolution. Tolerates phone-format differences (country code,
      // formatting) that the exact `phone.equals`/`email.equals` criteria below cannot. Falls
      // back gracefully (returns null) on older backends without the endpoint.
      final mine = await getMyLead();
      if (mine != null) {
        if (kDebugMode) {
          print('Lead resolved via /api/leads/mine: id=${mine['id']}');
        }
        return mine;
      }

      final candidates = <Map<String, dynamic>>[];
      final seenIds = <String>{};

      void addCandidates(List<Map<String, dynamic>> rows) {
        for (final row in rows) {
          final id = row['id']?.toString() ?? '';
          if (id.isEmpty || seenIds.contains(id)) continue;
          if (!_leadMatchesUser(row, normalizedEmail, phoneDigits)) continue;
          seenIds.add(id);
          candidates.add(row);
        }
      }

      final useEmailFilter =
          normalizedEmail.isNotEmpty && !normalizedEmail.endsWith('@phone.local');
      if (useEmailFilter) {
        addCandidates(
          await _fetchLeadsByCriteria({'email.equals': normalizedEmail}),
        );
      }
      if (phoneDigits.isNotEmpty) {
        addCandidates(
          await _fetchLeadsByCriteria({'phone.equals': phoneDigits}),
        );
      }

      if (candidates.isEmpty) {
        if (kDebugMode) {
          print('No lead found for email=$normalizedEmail phone=$phoneDigits');
        }
        return null;
      }

      if (preferredId != null && preferredId.isNotEmpty) {
        for (final lead in candidates) {
          if (lead['id']?.toString() == preferredId) {
            return _normalizeLead(lead);
          }
        }
      }

      candidates.sort((a, b) {
        final aReq = _requirementsCount(a);
        final bReq = _requirementsCount(b);
        if (aReq != bReq) return bReq.compareTo(aReq);
        return _createdAtMillis(b).compareTo(_createdAtMillis(a));
      });

      return _normalizeLead(candidates.first);
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

  /// Resolve the current customer's lead via `GET /api/leads/mine` (server-authoritative).
  ///
  /// Returns null when the endpoint is unavailable (older backend) or no lead is linked, so callers
  /// can fall back to criteria search without surfacing an error.
  Future<Map<String, dynamic>?> getMyLead() async {
    try {
      final response = await _apiClient.get('${ApiConfig.leadsEndpoint}/mine');
      if (response.statusCode == 200 && response.data is Map) {
        return _normalizeLead(Map<String, dynamic>.from(response.data as Map));
      }
      return null;
    } on DioException catch (e) {
      // 404 = no lead linked yet; anything else = older backend or transient. Both fall back.
      if (kDebugMode) {
        print('getMyLead: ${e.response?.statusCode} (falling back to criteria search)');
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('getMyLead error: $e (falling back to criteria search)');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchLeadsByCriteria(
    Map<String, String> criteria,
  ) async {
    final response = await _apiClient.get(
      ApiConfig.leadsEndpoint,
      queryParameters: {
        'size': '20',
        'sort': 'createdAt,desc',
        ...criteria,
      },
    );
    if (kDebugMode) {
      final list = response.data is List ? (response.data as List).length : 0;
      print('Lead criteria $criteria -> status=${response.statusCode} count=$list');
    }

    if (response.statusCode == 401) {
      throw Exception('Authentication required. Please log in again.');
    }
    if (response.statusCode == 403) {
      throw Exception('Access denied.');
    }
    if (response.statusCode != 200) return [];

    final list = response.data as List<dynamic>;
    return list
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static bool _leadMatchesUser(
    Map<String, dynamic> lead,
    String normalizedEmail,
    String phoneDigits,
  ) {
    final leadEmail = (lead['email'] as String? ?? '').toLowerCase().trim();
    if (normalizedEmail.isNotEmpty &&
        !normalizedEmail.endsWith('@phone.local') &&
        leadEmail.isNotEmpty &&
        leadEmail == normalizedEmail) {
      return true;
    }
    if (phoneDigits.isEmpty) return false;
    final leadDigits = _digitsOnly(lead['phone'] as String?);
    if (leadDigits.isEmpty) return false;
    return leadDigits == phoneDigits ||
        leadDigits.endsWith(phoneDigits) ||
        phoneDigits.endsWith(leadDigits);
  }

  static int _requirementsCount(Map<String, dynamic> lead) {
    final raw = lead['additionalDocumentRequirements'] ??
        lead['additional_documents'] ??
        lead['additionalDocuments'];
    if (raw is List) return raw.length;
    return 0;
  }

  static int _createdAtMillis(Map<String, dynamic> lead) {
    final raw = lead['createdAt'];
    if (raw == null) return 0;
    return DateTime.tryParse(raw.toString())?.millisecondsSinceEpoch ?? 0;
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
    final req = lead['additionalDocumentRequirements'] ??
        lead['additional_documents'] ??
        lead['additionalDocuments'];
    return {
      ...lead,
      'id': lead['id']?.toString() ?? '',
      if (req is List)
        'additionalDocumentRequirements': List<dynamic>.from(req),
    };
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
