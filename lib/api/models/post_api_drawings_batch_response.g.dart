// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post_api_drawings_batch_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PostApiDrawingsBatchResponse _$PostApiDrawingsBatchResponseFromJson(
  Map<String, dynamic> json,
) => PostApiDrawingsBatchResponse(
  id: json['id'] as String,
  userId: json['userId'] as String,
  mapId: json['mapId'] as String?,
  points: (json['points'] as List<dynamic>)
      .map((e) => Points4.fromJson(e as Map<String, dynamic>))
      .toList(),
  color: json['color'] as String,
  strokeWidth: json['strokeWidth'] as num,
  createdAt: json['createdAt'] as String,
);

Map<String, dynamic> _$PostApiDrawingsBatchResponseToJson(
  PostApiDrawingsBatchResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'mapId': instance.mapId,
  'points': instance.points,
  'color': instance.color,
  'strokeWidth': instance.strokeWidth,
  'createdAt': instance.createdAt,
};
