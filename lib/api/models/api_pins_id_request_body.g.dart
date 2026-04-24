// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_pins_id_request_body.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ApiPinsIdRequestBody _$ApiPinsIdRequestBodyFromJson(
  Map<String, dynamic> json,
) => ApiPinsIdRequestBody(
  tagIds: (json['tagIds'] as List<dynamic>?)?.map((e) => e as String).toList(),
);

Map<String, dynamic> _$ApiPinsIdRequestBodyToJson(
  ApiPinsIdRequestBody instance,
) => <String, dynamic>{'tagIds': instance.tagIds};
