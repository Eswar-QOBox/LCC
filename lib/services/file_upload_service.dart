import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import '../services/api_client.dart';

class FileUploadService {
  final ApiClient _apiClient = ApiClient();

  /// Upload selfie image
  Future<Map<String, dynamic>> uploadSelfie(XFile imageFile) async {
    try {
      MultipartFile multipartFile;
      
      if (kIsWeb) {
        // On web, read bytes and use fromBytes
        final bytes = await imageFile.readAsBytes();
        // Ensure we have a valid filename - use a default if empty
        String filename = imageFile.name;
        if (filename.isEmpty) {
          filename = 'selfie_${DateTime.now().millisecondsSinceEpoch}.jpg';
        }
        // Determine content type from filename or use default
        String contentType = 'image/jpeg';
        if (filename.toLowerCase().endsWith('.png')) {
          contentType = 'image/png';
        } else if (filename.toLowerCase().endsWith('.webp')) {
          contentType = 'image/webp';
        }
        multipartFile = MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: DioMediaType.parse(contentType),
        );
      } else {
        // On mobile/desktop, use fromFile
        multipartFile = await MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.name.isNotEmpty
              ? imageFile.name
              : 'selfie_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }

      final formData = FormData.fromMap({
        'file': multipartFile,
      });

      final response = await _apiClient.post(
        '/api/v1/uploads/selfie',
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

      throw Exception('Failed to upload selfie');
    } catch (e) {
      throw Exception('Failed to upload selfie: $e');
    }
  }

  /// Upload Aadhaar card (front or back)
  Future<Map<String, dynamic>> uploadAadhaar(
    XFile imageFile, {
    required String side, // 'front' or 'back'
  }) async {
    try {
      MultipartFile multipartFile;
      
      if (kIsWeb) {
        // On web, read bytes and use fromBytes
        final bytes = await imageFile.readAsBytes();
        // Ensure we have a valid filename - use a default if empty
        String filename = imageFile.name;
        if (filename.isEmpty) {
          filename = 'aadhaar_${DateTime.now().millisecondsSinceEpoch}.jpg';
        }
        // Determine content type from filename or use default
        String contentType = 'image/jpeg';
        if (filename.toLowerCase().endsWith('.png')) {
          contentType = 'image/png';
        } else if (filename.toLowerCase().endsWith('.pdf')) {
          contentType = 'application/pdf';
        }
        multipartFile = MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: DioMediaType.parse(contentType),
        );
      } else {
        // On mobile/desktop, use fromFile
        multipartFile = await MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.name.isNotEmpty
              ? imageFile.name
              : 'aadhaar_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }

      final formData = FormData.fromMap({
        'file': multipartFile,
        'side': side,
      });

      final response = await _apiClient.post(
        '/api/v1/uploads/aadhaar',
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

      throw Exception('Failed to upload Aadhaar');
    } catch (e) {
      throw Exception('Failed to upload Aadhaar: $e');
    }
  }

  /// Upload PAN card
  Future<Map<String, dynamic>> uploadPan(XFile imageFile) async {
    try {
      MultipartFile multipartFile;
      
      if (kIsWeb) {
        // On web, read bytes and use fromBytes
        final bytes = await imageFile.readAsBytes();
        // Ensure we have a valid filename - use a default if empty
        String filename = imageFile.name;
        if (filename.isEmpty) {
          filename = 'pan_${DateTime.now().millisecondsSinceEpoch}.jpg';
        }
        // Determine content type from filename or use default
        String contentType = 'image/jpeg';
        if (filename.toLowerCase().endsWith('.png')) {
          contentType = 'image/png';
        } else if (filename.toLowerCase().endsWith('.pdf')) {
          contentType = 'application/pdf';
        }
        multipartFile = MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: DioMediaType.parse(contentType),
        );
      } else {
        // On mobile/desktop, use fromFile
        String filename = imageFile.name.isNotEmpty
            ? imageFile.name
            : 'pan_${DateTime.now().millisecondsSinceEpoch}.jpg';
        // Determine content type from filename
        String? contentType;
        if (filename.toLowerCase().endsWith('.pdf')) {
          contentType = 'application/pdf';
        }
        multipartFile = await MultipartFile.fromFile(
          imageFile.path,
          filename: filename,
          contentType: contentType != null ? DioMediaType.parse(contentType) : null,
        );
      }

      final formData = FormData.fromMap({
        'file': multipartFile,
      });

      final response = await _apiClient.post(
        '/api/v1/uploads/pan',
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

      throw Exception('Failed to upload PAN');
    } catch (e) {
      throw Exception('Failed to upload PAN: $e');
    }
  }

  /// Upload bank statement files (multiple)
  Future<List<Map<String, dynamic>>> uploadBankStatements(
    List<XFile> files,
  ) async {
    try {
      final formData = FormData();
      
      for (int i = 0; i < files.length; i++) {
        var file = files[i];
        MultipartFile multipartFile;
        
        if (kIsWeb) {
          // On web, read bytes and use fromBytes
          final bytes = await file.readAsBytes();
          // Ensure we have a valid filename - use a default if empty
          String filename = file.name;
          if (filename.isEmpty) {
            filename = 'bank_statement_${i}_${DateTime.now().millisecondsSinceEpoch}.pdf';
          }
          // Determine content type from filename or use default
          String contentType = 'application/pdf';
          if (filename.toLowerCase().endsWith('.png')) {
            contentType = 'image/png';
          } else if (filename.toLowerCase().endsWith('.jpg') || filename.toLowerCase().endsWith('.jpeg')) {
            contentType = 'image/jpeg';
          }
          multipartFile = MultipartFile.fromBytes(
            bytes,
            filename: filename,
            contentType: DioMediaType.parse(contentType),
          );
        } else {
          // On mobile/desktop, use fromFile
          multipartFile = await MultipartFile.fromFile(
            file.path,
            filename: file.name.isNotEmpty
                ? file.name
                : 'bank_statement_${i}_${DateTime.now().millisecondsSinceEpoch}.pdf',
          );
        }
        
        formData.files.add(
          MapEntry(
            'files',
            multipartFile,
          ),
        );
      }

      final response = await _apiClient.post(
        '/api/v1/uploads/bank-statement',
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
          final filesList = data['data']['files'] as List<dynamic>;
          return filesList.cast<Map<String, dynamic>>();
        }
      }

      throw Exception('Failed to upload bank statements');
    } catch (e) {
      throw Exception('Failed to upload bank statements: $e');
    }
  }

  /// Upload salary slips (multiple)
  Future<List<Map<String, dynamic>>> uploadSalarySlips(
    List<XFile> files,
  ) async {
    try {
      final formData = FormData();
      
      for (int i = 0; i < files.length; i++) {
        var file = files[i];
        MultipartFile multipartFile;
        
        if (kIsWeb) {
          // On web, read bytes and use fromBytes
          final bytes = await file.readAsBytes();
          // Ensure we have a valid filename - use a default if empty
          String filename = file.name;
          if (filename.isEmpty) {
            filename = 'salary_slip_${i}_${DateTime.now().millisecondsSinceEpoch}.pdf';
          }
          // Determine content type from filename or use default
          String contentType = 'application/pdf';
          if (filename.toLowerCase().endsWith('.png')) {
            contentType = 'image/png';
          } else if (filename.toLowerCase().endsWith('.jpg') || filename.toLowerCase().endsWith('.jpeg')) {
            contentType = 'image/jpeg';
          }
          multipartFile = MultipartFile.fromBytes(
            bytes,
            filename: filename,
            contentType: DioMediaType.parse(contentType),
          );
        } else {
          // On mobile/desktop, use fromFile
          multipartFile = await MultipartFile.fromFile(
            file.path,
            filename: file.name.isNotEmpty
                ? file.name
                : 'salary_slip_${i}_${DateTime.now().millisecondsSinceEpoch}.pdf',
          );
        }
        
        formData.files.add(
          MapEntry(
            'files',
            multipartFile,
          ),
        );
      }

      final response = await _apiClient.post(
        '/api/v1/uploads/salary-slips',
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
          final filesList = data['data']['files'] as List<dynamic>;
          return filesList.cast<Map<String, dynamic>>();
        }
      }

      throw Exception('Failed to upload salary slips');
    } catch (e) {
      throw Exception('Failed to upload salary slips: $e');
    }
  }

  /// Upload file from bytes (for web platform)
  Future<Map<String, dynamic>> uploadSelfieFromBytes(
    List<int> bytes,
    String filename,
  ) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
        ),
      });

      final response = await _apiClient.post(
        '/api/v1/uploads/selfie',
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

      throw Exception('Failed to upload selfie');
    } catch (e) {
      throw Exception('Failed to upload selfie: $e');
    }
  }
}
