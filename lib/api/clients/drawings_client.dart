// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/api_drawings_batch_request_body.dart';
import '../models/api_drawings_request_body.dart';
import '../models/get_api_drawings_response.dart';
import '../models/post_api_drawings_batch_response.dart';
import '../models/post_api_drawings_response.dart';

part 'drawings_client.g.dart';

@RestApi()
abstract class DrawingsClient {
  factory DrawingsClient(Dio dio, {String? baseUrl}) = _DrawingsClient;

  /// Get all drawings for current user
  @GET('/api/drawings')
  Future<List<GetApiDrawingsResponse>> getApiDrawings();

  /// Create a new drawing
  @POST('/api/drawings')
  Future<PostApiDrawingsResponse> postApiDrawings({
    @Body() ApiDrawingsRequestBody? body,
  });

  /// Delete a drawing
  @DELETE('/api/drawings/{id}')
  Future<void> deleteApiDrawingsById({
    @Path('id') required String id,
  });

  /// Create multiple drawings at once
  @POST('/api/drawings/batch')
  Future<List<PostApiDrawingsBatchResponse>> postApiDrawingsBatch({
    @Body() ApiDrawingsBatchRequestBody? body,
  });
}
