import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/document_submission.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../utils/auth_errors.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  
  User? _user;
  PersonalData? _profilePersonalData;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isAuthenticated = false;

  User? get user => _user;
  PersonalData? get profilePersonalData => _profilePersonalData;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _isAuthenticated;

  AuthProvider() {
    _checkAuthStatus();
  }

  /// Check if user is already authenticated
  Future<void> _checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      final storage = StorageService.instance;
      final isLoggedIn = await storage.isLoggedIn();
      if (isLoggedIn) {
        // Try to get current user
        try {
          await getCurrentUser();
        } catch (e) {
          // Only clear auth state if it's an authentication error (401/403)
          // Don't clear on network errors - user might be offline
          if (e is AuthException) {
            final statusCode = e.statusCode;
            if (statusCode == 401 || statusCode == 403) {
              // Token is invalid or expired, clear auth state
              await logout();
            } else {
              // Network or other error - keep tokens but don't set authenticated
              _isAuthenticated = false;
              _user = null;
            }
          } else {
            // Unknown error - keep tokens but don't set authenticated
            _isAuthenticated = false;
            _user = null;
          }
        }
      } else {
        _isAuthenticated = false;
        _user = null;
      }
    } catch (e) {
      // If storage check fails, assume not authenticated
      _isAuthenticated = false;
      _user = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Login with email and password
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.login(email, password);
      _user = result['user'] as User;
      _isAuthenticated = true;
      _profilePersonalData = null;

      // Best effort: hydrate profile details from /auth/me
      try {
        final me = await _authService.getMe();
        _user = me.user;
        _profilePersonalData = me.personalData;
      } catch (_) {
        // Ignore; keep the user from login response
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      if (e is AuthException) {
        _errorMessage = e.userFriendlyMessage;
      } else {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      }
      _isLoading = false;
      _isAuthenticated = false;
      _profilePersonalData = null;
      notifyListeners();
      return false;
    }
  }

  /// Get current authenticated user
  Future<void> getCurrentUser() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final me = await _authService.getMe();
      _user = me.user;
      _profilePersonalData = me.personalData;
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      if (e is AuthException) {
        _errorMessage = e.userFriendlyMessage;
      } else {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      }
      _isLoading = false;
      _isAuthenticated = false;
      _user = null;
      _profilePersonalData = null;
      notifyListeners();
      rethrow;
    }
  }

  /// Logout
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.logout();
      _user = null;
      _profilePersonalData = null;
      _isAuthenticated = false;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Request password reset (forgot password) - accepts email or phone
  Future<Map<String, dynamic>?> forgotPassword(String identifier) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.forgotPassword(identifier);
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      if (e is AuthException) {
        _errorMessage = e.userFriendlyMessage;
      } else {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      }
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }
}
