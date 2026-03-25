// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post_api_maps_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PostApiMapsResponse _$PostApiMapsResponseFromJson(Map<String, dynamic> json) =>
    PostApiMapsResponse(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      createdAt: json['createdAt'] as String,
    );

Map<String, dynamic> _$PostApiMapsResponseToJson(
  PostApiMapsResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'name': instance.name,
  'description': instance.description,
  'createdAt': instance.createdAt,
};
