// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_drawings_batch_request_body.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ApiDrawingsBatchRequestBody _$ApiDrawingsBatchRequestBodyFromJson(
  Map<String, dynamic> json,
) => ApiDrawingsBatchRequestBody(
  drawings: (json['drawings'] as List<dynamic>)
      .map((e) => Drawings.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$ApiDrawingsBatchRequestBodyToJson(
  ApiDrawingsBatchRequestBody instance,
) => <String, dynamic>{'drawings': instance.drawings};
