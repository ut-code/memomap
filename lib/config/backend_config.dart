import 'dart:io' show Platform;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:memomap/api/api_client.dart';
import 'package:path_provider/path_provider.dart';

class BackendConfig {
  static const _port = '8787';
  static PersistCookieJar? _cookieJar;

  static String get url {
    if (dotenv.env['BACKEND_URL'] case final url? when url.isNotEmpty) {
      return url;
    }
    if (kIsWeb) {
      return 'http://localhost:$_port';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:$_port';
    }
    return 'http://localhost:$_port';
  }

  static Future<PersistCookieJar> getCookieJar() async {
    if (_cookieJar != null) return _cookieJar!;
    final dir = await getApplicationDocumentsDirectory();
    _cookieJar = PersistCookieJar(
      ignoreExpires: false,
      storage: FileStorage('${dir.path}/.cookies/'),
    );
    return _cookieJar!;
  }

  static Future<Dio> createDio() async {
    final dio = Dio(BaseOptions(
      baseUrl: url,
      extra: {'withCredentials': true},
    ));

    if (!kIsWeb) {
      final cookieJar = await getCookieJar();
      dio.interceptors.add(CookieManager(cookieJar));
    }

    return dio;
  }

  static Future<ApiClient> createApiClient() async {
    return ApiClient(await createDio());
  }

  static Future<void> clearCookies() async {
    if (!kIsWeb && _cookieJar != null) {
      await _cookieJar!.deleteAll();
    }
  }
}
