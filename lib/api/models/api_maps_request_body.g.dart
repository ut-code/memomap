// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_maps_request_body.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ApiMapsRequestBody _$ApiMapsRequestBodyFromJson(Map<String, dynamic> json) =>
    ApiMapsRequestBody(
      name: json['name'] as String,
      description: json['description'] as String?,
    );

Map<String, dynamic> _$ApiMapsRequestBodyToJson(ApiMapsRequestBody instance) =>
    <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
    };
