// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'put_api_tags_id_response.g.dart';

@JsonSerializable()
class PutApiTagsIdResponse {
  const PutApiTagsIdResponse({
    required this.id,
    required this.userId,
    required this.name,
    required this.color,
    required this.createdAt,
  });
  
  factory PutApiTagsIdResponse.fromJson(Map<String, Object?> json) => _$PutApiTagsIdResponseFromJson(json);
  
  final String id;
  final String userId;
  final String name;
  final String color;
  final String createdAt;

  Map<String, Object?> toJson() => _$PutApiTagsIdResponseToJson(this);
}
