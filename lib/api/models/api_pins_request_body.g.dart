// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_pins_request_body.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ApiPinsRequestBody _$ApiPinsRequestBodyFromJson(Map<String, dynamic> json) =>
    ApiPinsRequestBody(
      latitude: json['latitude'] as num,
      longitude: json['longitude'] as num,
    );

Map<String, dynamic> _$ApiPinsRequestBodyToJson(ApiPinsRequestBody instance) =>
    <String, dynamic>{
      'latitude': instance.latitude,
      'longitude': instance.longitude,
    };
