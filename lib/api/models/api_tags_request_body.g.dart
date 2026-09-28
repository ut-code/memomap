// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_tags_request_body.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ApiTagsRequestBody _$ApiTagsRequestBodyFromJson(Map<String, dynamic> json) =>
    ApiTagsRequestBody(
      name: json['name'] as String,
      color: json['color'] as String,
      mapId: json['mapId'] as String?,
    );

Map<String, dynamic> _$ApiTagsRequestBodyToJson(ApiTagsRequestBody instance) =>
    <String, dynamic>{
      'mapId': instance.mapId,
      'name': instance.name,
      'color': instance.color,
    };
