import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import '../models/additional_document.dart';
import '../services/api_client.dart';

class AdditionalDocumentsService {
  final ApiClient _apiClient = ApiClient();

  /// Get lead information including document requirements
  /// Only returns lead if it matches the authenticated user's email
  Future<Map<String, dynamic>> getLeadByEmail(String email) async {
    try {
      // Directly search for lead by email using the leads endpoint
      // Backend ensures users can only see their own lead (by email match)
      final normalizedEmail = email.toLowerCase().trim();
      
      final leadsResponse = await _apiClient.get(
        '/api/v1/leads',
        queryParameters: {
          'search': normalizedEmail,
          'limit': '10',
        },
      );

      if (leadsResponse.statusCode == 200) {
        final leadsData = leadsResponse.data;
        
        if (kDebugMode) {
          print('Leads API response: $leadsData');
        }
        
        if (leadsData is Map && leadsData['success'] == true) {
          final data = leadsData['data'];
          if (data is Map && data['leads'] != null) {
            final leads = data['leads'] as List;
            
            if (kDebugMode) {
              print('Found ${leads.length} leads in response');
            }
            
            // Find lead with matching email (case-insensitive)
            // Backend should already filter this, but we double-check for security
            for (var lead in leads) {
              if (lead is Map) {
                final leadEmail = (lead['email'] as String? ?? '').toLowerCase().trim();
                
                if (kDebugMode) {
                  print('Checking lead email: $leadEmail against: $normalizedEmail');
                }
                
                if (leadEmail == normalizedEmail) {
                  if (kDebugMode) {
                    print('Found matching lead: ${lead['id']}');
                  }
                  return lead as Map<String, dynamic>;
                }
              }
            }
          } else {
            if (kDebugMode) {
              print('Unexpected response structure: data or leads is null');
            }
          }
        } else {
          if (kDebugMode) {
            print('API response success is false or unexpected structure');
          }
        }
      } else if (leadsResponse.statusCode == 403) {
        throw Exception('Access denied. You can only view your own lead information.');
      } else if (leadsResponse.statusCode == 401) {
        throw Exception('Authentication required. Please log in again.');
      }

      // No matching lead found
      if (kDebugMode) {
        print('No lead found for email: $normalizedEmail');
      }
      throw Exception('Lead not found for your email address');
    } on DioException catch (e) {
      // Handle DioException (network errors, HTTP errors, etc.)
      String errorMessage;
      
      // Check for network/connection errors
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionError) {
        errorMessage = 'Unable to connect to server. Please check your internet connection and try again.';
      } else if (e.response != null) {
        // HTTP error response
        final statusCode = e.response!.statusCode;
        if (statusCode == 401) {
          errorMessage = 'Authentication required. Please log in again.';
        } else if (statusCode == 403) {
          errorMessage = 'Access denied. You can only view your own lead information.';
        } else if (statusCode == 404) {
          errorMessage = 'Service temporarily unavailable. Please try again later.';
        } else if (statusCode == 500) {
          errorMessage = 'Server error. Please try again later.';
        } else {
          // Try to extract error message from response
          final errorData = e.response?.data;
          if (errorData is Map && errorData['message'] != null) {
            errorMessage = errorData['message'].toString();
          } else {
            errorMessage = 'Failed to get lead information. Please try again later.';
          }
        }
      } else {
        // Other DioException
        errorMessage = 'Network error: ${e.message ?? "Please check your internet connection and try again."}';
      }
      
      throw Exception(errorMessage);
    } catch (e) {
      // Handle other exceptions
      final errorString = e.toString();
      
      // Preserve specific error messages
      if (errorString.contains('Access denied') || 
          errorString.contains('Authentication required') ||
          errorString.contains('Lead not found')) {
        rethrow;
      }
      
      // For unknown errors, include the original error message for debugging
      if (kDebugMode) {
        print('Error in getLeadByEmail: $e');
      }
      
      // Extract clean error message
      String errorMessage = errorString.replaceFirst('Exception: ', '');
      if (errorMessage.isEmpty || errorMessage == errorString) {
        errorMessage = 'Failed to get lead information. Please try again later.';
      }
      
      throw Exception(errorMessage);
    }
  }

  /// Get lead by ID
  Future<Map<String, dynamic>> getLead(String leadId) async {
    try {
      final response = await _apiClient.get('/api/v1/leads/$leadId');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true && data['data']?['lead'] != null) {
          return data['data']['lead'] as Map<String, dynamic>;
        }
      }
      throw Exception('Lead not found');
    } catch (e) {
      throw Exception('Failed to get lead: $e');
    }
  }

  /// Get user documents
  Future<List<UploadedDocument>> getUserDocuments(String userId) async {
    try {
      final response = await _apiClient.get('/api/v1/uploads/user/$userId');

      print('=== getUserDocuments API Response ===');
      print('Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data;
        print('Response success: ${data['success']}');
        print('Has documents: ${data['data']?['documents'] != null}');
        
        if (data['success'] == true && data['data']?['documents'] != null) {
          final documents = data['data']['documents'] as List;
          print('Total documents from API: ${documents.length}');
          
          // Debug: Print all documents before filtering
          for (var doc in documents) {
            print('Raw doc - folder: ${doc['folder']}, category: ${doc['category']}, status: ${doc['status']}, name: ${doc['name']}');
          }
          
          // Filter for additional documents AND regular documents (selfies, aadhaar, pan, etc.)
          // Documents uploaded to additional_documents/{doc_type} will have folder = doc_type
          // Regular documents are in folders like: selfies, aadhaar, pan, bank_statements, salary_slips
          // The folder field contains the document type ID (e.g., 'applicant_aadhaar', 'spouse_pan', 'selfies')
          // IMPORTANT: Always include rejected documents, even if they don't match the filter
          final additionalDocs = documents.where((doc) {
            final folder = doc['folder'] as String? ?? '';
            final category = doc['category'] as String? ?? '';
            final status = (doc['status'] as String? ?? '').toLowerCase();
            
            // Always include rejected documents (they need to be shown for re-upload)
            if (status == 'rejected') {
              print('Including rejected document - folder: $folder, category: $category, status: $status');
              return true;
            }
            
            // Regular document folders (selfies, aadhaar, pan, etc.)
            final regularDocFolders = ['selfies', 'aadhaar', 'pan', 'bank_statements', 'salary_slips'];
            if (regularDocFolders.contains(folder.toLowerCase())) {
              print('Including regular document - folder: $folder');
              return true;
            }
            
            // For other documents, check if they match additional document patterns
            final matches = folder.startsWith('applicant_') ||
                   folder.startsWith('spouse_') ||
                   folder.startsWith('custom_') ||
                   category.toLowerCase().contains('additional') ||
                   category.toLowerCase().contains('applicant') ||
                   category.toLowerCase().contains('spouse');
            if (matches) {
              print('Document matches filter - folder: $folder, category: $category');
            }
            return matches;
          }).toList();

          print('Filtered additional documents: ${additionalDocs.length}');

          final result = additionalDocs
              .map((doc) {
                try {
                  return UploadedDocument.fromJson(doc as Map<String, dynamic>);
                } catch (e) {
                  print('Error parsing document: $e, doc: $doc');
                  return null;
                }
              })
              .whereType<UploadedDocument>()
              .toList();
          
          print('Final parsed documents: ${result.length}');
          for (var doc in result) {
            print('Parsed doc - type: ${doc.documentType}, status: ${doc.status}, file: ${doc.fileName}');
          }
          
          return result;
        }
      }
      print('No documents returned from API');
      return [];
    } catch (e) {
      print('Error in getUserDocuments: $e');
      throw Exception('Failed to get documents: $e');
    }
  }

  /// Upload additional document
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
        // On web, use bytes
        if (fileBytes == null) {
          throw Exception('File bytes required for web upload');
        }
        String contentType = 'application/pdf';
        if (fileName.toLowerCase().endsWith('.png')) {
          contentType = 'image/png';
        } else if (fileName.toLowerCase().endsWith('.jpg') || 
                   fileName.toLowerCase().endsWith('.jpeg')) {
          contentType = 'image/jpeg';
        }
        multipartFile = MultipartFile.fromBytes(
          fileBytes,
          filename: fileName,
          contentType: DioMediaType.parse(contentType),
        );
      } else {
        // On mobile/desktop, use file path
        multipartFile = await MultipartFile.fromFile(
          filePath,
          filename: fileName,
        );
      }

      final formData = FormData.fromMap({
        'file': multipartFile,
        'documentType': documentType,
        'leadId': leadId,
      });

      final response = await _apiClient.post(
        '/api/v1/uploads/additional-document',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          return data['data']['file'] as Map<String, dynamic>;
        }
      }

      throw Exception('Failed to upload document');
    } catch (e) {
      throw Exception('Failed to upload document: $e');
    }
  }
}
