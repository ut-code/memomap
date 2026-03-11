// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';

import 'clients/system_client.dart';
import 'clients/user_client.dart';
import 'clients/pins_client.dart';
import 'clients/drawings_client.dart';

/// Memomap API `v1.0.0`.
///
/// Backend API for Memomap application.
class ApiClient {
  ApiClient(
    Dio dio, {
    String? baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  final Dio _dio;
  final String? _baseUrl;

  static String get version => '1.0.0';

  SystemClient? _system;
  UserClient? _user;
  PinsClient? _pins;
  DrawingsClient? _drawings;

  SystemClient get system => _system ??= SystemClient(_dio, baseUrl: _baseUrl);

  UserClient get user => _user ??= UserClient(_dio, baseUrl: _baseUrl);

  PinsClient get pins => _pins ??= PinsClient(_dio, baseUrl: _baseUrl);

  DrawingsClient get drawings => _drawings ??= DrawingsClient(_dio, baseUrl: _baseUrl);
}
