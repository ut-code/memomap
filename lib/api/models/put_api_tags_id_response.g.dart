// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'put_api_tags_id_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PutApiTagsIdResponse _$PutApiTagsIdResponseFromJson(
  Map<String, dynamic> json,
) => PutApiTagsIdResponse(
  id: json['id'] as String,
  userId: json['userId'] as String,
  name: json['name'] as String,
  color: json['color'] as String,
  createdAt: json['createdAt'] as String,
  mapId: json['mapId'] as String?,
);

Map<String, dynamic> _$PutApiTagsIdResponseToJson(
  PutApiTagsIdResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'mapId': instance.mapId,
  'name': instance.name,
  'color': instance.color,
  'createdAt': instance.createdAt,
};
