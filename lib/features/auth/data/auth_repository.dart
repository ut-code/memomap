import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:memomap/config/backend_config.dart';
import 'package:memomap/features/auth/data/auth_models.dart';
import 'package:memomap/features/auth/data/token_storage.dart';

export 'package:memomap/features/auth/data/auth_models.dart';

class AuthRepository {
  AuthRepository._internal(this._dio);

  final Dio _dio;

  static AuthRepository? _instance;

  static Future<AuthRepository> getInstance() async {
    if (_instance != null) return _instance!;
    final dio = await BackendConfig.createDio();
    _instance = AuthRepository._internal(dio);
    return _instance!;
  }

  String get _authBaseUrl => '${BackendConfig.url}/api/auth';

  Future<SessionResponse?> getSession() async {
    try {
      final response = await _dio.get('$_authBaseUrl/get-session');

      await _extractSessionInfo(response);

      if (response.data == null) return null;

      final data = response.data as Map<String, dynamic>;
      if (data['session'] == null || data['user'] == null) return null;

      return SessionResponse.fromJson(data);
    } on DioException {
      await TokenStorage.deleteToken();
      return null;
    }
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '$_authBaseUrl/sign-up/email',
        data: {
          'name': email.split('@').first,
          'email': email,
          'password': password,
        },
      );

      await _extractSessionInfo(response);
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '$_authBaseUrl/sign-in/email',
        data: {
          'email': email,
          'password': password,
        },
      );

      await _extractSessionInfo(response);
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      throw UnsupportedError('Use renderButton on web');
    }

    final serverClientId = dotenv.env['GOOGLE_SERVER_CLIENT_ID'];
    final googleSignIn = GoogleSignIn(
      scopes: ['email', 'profile'],
      serverClientId: serverClientId,
    );

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('Google sign-in was cancelled');
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      throw Exception('Failed to get Google ID token');
    }

    await signInWithGoogleIdToken(idToken);
  }

  Future<void> signInWithGoogleIdToken(String idToken) async {
    final response = await _dio.post(
      '$_authBaseUrl/sign-in/social',
      data: {
        'provider': 'google',
        'idToken': {'token': idToken},
      },
    );

    await _extractSessionInfo(response);
  }

  Future<void> signOut() async {
    try {
      await _dio.post('$_authBaseUrl/sign-out', data: {});
    } catch (_) {
      // Ignore errors during sign-out
    }

    await TokenStorage.deleteToken();
    await BackendConfig.clearCookies();

    final googleSignIn = GoogleSignIn();
    await googleSignIn.signOut();
  }

  Future<void> _extractSessionInfo(Response response) async {
    final data = response.data as Map<String, dynamic>?;
    if (data?['session']?['id'] case final String sessionId) {
      await TokenStorage.saveSessionId(sessionId);
    }
  }

  String _extractErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      if (data['message'] != null) {
        return data['message'].toString();
      }
    }
    return e.message ?? 'An error occurred';
  }
}
