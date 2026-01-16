import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
        
        if (leadsData['success'] == true && 
            leadsData['data']?['leads'] != null) {
          final leads = leadsData['data']['leads'] as List;
          
          // Find lead with matching email (case-insensitive)
          // Backend should already filter this, but we double-check for security
          for (var lead in leads) {
            final leadEmail = (lead['email'] as String? ?? '').toLowerCase().trim();
            
            if (leadEmail == normalizedEmail) {
              return lead as Map<String, dynamic>;
            }
          }
        }
      } else if (leadsResponse.statusCode == 403) {
        throw Exception('Access denied. You can only view your own lead information.');
      } else if (leadsResponse.statusCode == 401) {
        throw Exception('Authentication required. Please log in again.');
      }

      throw Exception('Lead not found for your email address');
    } catch (e) {
      if (e.toString().contains('Access denied') || 
          e.toString().contains('Authentication required')) {
        rethrow;
      }
      throw Exception('Failed to get lead information. Please try again later.');
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

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true && data['data']?['documents'] != null) {
          final documents = data['data']['documents'] as List;
          
          // Filter for additional documents
          // Documents uploaded to additional_documents/{doc_type} will have folder = doc_type
          // The folder field contains the document type ID (e.g., 'applicant_aadhaar', 'spouse_pan')
          final additionalDocs = documents.where((doc) {
            final folder = doc['folder'] as String? ?? '';
            final category = doc['category'] as String? ?? '';
            // Check if it matches document type patterns (applicant_*, spouse_*, custom_*)
            // or if category indicates it's an additional document
            return folder.startsWith('applicant_') ||
                   folder.startsWith('spouse_') ||
                   folder.startsWith('custom_') ||
                   category.toLowerCase().contains('additional') ||
                   category.toLowerCase().contains('applicant') ||
                   category.toLowerCase().contains('spouse');
          }).toList();

          return additionalDocs
              .map((doc) => UploadedDocument.fromJson(doc as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
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
