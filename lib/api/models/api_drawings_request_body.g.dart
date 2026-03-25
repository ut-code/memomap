// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_drawings_request_body.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ApiDrawingsRequestBody _$ApiDrawingsRequestBodyFromJson(
  Map<String, dynamic> json,
) => ApiDrawingsRequestBody(
  points: (json['points'] as List<dynamic>)
      .map((e) => Points3.fromJson(e as Map<String, dynamic>))
      .toList(),
  color: json['color'] as String,
  strokeWidth: json['strokeWidth'] as num,
  mapId: json['mapId'] as String?,
);

Map<String, dynamic> _$ApiDrawingsRequestBodyToJson(
  ApiDrawingsRequestBody instance,
) => <String, dynamic>{
  'points': instance.points,
  'color': instance.color,
  'strokeWidth': instance.strokeWidth,
  'mapId': instance.mapId,
};
