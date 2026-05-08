import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_client.dart';
import '../utils/api_config.dart';

class FileUploadService {
  final ApiClient _apiClient = ApiClient();

  // ── Selfie ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> uploadSelfie(XFile imageFile, {String? leadId}) async {
    final compressedBytes = await _compressImage(imageFile);
    final multipartFile = await _buildMultipart(
      imageFile,
      bytes: compressedBytes,
      defaultName: 'selfie_${DateTime.now().millisecondsSinceEpoch}.jpg',
      contentType: 'image/jpeg',
    );
    return _upload(multipartFile, documentType: 'selfie', leadId: leadId);
  }

  // ── Aadhaar ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> uploadAadhaar(
    XFile imageFile, {
    required String side,
    bool isPdf = false,
    Uint8List? maskedBytes,
    String? leadId,
  }) async {
    MultipartFile multipartFile;

    if (maskedBytes != null) {
      multipartFile = MultipartFile.fromBytes(
        maskedBytes,
        filename: imageFile.name.isNotEmpty
            ? imageFile.name
            : 'aadhaar_masked_${DateTime.now().millisecondsSinceEpoch}.jpg',
        contentType: DioMediaType.parse('image/jpeg'),
      );
    } else {
      multipartFile = await _buildMultipart(
        imageFile,
        defaultName: 'aadhaar_${DateTime.now().millisecondsSinceEpoch}',
        contentType: isPdf ? 'application/pdf' : 'image/jpeg',
        enforcePdf: isPdf,
      );
    }

    return _upload(multipartFile, documentType: 'aadhaar_$side', leadId: leadId);
  }

  // ── PAN ───────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> uploadPan(XFile imageFile, {bool isPdf = false, String? leadId}) async {
    final multipartFile = await _buildMultipart(
      imageFile,
      defaultName: 'pan_${DateTime.now().millisecondsSinceEpoch}',
      contentType: isPdf ? 'application/pdf' : 'image/jpeg',
      enforcePdf: isPdf,
    );
    return _upload(multipartFile, documentType: 'pan', leadId: leadId);
  }

  // ── Bank statements ───────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> uploadBankStatements(List<XFile> files, {String? leadId}) async {
    final results = <Map<String, dynamic>>[];
    for (int i = 0; i < files.length; i++) {
      final mp = await _buildMultipart(
        files[i],
        defaultName: 'bank_statement_${i}_${DateTime.now().millisecondsSinceEpoch}.pdf',
        contentType: 'application/pdf',
      );
      results.add(await _upload(mp, documentType: 'bank_statement', leadId: leadId));
    }
    return results;
  }

  // ── Salary slips ──────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> uploadSalarySlips(List<XFile> files, {String? leadId}) async {
    final results = <Map<String, dynamic>>[];
    for (int i = 0; i < files.length; i++) {
      final mp = await _buildMultipart(
        files[i],
        defaultName: 'salary_slip_${i}_${DateTime.now().millisecondsSinceEpoch}.pdf',
        contentType: 'application/pdf',
      );
      results.add(await _upload(mp, documentType: 'salary_slip', leadId: leadId));
    }
    return results;
  }

  // ── Selfie from raw bytes (web) ───────────────────────────────────────────

  Future<Map<String, dynamic>> uploadSelfieFromBytes(List<int> bytes, String filename, {String? leadId}) async {
    final mp = MultipartFile.fromBytes(bytes, filename: filename);
    return _upload(mp, documentType: 'selfie', leadId: leadId);
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Post a single file to the JHipster multipart upload endpoint.
  /// Pass [leadId] to associate the document with a specific lead (recommended).
  Future<Map<String, dynamic>> _upload(
    MultipartFile multipartFile, {
    required String documentType,
    String? leadId,
  }) async {
    final fields = <String, dynamic>{
      'file': multipartFile,
      'documentType': documentType,
    };
    if (leadId != null) fields['leadId'] = leadId;

    final formData = FormData.fromMap(fields);

    final response = await _apiClient.post(
      ApiConfig.leadDocumentsUploadEndpoint,
      data: formData,
      options: Options(headers: {'Content-Type': 'multipart/form-data'}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      return {'url': data?.toString() ?? ''};
    }

    throw Exception('Upload failed (${response.statusCode})');
  }

  Future<MultipartFile> _buildMultipart(
    XFile file, {
    Uint8List? bytes,
    required String defaultName,
    required String contentType,
    bool enforcePdf = false,
  }) async {
    String filename = file.name.isNotEmpty ? file.name : defaultName;

    if (enforcePdf && !filename.toLowerCase().endsWith('.pdf')) {
      filename = '${filename.contains('.') ? filename.split('.').first : filename}.pdf';
      contentType = 'application/pdf';
    } else if (!enforcePdf) {
      if (filename.toLowerCase().endsWith('.png')) contentType = 'image/png';
      if (filename.toLowerCase().endsWith('.pdf')) contentType = 'application/pdf';
    }

    if (bytes != null) {
      return MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: DioMediaType.parse(contentType),
      );
    }

    if (kIsWeb) {
      final fileBytes = await file.readAsBytes();
      return MultipartFile.fromBytes(
        fileBytes,
        filename: filename,
        contentType: DioMediaType.parse(contentType),
      );
    }

    return MultipartFile.fromFile(
      file.path,
      filename: filename,
      contentType: DioMediaType.parse(contentType),
    );
  }

  Future<Uint8List?> _compressImage(XFile imageFile) async {
    try {
      if (kIsWeb) {
        final bytes = await imageFile.readAsBytes();
        return await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: 1024,
          minHeight: 1024,
          quality: 70,
          format: CompressFormat.jpeg,
        );
      } else {
        return await FlutterImageCompress.compressWithFile(
          imageFile.path,
          minWidth: 1024,
          minHeight: 1024,
          quality: 70,
          format: CompressFormat.jpeg,
        );
      }
    } catch (e) {
      debugPrint('Image compression failed: $e');
      return null;
    }
  }
}
