// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'post_api_maps_response.g.dart';

@JsonSerializable()
class PostApiMapsResponse {
  const PostApiMapsResponse({
    required this.id,
    required this.userId,
    required this.name,
    required this.description,
    required this.createdAt,
  });
  
  factory PostApiMapsResponse.fromJson(Map<String, Object?> json) => _$PostApiMapsResponseFromJson(json);
  
  final String id;
  final String userId;
  final String name;
  final String? description;
  final String createdAt;

  Map<String, Object?> toJson() => _$PostApiMapsResponseToJson(this);
}
