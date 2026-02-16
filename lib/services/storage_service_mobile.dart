import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'storage_service.dart';

// Mobile implementation using FlutterSecureStorage
class StorageServiceMobile implements StorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  @override
  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: StorageService.accessTokenKey, value: token);
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: StorageService.refreshTokenKey, value: token);
  }

  @override
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await Future.wait([
      saveAccessToken(accessToken),
      saveRefreshToken(refreshToken),
    ]);
  }

  @override
  Future<String?> getAccessToken() async {
    return await _storage.read(key: StorageService.accessTokenKey);
  }

  @override
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: StorageService.refreshTokenKey);
  }

  @override
  Future<void> deleteAccessToken() async {
    await _storage.delete(key: StorageService.accessTokenKey);
  }

  @override
  Future<void> deleteRefreshToken() async {
    await _storage.delete(key: StorageService.refreshTokenKey);
  }

  @override
  Future<void> deleteAllTokens() async {
    await _storage.deleteAll();
  }

  @override
  Future<bool> isLoggedIn() async {
    final accessToken = await getAccessToken();
    return accessToken != null && accessToken.isNotEmpty;
  }

  @override
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}

StorageService getStorageService() {
  return StorageServiceMobile();
}
