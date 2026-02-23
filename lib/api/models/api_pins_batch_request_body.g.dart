// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_pins_batch_request_body.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ApiPinsBatchRequestBody _$ApiPinsBatchRequestBodyFromJson(
  Map<String, dynamic> json,
) => ApiPinsBatchRequestBody(
  pins: (json['pins'] as List<dynamic>)
      .map((e) => Pins.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$ApiPinsBatchRequestBodyToJson(
  ApiPinsBatchRequestBody instance,
) => <String, dynamic>{'pins': instance.pins};
