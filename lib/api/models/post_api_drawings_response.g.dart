// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post_api_drawings_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PostApiDrawingsResponse _$PostApiDrawingsResponseFromJson(
  Map<String, dynamic> json,
) => PostApiDrawingsResponse(
  id: json['id'] as String,
  userId: json['userId'] as String,
  mapId: json['mapId'] as String?,
  points: (json['points'] as List<dynamic>)
      .map((e) => Points2.fromJson(e as Map<String, dynamic>))
      .toList(),
  color: json['color'] as String,
  strokeWidth: json['strokeWidth'] as num,
  createdAt: json['createdAt'] as String,
);

Map<String, dynamic> _$PostApiDrawingsResponseToJson(
  PostApiDrawingsResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'mapId': instance.mapId,
  'points': instance.points,
  'color': instance.color,
  'strokeWidth': instance.strokeWidth,
  'createdAt': instance.createdAt,
};
