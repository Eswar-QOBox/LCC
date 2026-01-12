/// Authentication error codes from the API
class AuthErrorCodes {
  static const String invalidCredentials = 'INVALID_CREDENTIALS';
  static const String unauthorized = 'UNAUTHORIZED';
  static const String forbidden = 'FORBIDDEN';
  static const String accountDisabled = 'ACCOUNT_DISABLED';
  static const String notFound = 'NOT_FOUND';
  static const String validationError = 'VALIDATION_ERROR';
  static const String conflict = 'CONFLICT';
  static const String rateLimitExceeded = 'RATE_LIMIT_EXCEEDED';
  static const String internalError = 'INTERNAL_ERROR';
}

/// Custom exception for authentication errors
class AuthException implements Exception {
  final String code;
  final String message;
  final int? statusCode;

  AuthException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  @override
  String toString() => message;

  /// Get user-friendly error message based on error code
  String get userFriendlyMessage {
    switch (code) {
      case AuthErrorCodes.invalidCredentials:
        return 'Invalid email or password. Please check your credentials and try again.';
      case AuthErrorCodes.accountDisabled:
        return 'Your account has been disabled. Please contact your administrator.';
      case AuthErrorCodes.unauthorized:
        return 'You are not authorized to perform this action.';
      case AuthErrorCodes.forbidden:
        return 'Access forbidden. You do not have permission to access this resource.';
      case AuthErrorCodes.rateLimitExceeded:
        return 'Too many requests. Please wait a moment and try again.';
      case AuthErrorCodes.validationError:
        return 'Invalid input. Please check your information and try again.';
      case AuthErrorCodes.conflict:
        return 'This resource already exists.';
      case AuthErrorCodes.notFound:
        return 'The requested resource was not found.';
      case AuthErrorCodes.internalError:
        return 'An internal error occurred. Please try again later.';
      default:
        return message.isNotEmpty ? message : 'An error occurred. Please try again.';
    }
  }

  /// Check if error requires user to contact admin
  bool get requiresAdminContact {
    return code == AuthErrorCodes.accountDisabled;
  }

  /// Check if error is due to invalid credentials
  bool get isInvalidCredentials {
    return code == AuthErrorCodes.invalidCredentials;
  }

  /// Check if error is due to network issues
  bool get isNetworkError {
    return code == 'NETWORK_ERROR' || code == 'CONNECTION_ERROR';
  }
}
