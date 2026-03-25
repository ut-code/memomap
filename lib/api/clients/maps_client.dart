// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/api_maps_id_request_body.dart';
import '../models/api_maps_request_body.dart';
import '../models/get_api_maps_response.dart';
import '../models/post_api_maps_response.dart';
import '../models/put_api_maps_id_response.dart';

part 'maps_client.g.dart';

@RestApi()
abstract class MapsClient {
  factory MapsClient(Dio dio, {String? baseUrl}) = _MapsClient;

  /// Get all maps for current user
  @GET('/api/maps')
  Future<List<GetApiMapsResponse>> getApiMaps();

  /// Create a new map
  @POST('/api/maps')
  Future<PostApiMapsResponse> postApiMaps({
    @Body() ApiMapsRequestBody? body,
  });

  /// Update a map
  @PUT('/api/maps/{id}')
  Future<PutApiMapsIdResponse> putApiMapsById({
    @Path('id') required String id,
    @Body() ApiMapsIdRequestBody? body,
  });

  /// Delete a map (and all associated pins/drawings)
  @DELETE('/api/maps/{id}')
  Future<void> deleteApiMapsById({
    @Path('id') required String id,
  });
}
