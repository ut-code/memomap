// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/api_tags_id_request_body.dart';
import '../models/api_tags_request_body.dart';
import '../models/get_api_tags_response.dart';
import '../models/post_api_tags_response.dart';
import '../models/put_api_tags_id_response.dart';

part 'tags_client.g.dart';

@RestApi()
abstract class TagsClient {
  factory TagsClient(Dio dio, {String? baseUrl}) = _TagsClient;

  /// Get all tags for current user
  @GET('/api/tags')
  Future<List<GetApiTagsResponse>> getApiTags();

  /// Create a new tag
  @POST('/api/tags')
  Future<PostApiTagsResponse> postApiTags({
    @Body() ApiTagsRequestBody? body,
  });

  /// Update a tag
  @PUT('/api/tags/{id}')
  Future<PutApiTagsIdResponse> putApiTagsById({
    @Path('id') required String id,
    @Body() ApiTagsIdRequestBody? body,
  });

  /// Delete a tag
  @DELETE('/api/tags/{id}')
  Future<void> deleteApiTagsById({
    @Path('id') required String id,
  });
}
