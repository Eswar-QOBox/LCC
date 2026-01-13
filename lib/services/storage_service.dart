// Conditional imports for platform-specific storage
import 'storage_service_stub.dart'
    if (dart.library.io) 'storage_service_mobile.dart'
    if (dart.library.html) 'storage_service_web.dart';

abstract class StorageService {
  // Token keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';

  // Factory constructor to get the appropriate implementation
  static StorageService get instance {
    return getStorageService();
  }

  // Save tokens
  Future<void> saveAccessToken(String token);
  Future<void> saveRefreshToken(String token);
  Future<void> saveTokens(String accessToken, String refreshToken);

  // Read tokens
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();

  // Delete tokens
  Future<void> deleteAccessToken();
  Future<void> deleteRefreshToken();
  Future<void> deleteAllTokens();

  // Check if user is logged in
  Future<bool> isLoggedIn();

  // Clear all data (logout)
  Future<void> clearAll();
}
