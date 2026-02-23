// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/get_health_response.dart';

part 'system_client.g.dart';

@RestApi()
abstract class SystemClient {
  factory SystemClient(Dio dio, {String? baseUrl}) = _SystemClient;

  /// Health check
  @GET('/health')
  Future<GetHealthResponse> getHealth();
}
