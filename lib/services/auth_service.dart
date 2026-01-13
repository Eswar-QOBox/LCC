import 'package:dio/dio.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../utils/auth_errors.dart';

class AuthService {
  final ApiClient _apiClient = ApiClient();

  /// Login with email and password
  /// Returns a map with 'access_token', 'refresh_token', and 'user'
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _apiClient.post(
        '/api/v1/auth/login',
        data: {'email': email, 'password': password},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          final responseData = data['data'] as Map<String, dynamic>;

          // Extract tokens and user
          final accessToken = responseData['access_token'] as String;
          final refreshToken = responseData['refresh_token'] as String;
          final userJson = responseData['user'] as Map<String, dynamic>;

          // Save tokens securely
          final storage = StorageService.instance;
          await storage.saveTokens(accessToken, refreshToken);

          // Parse and return user
          final user = User.fromJson(userJson);

          return {
            'access_token': accessToken,
            'refresh_token': refreshToken,
            'user': user,
          };
        }
      }

      throw AuthException(
        code: AuthErrorCodes.internalError,
        message: 'Login failed: Invalid response',
        statusCode: response.statusCode,
      );
    } catch (e) {
      if (e is DioException) {
        // Handle CORS/connection errors (common on web platform)
        if (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout) {
          // Check if this is a CORS issue (connection error on web)
          final errorMessage = e.message?.toLowerCase() ?? '';
          if (errorMessage.contains('xmlhttprequest') ||
              errorMessage.contains('cors') ||
              errorMessage.contains('network')) {
            throw AuthException(
              code: 'NETWORK_ERROR',
              message:
                  'Connection error. This may be a CORS issue. Please ensure:\n'
                  '1. Backend server is running on port 5000\n'
                  '2. CORS is properly configured on the backend\n'
                  '3. Backend includes CORS headers in POST responses (not just OPTIONS)',
              statusCode: null,
            );
          }
          throw AuthException(
            code: 'NETWORK_ERROR',
            message:
                'Network error. Please check your internet connection and try again.',
            statusCode: null,
          );
        }

        // Handle HTTP status code errors
        final statusCode = e.response?.statusCode;

        // Map common HTTP status codes to error codes
        String errorCode = AuthErrorCodes.internalError;
        String errorMessage = 'Login failed';

        if (statusCode == 404) {
          errorCode = AuthErrorCodes.notFound;
          errorMessage =
              'Login endpoint not found. Please check if the server is running and the API endpoint is correct.';
        } else if (statusCode == 401) {
          errorCode = AuthErrorCodes.invalidCredentials;
          errorMessage =
              'Invalid email or password. Please check your credentials and try again.';
        } else if (statusCode == 403) {
          errorCode = AuthErrorCodes.forbidden;
          errorMessage =
              'Access forbidden. You do not have permission to access this resource.';
        } else if (statusCode == 400) {
          errorCode = AuthErrorCodes.validationError;
          errorMessage =
              'Invalid request. Please check your input and try again.';
        } else if (statusCode == 500) {
          errorCode = AuthErrorCodes.internalError;
          errorMessage = 'Server error. Please try again later.';
        }

        // Handle API error responses with body
        final errorData = e.response?.data;
        if (errorData != null && errorData is Map) {
          try {
            // Handle different error response formats
            dynamic errorObj = errorData['error'];

            if (errorObj != null) {
              if (errorObj is Map<String, dynamic>) {
                // Error is an object with code and message
                final code = errorObj['code'];
                final message = errorObj['message'];
                if (code != null) errorCode = code.toString();
                if (message != null) errorMessage = message.toString();
              } else if (errorObj is String) {
                // Error is a simple string message
                errorMessage = errorObj;
              } else if (errorObj is int) {
                // Error is a status code number
                // Use the status code mapping above
              }
            } else if (errorData['message'] != null) {
              // Error message at top level
              errorMessage = errorData['message'].toString();
            }
          } catch (parseError) {
            // If parsing fails, use the status code-based error message
            // This handles cases where errorData format is unexpected
          }
        }

        throw AuthException(
          code: errorCode,
          message: errorMessage,
          statusCode: statusCode,
        );
      }

      // Re-throw AuthException as-is
      if (e is AuthException) {
        rethrow;
      }

      // Wrap other exceptions
      throw AuthException(
        code: AuthErrorCodes.internalError,
        message: e.toString(),
      );
    }
  }

  /// Refresh access token using refresh token
  Future<String> refreshAccessToken(String refreshToken) async {
    try {
      final response = await _apiClient.post(
        '/api/v1/auth/refresh',
        options: Options(
          headers: {
            'Authorization': 'Bearer $refreshToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          final newAccessToken = data['data']['access_token'] as String;
          final storage = StorageService.instance;
          await storage.saveAccessToken(newAccessToken);
          return newAccessToken;
        }
      }

      throw AuthException(
        code: AuthErrorCodes.unauthorized,
        message: 'Token refresh failed',
        statusCode: response.statusCode,
      );
    } catch (e) {
      if (e is DioException) {
        // Handle network errors
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.connectionError) {
          throw AuthException(
            code: 'NETWORK_ERROR',
            message:
                'Network error. Please check your internet connection and try again.',
            statusCode: null,
          );
        }

        // Handle HTTP status code errors
        final statusCode = e.response?.statusCode;

        // Map common HTTP status codes to error codes
        String errorCode = AuthErrorCodes.unauthorized;
        String errorMessage = 'Token refresh failed';

        if (statusCode == 404) {
          errorCode = AuthErrorCodes.notFound;
          errorMessage =
              'Refresh endpoint not found. Please check if the server is running and the API endpoint is correct.';
        } else if (statusCode == 401) {
          errorCode = AuthErrorCodes.unauthorized;
          errorMessage = 'Token refresh failed. Please login again.';
        } else if (statusCode == 403) {
          errorCode = AuthErrorCodes.forbidden;
          errorMessage =
              'Access forbidden. You do not have permission to access this resource.';
        }

        // Handle API error responses with body
        final errorData = e.response?.data;
        if (errorData != null && errorData is Map) {
          try {
            // Handle different error response formats
            dynamic errorObj = errorData['error'];

            if (errorObj != null) {
              if (errorObj is Map<String, dynamic>) {
                // Error is an object with code and message
                final code = errorObj['code'];
                final message = errorObj['message'];
                if (code != null) errorCode = code.toString();
                if (message != null) errorMessage = message.toString();
              } else if (errorObj is String) {
                // Error is a simple string message
                errorMessage = errorObj;
              }
            } else if (errorData['message'] != null) {
              // Error message at top level
              errorMessage = errorData['message'].toString();
            }
          } catch (parseError) {
            // If parsing fails, use the status code-based error message
          }
        }

        throw AuthException(
          code: errorCode,
          message: errorMessage,
          statusCode: statusCode,
        );
      }

      // Re-throw AuthException as-is
      if (e is AuthException) {
        rethrow;
      }

      // Wrap other exceptions
      throw AuthException(
        code: AuthErrorCodes.internalError,
        message: e.toString(),
      );
    }
  }

  /// Get current authenticated user
  Future<User> getCurrentUser() async {
    try {
      final response = await _apiClient.get('/api/v1/auth/me');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          final userJson = data['data']['user'] as Map<String, dynamic>;
          return User.fromJson(userJson);
        }
      }

      throw AuthException(
        code: AuthErrorCodes.internalError,
        message: 'Failed to get user',
        statusCode: response.statusCode,
      );
    } catch (e) {
      if (e is DioException) {
        // Handle network errors
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.connectionError) {
          throw AuthException(
            code: 'NETWORK_ERROR',
            message:
                'Network error. Please check your internet connection and try again.',
            statusCode: null,
          );
        }

        // Handle HTTP status code errors
        final statusCode = e.response?.statusCode;

        // Map common HTTP status codes to error codes
        String errorCode = AuthErrorCodes.internalError;
        String errorMessage = 'Failed to get user';

        if (statusCode == 404) {
          errorCode = AuthErrorCodes.notFound;
          errorMessage =
              'User endpoint not found. Please check if the server is running and the API endpoint is correct.';
        } else if (statusCode == 401) {
          errorCode = AuthErrorCodes.unauthorized;
          errorMessage = 'Unauthorized. Please login again.';
        } else if (statusCode == 403) {
          errorCode = AuthErrorCodes.forbidden;
          errorMessage =
              'Access forbidden. You do not have permission to access this resource.';
        }

        // Handle API error responses with body
        final errorData = e.response?.data;
        if (errorData != null && errorData is Map) {
          try {
            // Handle different error response formats
            dynamic errorObj = errorData['error'];

            if (errorObj != null) {
              if (errorObj is Map<String, dynamic>) {
                // Error is an object with code and message
                final code = errorObj['code'];
                final message = errorObj['message'];
                if (code != null) errorCode = code.toString();
                if (message != null) errorMessage = message.toString();
              } else if (errorObj is String) {
                // Error is a simple string message
                errorMessage = errorObj;
              }
            } else if (errorData['message'] != null) {
              // Error message at top level
              errorMessage = errorData['message'].toString();
            }
          } catch (parseError) {
            // If parsing fails, use the status code-based error message
          }
        }

        throw AuthException(
          code: errorCode,
          message: errorMessage,
          statusCode: statusCode,
        );
      }

      // Re-throw AuthException as-is
      if (e is AuthException) {
        rethrow;
      }

      // Wrap other exceptions
      throw AuthException(
        code: AuthErrorCodes.internalError,
        message: e.toString(),
      );
    }
  }

  /// Logout - clear tokens
  Future<void> logout() async {
    final storage = StorageService.instance;
    await storage.clearAll();
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final storage = StorageService.instance;
    return await storage.isLoggedIn();
  }
}
