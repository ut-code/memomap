// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'get_api_tags_response.g.dart';

@JsonSerializable()
class GetApiTagsResponse {
  const GetApiTagsResponse({
    required this.id,
    required this.userId,
    required this.name,
    required this.color,
    required this.createdAt,
  });
  
  factory GetApiTagsResponse.fromJson(Map<String, Object?> json) => _$GetApiTagsResponseFromJson(json);
  
  final String id;
  final String userId;
  final String name;
  final String color;
  final String createdAt;

  Map<String, Object?> toJson() => _$GetApiTagsResponseToJson(this);
}
