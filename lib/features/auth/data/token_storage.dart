import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _sessionIdKey = 'session_id';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> saveSessionId(String sessionId) async {
    await _storage.write(key: _sessionIdKey, value: sessionId);
  }

  static Future<String?> getSessionId() async {
    return _storage.read(key: _sessionIdKey);
  }

  static Future<void> deleteToken() async {
    await _storage.delete(key: _sessionIdKey);
  }
}
