import 'package:dio/dio.dart';
import '../models/user.dart';
import '../models/document_submission.dart';
import '../models/me_response.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../utils/api_config.dart';
import '../utils/auth_errors.dart';

class AuthService {
  final ApiClient _apiClient = ApiClient();

  /// Login with email/username and password.
  /// JHipster returns { id_token: "..." } — no refresh token.
  Future<Map<String, dynamic>> login(String identifier, String password) async {
    try {
      final response = await _apiClient.post(
        ApiConfig.loginEndpoint,
        data: {
          'username': identifier.trim(),
          'password': password,
          'rememberMe': false,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final idToken = data['id_token'] as String?;
        if (idToken != null) {
          final storage = StorageService.instance;
          // JHipster has no refresh token — store id_token as access token only.
          await storage.saveTokens(idToken, '');

          // Fetch user details from /api/account
          final me = await getMe();
          return {
            'access_token': idToken,
            'refresh_token': '',
            'user': me.user,
          };
        }
      }

      throw AuthException(
        code: AuthErrorCodes.internalError,
        message: 'Login failed: Invalid response',
        statusCode: response.statusCode,
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      if (e is DioException) {
        _handleDioException(e, context: 'Login');
      }
      throw AuthException(
        code: AuthErrorCodes.internalError,
        message: e.toString(),
      );
    }
  }

  /// Get current authenticated user from /api/account.
  /// JHipster returns a flat user object (no success wrapper).
  Future<MeResponse> getMe() async {
    try {
      final response = await _apiClient.get(ApiConfig.meEndpoint);

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return MeResponse(
          user: User.fromJson(data),
          personalData: null,
        );
      }

      throw AuthException(
        code: AuthErrorCodes.internalError,
        message: 'Failed to get user',
        statusCode: response.statusCode,
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      if (e is DioException) {
        _handleDioException(e, context: 'GetMe');
      }
      throw AuthException(
        code: AuthErrorCodes.internalError,
        message: e.toString(),
      );
    }
  }

  /// Get current authenticated user.
  Future<User> getCurrentUser() async {
    final me = await getMe();
    return me.user;
  }

  /// Logout — clear stored tokens.
  Future<void> logout() async {
    final storage = StorageService.instance;
    await storage.clearAll();
  }

  /// Check if user is logged in.
  Future<bool> isLoggedIn() async {
    final storage = StorageService.instance;
    return await storage.isLoggedIn();
  }

  /// Request password reset.
  /// JHipster endpoint: POST /api/account/reset-password/init with plain-text email body.
  Future<Map<String, dynamic>> forgotPassword(String identifier) async {
    try {
      final response = await _apiClient.post(
        ApiConfig.forgotPasswordEndpoint,
        data: identifier.trim(),
        options: Options(headers: {'Content-Type': 'text/plain'}),
      );

      // JHipster returns 200 with no body on success
      if (response.statusCode == 200) {
        return {'message': 'Password reset email sent. Please check your inbox.'};
      }

      throw AuthException(
        code: AuthErrorCodes.internalError,
        message: 'Password reset failed',
        statusCode: response.statusCode,
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      if (e is DioException) {
        _handleDioException(e, context: 'ForgotPassword');
      }
      throw AuthException(
        code: AuthErrorCodes.internalError,
        message: e.toString(),
      );
    }
  }

  /// Centralised DioException → AuthException conversion.
  Never _handleDioException(DioException e, {required String context}) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      throw AuthException(
        code: 'NETWORK_ERROR',
        message: 'Network error. Please check your internet connection and try again.',
        statusCode: null,
      );
    }

    final statusCode = e.response?.statusCode;
    String errorCode = AuthErrorCodes.internalError;
    String errorMessage = '$context failed';

    switch (statusCode) {
      case 400:
        errorCode = AuthErrorCodes.validationError;
        errorMessage = 'Invalid request. Please check your input.';
        break;
      case 401:
        errorCode = AuthErrorCodes.invalidCredentials;
        errorMessage = 'Invalid username or password.';
        break;
      case 403:
        errorCode = AuthErrorCodes.forbidden;
        errorMessage = 'Access forbidden.';
        break;
      case 404:
        errorCode = AuthErrorCodes.notFound;
        errorMessage = 'Endpoint not found. Please check the server configuration.';
        break;
      case 500:
        errorCode = AuthErrorCodes.internalError;
        errorMessage = 'Server error. Please try again later.';
        break;
    }

    // Override with body message if present
    final errorData = e.response?.data;
    if (errorData != null) {
      if (errorData is String && errorData.isNotEmpty) {
        errorMessage = errorData;
      } else if (errorData is Map) {
        final msg = errorData['message'] ?? errorData['detail'] ?? errorData['title'];
        if (msg != null) errorMessage = msg.toString();
      }
    }

    throw AuthException(
      code: errorCode,
      message: errorMessage,
      statusCode: statusCode,
    );
  }
}
