import 'storage_service.dart';

// Stub for non-web, non-mobile platforms
class StorageServiceStub implements StorageService {
  @override
  Future<void> saveAccessToken(String token) async {
    throw UnimplementedError('Storage not available on this platform');
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    throw UnimplementedError('Storage not available on this platform');
  }

  @override
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    throw UnimplementedError('Storage not available on this platform');
  }

  @override
  Future<String?> getAccessToken() async {
    throw UnimplementedError('Storage not available on this platform');
  }

  @override
  Future<String?> getRefreshToken() async {
    throw UnimplementedError('Storage not available on this platform');
  }

  @override
  Future<void> deleteAccessToken() async {
    throw UnimplementedError('Storage not available on this platform');
  }

  @override
  Future<void> deleteRefreshToken() async {
    throw UnimplementedError('Storage not available on this platform');
  }

  @override
  Future<void> deleteAllTokens() async {
    throw UnimplementedError('Storage not available on this platform');
  }

  @override
  Future<bool> isLoggedIn() async {
    return false;
  }

  @override
  Future<void> clearAll() async {
    throw UnimplementedError('Storage not available on this platform');
  }
}

StorageService getStorageService() {
  return StorageServiceStub();
}
