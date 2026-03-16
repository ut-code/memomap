// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'put_api_maps_id_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PutApiMapsIdResponse _$PutApiMapsIdResponseFromJson(
  Map<String, dynamic> json,
) => PutApiMapsIdResponse(
  id: json['id'] as String,
  userId: json['userId'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  createdAt: json['createdAt'] as String,
);

Map<String, dynamic> _$PutApiMapsIdResponseToJson(
  PutApiMapsIdResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'name': instance.name,
  'description': instance.description,
  'createdAt': instance.createdAt,
};
