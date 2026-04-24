// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post_api_tags_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PostApiTagsResponse _$PostApiTagsResponseFromJson(Map<String, dynamic> json) =>
    PostApiTagsResponse(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      color: json['color'] as String,
      createdAt: json['createdAt'] as String,
    );

Map<String, dynamic> _$PostApiTagsResponseToJson(
  PostApiTagsResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'name': instance.name,
  'color': instance.color,
  'createdAt': instance.createdAt,
};
