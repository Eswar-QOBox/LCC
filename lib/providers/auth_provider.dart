import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../utils/auth_errors.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  
  User? _user;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isAuthenticated = false;

  User? get user => _user;
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
        await getCurrentUser();
      }
    } catch (e) {
      // If getting user fails, clear auth state
      await logout();
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
      _user = await _authService.getCurrentUser();
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
}
