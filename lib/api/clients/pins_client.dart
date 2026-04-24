// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/api_pins_batch_request_body.dart';
import '../models/api_pins_id_request_body.dart';
import '../models/api_pins_request_body.dart';
import '../models/get_api_pins_response.dart';
import '../models/patch_api_pins_id_response.dart';
import '../models/post_api_pins_batch_response.dart';
import '../models/post_api_pins_response.dart';

part 'pins_client.g.dart';

@RestApi()
abstract class PinsClient {
  factory PinsClient(Dio dio, {String? baseUrl}) = _PinsClient;

  /// Get all pins for current user
  @GET('/api/pins')
  Future<List<GetApiPinsResponse>> getApiPins();

  /// Create a new pin
  @POST('/api/pins')
  Future<PostApiPinsResponse> postApiPins({
    @Body() ApiPinsRequestBody? body,
  });

  /// Delete a pin
  @DELETE('/api/pins/{id}')
  Future<void> deleteApiPinsById({
    @Path('id') required String id,
  });

  /// Update pin tags
  @PATCH('/api/pins/{id}')
  Future<PatchApiPinsIdResponse> patchApiPinsById({
    @Path('id') required String id,
    @Body() ApiPinsIdRequestBody? body,
  });

  /// Create multiple pins at once
  @POST('/api/pins/batch')
  Future<List<PostApiPinsBatchResponse>> postApiPinsBatch({
    @Body() ApiPinsBatchRequestBody? body,
  });
}
