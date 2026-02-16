import 'package:shared_preferences/shared_preferences.dart';
import 'storage_service.dart';

// Web implementation using SharedPreferences
class StorageServiceWeb implements StorageService {
  static SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  @override
  Future<void> saveAccessToken(String token) async {
    final prefs = await _preferences;
    await prefs.setString(StorageService.accessTokenKey, token);
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    final prefs = await _preferences;
    await prefs.setString(StorageService.refreshTokenKey, token);
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
    final prefs = await _preferences;
    return prefs.getString(StorageService.accessTokenKey);
  }

  @override
  Future<String?> getRefreshToken() async {
    final prefs = await _preferences;
    return prefs.getString(StorageService.refreshTokenKey);
  }

  @override
  Future<void> deleteAccessToken() async {
    final prefs = await _preferences;
    await prefs.remove(StorageService.accessTokenKey);
  }

  @override
  Future<void> deleteRefreshToken() async {
    final prefs = await _preferences;
    await prefs.remove(StorageService.refreshTokenKey);
  }

  @override
  Future<void> deleteAllTokens() async {
    final prefs = await _preferences;
    await prefs.remove(StorageService.accessTokenKey);
    await prefs.remove(StorageService.refreshTokenKey);
  }

  @override
  Future<bool> isLoggedIn() async {
    final accessToken = await getAccessToken();
    return accessToken != null && accessToken.isNotEmpty;
  }

  @override
  Future<void> clearAll() async {
    await deleteAllTokens();
  }
}

StorageService getStorageService() {
  return StorageServiceWeb();
}
