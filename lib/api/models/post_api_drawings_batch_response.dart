// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'points4.dart';

part 'post_api_drawings_batch_response.g.dart';

@JsonSerializable()
class PostApiDrawingsBatchResponse {
  const PostApiDrawingsBatchResponse({
    required this.id,
    required this.userId,
    required this.mapId,
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.createdAt,
  });
  
  factory PostApiDrawingsBatchResponse.fromJson(Map<String, Object?> json) => _$PostApiDrawingsBatchResponseFromJson(json);
  
  final String id;
  final String userId;
  final String? mapId;
  final List<Points4> points;
  final String color;
  final num strokeWidth;
  final String createdAt;

  Map<String, Object?> toJson() => _$PostApiDrawingsBatchResponseToJson(this);
}
