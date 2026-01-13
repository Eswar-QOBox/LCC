import 'package:dio/dio.dart';
import '../models/loan_application.dart';
import '../services/api_client.dart';

class LoanApplicationService {
  final ApiClient _apiClient = ApiClient();

  /// Get all loan applications for the current user
  Future<List<LoanApplication>> getApplications({
    int page = 1,
    int limit = 20,
    String? status,
    String? loanType,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      if (loanType != null && loanType.isNotEmpty) {
        queryParams['loanType'] = loanType;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await _apiClient.get(
        '/api/v1/applications',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          final applicationsJson =
              data['data']['applications'] as List<dynamic>;
          return applicationsJson
              .map((json) => LoanApplication.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      }

      throw Exception('Failed to fetch applications');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Unauthorized. Please login again.');
      }
      throw Exception(
          'Network error: ${e.response?.data?['error']?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to fetch applications: $e');
    }
  }

  /// Get a single loan application by ID
  Future<LoanApplication> getApplication(String applicationId) async {
    try {
      final response = await _apiClient.get(
        '/api/v1/applications/$applicationId',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          final applicationJson = data['data']['application'] as Map<String, dynamic>;
          return LoanApplication.fromJson(applicationJson);
        }
      }

      throw Exception('Failed to fetch application');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Unauthorized. Please login again.');
      } else if (e.response?.statusCode == 404) {
        throw Exception('Application not found');
      }
      throw Exception(
          'Network error: ${e.response?.data?['error']?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to fetch application: $e');
    }
  }

  /// Create a new loan application
  Future<LoanApplication> createApplication({
    required String loanType,
    double? loanAmount,
    int currentStep = 1,
    String status = 'draft',
  }) async {
    try {
      final response = await _apiClient.post(
        '/api/v1/applications',
        data: {
          'loanType': loanType,
          if (loanAmount != null) 'loanAmount': loanAmount,
          'currentStep': currentStep,
          'status': status,
        },
      );

      if (response.statusCode == 201) {
        final data = response.data;
        if (data['success'] == true) {
          final applicationJson = data['data']['application'] as Map<String, dynamic>;
          return LoanApplication.fromJson(applicationJson);
        }
      }

      throw Exception('Failed to create application');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Unauthorized. Please login again.');
      } else if (e.response?.statusCode == 400) {
        final errorMsg = e.response?.data?['error']?['message'] ?? 'Invalid request';
        throw Exception(errorMsg);
      }
      throw Exception(
          'Network error: ${e.response?.data?['error']?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to create application: $e');
    }
  }

  /// Update a loan application
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
      final updateData = <String, dynamic>{};
      if (loanType != null) updateData['loanType'] = loanType;
      if (loanAmount != null) updateData['loanAmount'] = loanAmount;
      if (currentStep != null) updateData['currentStep'] = currentStep;
      if (status != null) updateData['status'] = status;
      if (step1Selfie != null) updateData['step1Selfie'] = step1Selfie;
      if (step2Aadhaar != null) updateData['step2Aadhaar'] = step2Aadhaar;
      if (step3Pan != null) updateData['step3Pan'] = step3Pan;
      if (step4BankStatement != null) updateData['step4BankStatement'] = step4BankStatement;
      if (step5PersonalData != null) updateData['step5PersonalData'] = step5PersonalData;
      if (step6Preview != null) updateData['step6Preview'] = step6Preview;
      if (step7Submission != null) updateData['step7Submission'] = step7Submission;

      final response = await _apiClient.put(
        '/api/v1/applications/$applicationId',
        data: updateData,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          final applicationJson = data['data']['application'] as Map<String, dynamic>;
          return LoanApplication.fromJson(applicationJson);
        }
      }

      throw Exception('Failed to update application');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Unauthorized. Please login again.');
      } else if (e.response?.statusCode == 404) {
        throw Exception('Application not found');
      } else if (e.response?.statusCode == 400) {
        final errorMsg = e.response?.data?['error']?['message'] ?? 'Invalid request';
        throw Exception(errorMsg);
      }
      throw Exception(
          'Network error: ${e.response?.data?['error']?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to update application: $e');
    }
  }

  /// Delete a loan application
  Future<void> deleteApplication(String applicationId) async {
    try {
      final response = await _apiClient.delete(
        '/api/v1/applications/$applicationId',
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete application');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Unauthorized. Please login again.');
      } else if (e.response?.statusCode == 404) {
        throw Exception('Application not found');
      } else if (e.response?.statusCode == 400) {
        final errorMsg = e.response?.data?['error']?['message'] ?? 'Invalid request';
        throw Exception(errorMsg);
      }
      throw Exception(
          'Network error: ${e.response?.data?['error']?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to delete application: $e');
    }
  }

  /// Continue a paused application
  Future<LoanApplication> continueApplication(String applicationId) async {
    try {
      final response = await _apiClient.post(
        '/api/v1/applications/$applicationId/continue',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          final applicationJson = data['data']['application'] as Map<String, dynamic>;
          return LoanApplication.fromJson(applicationJson);
        }
      }

      throw Exception('Failed to continue application');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Unauthorized. Please login again.');
      } else if (e.response?.statusCode == 404) {
        throw Exception('Application not found');
      } else if (e.response?.statusCode == 400) {
        final errorMsg = e.response?.data?['error']?['message'] ?? 'Invalid request';
        throw Exception(errorMsg);
      }
      throw Exception(
          'Network error: ${e.response?.data?['error']?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to continue application: $e');
    }
  }

  /// Pause an in-progress application
  Future<LoanApplication> pauseApplication(String applicationId) async {
    try {
      final response = await _apiClient.post(
        '/api/v1/applications/$applicationId/pause',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          final applicationJson = data['data']['application'] as Map<String, dynamic>;
          return LoanApplication.fromJson(applicationJson);
        }
      }

      throw Exception('Failed to pause application');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Unauthorized. Please login again.');
      } else if (e.response?.statusCode == 404) {
        throw Exception('Application not found');
      } else if (e.response?.statusCode == 400) {
        final errorMsg = e.response?.data?['error']?['message'] ?? 'Invalid request';
        throw Exception(errorMsg);
      }
      throw Exception(
          'Network error: ${e.response?.data?['error']?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to pause application: $e');
    }
  }
}
