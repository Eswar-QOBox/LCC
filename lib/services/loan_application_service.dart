import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/loan_application.dart';
import '../services/api_client.dart';
import '../utils/api_config.dart';

class LoanApplicationService {
  final ApiClient _apiClient = ApiClient();

  /// JHipster loan-type normalisation (backend only allows its known enum values).
  static String _loanTypeForBackend(String loanType) {
    if (loanType == 'Professional Loan') return 'Personal Loan';
    if (loanType == 'Student Loan') return 'Education Loan';
    return loanType;
  }

  /// Get all loan applications for the current user.
  /// Maps JHipster GET /api/loan-submissions to a list of LoanApplication models.
  ///
  /// When `customerLeadId` is set (CRM lead for this login), results are restricted to
  /// rows whose inferred lead id matches. This mitigates a backend issue where the list
  /// endpoint can return other customers' submissions while still authenticated.
  Future<List<LoanApplication>> getApplications({
    int page = 1,
    int limit = 20,
    String? status,
    String? loanType,
    String? search,
    String? customerLeadId,
  }) async {
    try {
      // JHipster pagination is 0-based
      final queryParams = <String, dynamic>{
        'page': page - 1,
        'size': limit,
        'sort': 'createdAt,desc',
      };

      final response = await _apiClient.get(
        ApiConfig.loanSubmissionsEndpoint,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final list = response.data as List<dynamic>;
        var apps = list
            .map((json) => LoanApplication.fromJhipsterJson(json as Map<String, dynamic>))
            .toList();
        final want = customerLeadId?.trim();
        if (want != null && want.isNotEmpty) {
          apps = apps.where((a) => a.userId == want).toList();
        }
        return apps;
      }

      throw Exception('Failed to fetch applications');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) throw Exception('Unauthorized. Please login again.');
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch applications: $e');
    }
  }

  /// Get a single loan application by ID.
  Future<LoanApplication> getApplication(String applicationId) async {
    try {
      final response = await _apiClient.get(
        '${ApiConfig.loanSubmissionsEndpoint}/$applicationId',
      );

      if (response.statusCode == 200) {
        return LoanApplication.fromJhipsterJson(
          response.data as Map<String, dynamic>,
        );
      }

      throw Exception('Failed to fetch application');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) throw Exception('Unauthorized. Please login again.');
      if (e.response?.statusCode == 404) throw Exception('Application not found');
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch application: $e');
    }
  }

  /// Create a new loan application.
  /// Maps Flutter's LoanApplication fields onto JHipster's LoanSubmissionDTO.
  ///
  /// [customerLeadId] is the CRM lead id for the logged-in customer. The backend
  /// requires this for `ROLE_USER` creates (`lead` must reference an accessible lead).
  Future<LoanApplication> createApplication({
    required String loanType,
    double? loanAmount,
    int currentStep = 1,
    String status = 'draft',
    String? customerLeadId,
  }) async {
    try {
      final backendLoanType = _loanTypeForBackend(loanType);

      // Encode app-level metadata in remarks so we can reconstruct it on read.
      final meta = jsonEncode({
        'currentStep': currentStep,
        'status': status,
        if (loanAmount != null) 'loanAmount': loanAmount,
      });

      final data = <String, dynamic>{
        'loanType': backendLoanType,
        'applicantName': '',
        'status': 'PENDING',
        'attemptNumber': 1,
        'remarks': meta,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      };

      final leadRaw = customerLeadId?.trim();
      if (leadRaw != null && leadRaw.isNotEmpty) {
        final asInt = int.tryParse(leadRaw);
        if (asInt != null) {
          data['lead'] = <String, dynamic>{'id': asInt};
        }
      }

      final response = await _apiClient.post(
        ApiConfig.loanSubmissionsEndpoint,
        data: data,
      );

      if (response.statusCode == 201) {
        return LoanApplication.fromJhipsterJson(
          response.data as Map<String, dynamic>,
        );
      }

      throw Exception('Failed to create application');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) throw Exception('Unauthorized. Please login again.');
      if (e.response?.statusCode == 403) {
        final body = e.response?.data;
        final msg = body is Map
            ? (body['detail'] ?? body['title'] ?? 'Forbidden').toString()
            : 'Forbidden';
        throw Exception(msg);
      }
      if (e.response?.statusCode == 400) {
        final msg = e.response?.data?['detail'] ?? e.response?.data?['title'] ?? 'Invalid request';
        throw Exception(msg);
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to create application: $e');
    }
  }

  /// Update a loan application.
  Future<LoanApplication> updateApplication(
    String applicationId, {
    String? loanType,
    double? loanAmount,
    int? currentStep,
    String? status,
    Map<String, dynamic>? step1Selfie,
    Map<String, dynamic>? step2Aadhaar,
    Map<String, dynamic>? step3Pan,
    Map<String, dynamic>? step4BankStatement,
    Map<String, dynamic>? step5PersonalData,
    Map<String, dynamic>? step6Preview,
    Map<String, dynamic>? step7Submission,
  }) async {
    try {
      // First fetch existing record to preserve unrequested fields
      final existing = await getApplication(applicationId);
      final existingMeta = existing.toMetaMap();

      // Merge updates into existing meta
      if (currentStep != null) existingMeta['currentStep'] = currentStep;
      if (status != null) existingMeta['status'] = status;
      if (loanAmount != null) existingMeta['loanAmount'] = loanAmount;
      if (step1Selfie != null) existingMeta['step1Selfie'] = step1Selfie;
      if (step2Aadhaar != null) existingMeta['step2Aadhaar'] = step2Aadhaar;
      if (step3Pan != null) existingMeta['step3Pan'] = step3Pan;
      if (step4BankStatement != null) existingMeta['step4BankStatement'] = step4BankStatement;
      if (step5PersonalData != null) existingMeta['step5PersonalData'] = step5PersonalData;
      if (step6Preview != null) existingMeta['step6Preview'] = step6Preview;
      if (step7Submission != null) existingMeta['step7Submission'] = step7Submission;

      final updateData = <String, dynamic>{
        'id': int.tryParse(applicationId) ?? applicationId,
        'loanType': loanType != null ? _loanTypeForBackend(loanType) : existing.loanType,
        'applicantName': existing.applicationId,
        'status': 'PENDING',
        'attemptNumber': 1,
        'remarks': jsonEncode(existingMeta),
        'createdAt': existing.createdAt.toUtc().toIso8601String(),
      };
      final existingLead = existing.userId.trim();
      if (existingLead.isNotEmpty) {
        final lid = int.tryParse(existingLead);
        if (lid != null) {
          updateData['lead'] = <String, dynamic>{'id': lid};
        }
      }

      final response = await _apiClient.put(
        '${ApiConfig.loanSubmissionsEndpoint}/$applicationId',
        data: updateData,
      );

      if (response.statusCode == 200) {
        return LoanApplication.fromJhipsterJson(
          response.data as Map<String, dynamic>,
        );
      }

      throw Exception('Failed to update application');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) throw Exception('Unauthorized. Please login again.');
      if (e.response?.statusCode == 404) throw Exception('Application not found');
      if (e.response?.statusCode == 403) {
        final body = e.response?.data;
        final msg = body is Map
            ? (body['detail'] ?? body['title'] ?? 'Forbidden').toString()
            : 'Forbidden';
        throw Exception(msg);
      }
      if (e.response?.statusCode == 400) {
        final msg = e.response?.data?['detail'] ?? e.response?.data?['title'] ?? 'Invalid request';
        throw Exception(msg);
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to update application: $e');
    }
  }

  /// Delete a loan application.
  Future<void> deleteApplication(String applicationId) async {
    try {
      final response = await _apiClient.delete(
        '${ApiConfig.loanSubmissionsEndpoint}/$applicationId',
      );
      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Failed to delete application');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) throw Exception('Unauthorized. Please login again.');
      if (e.response?.statusCode == 404) throw Exception('Application not found');
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to delete application: $e');
    }
  }

  /// Continue a paused application — update status to in_progress.
  Future<LoanApplication> continueApplication(String applicationId) async {
    return updateApplication(applicationId, status: 'in_progress');
  }

  /// Pause an in-progress application — update status to paused.
  Future<LoanApplication> pauseApplication(String applicationId) async {
    return updateApplication(applicationId, status: 'paused');
  }
}
