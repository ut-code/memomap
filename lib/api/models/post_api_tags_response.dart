// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'post_api_tags_response.g.dart';

@JsonSerializable()
class PostApiTagsResponse {
  const PostApiTagsResponse({
    required this.id,
    required this.userId,
    required this.name,
    required this.color,
    required this.createdAt,
  });
  
  factory PostApiTagsResponse.fromJson(Map<String, Object?> json) => _$PostApiTagsResponseFromJson(json);
  
  final String id;
  final String userId;
  final String name;
  final String color;
  final String createdAt;

  Map<String, Object?> toJson() => _$PostApiTagsResponseToJson(this);
}
