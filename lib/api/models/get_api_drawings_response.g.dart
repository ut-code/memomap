// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_api_drawings_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GetApiDrawingsResponse _$GetApiDrawingsResponseFromJson(
  Map<String, dynamic> json,
) => GetApiDrawingsResponse(
  id: json['id'] as String,
  userId: json['userId'] as String,
  mapId: json['mapId'] as String?,
  points: (json['points'] as List<dynamic>)
      .map((e) => Points.fromJson(e as Map<String, dynamic>))
      .toList(),
  color: json['color'] as String,
  strokeWidth: json['strokeWidth'] as num,
  createdAt: json['createdAt'] as String,
);

Map<String, dynamic> _$GetApiDrawingsResponseToJson(
  GetApiDrawingsResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'mapId': instance.mapId,
  'points': instance.points,
  'color': instance.color,
  'strokeWidth': instance.strokeWidth,
  'createdAt': instance.createdAt,
};
