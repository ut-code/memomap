// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'points.dart';

part 'get_api_drawings_response.g.dart';

@JsonSerializable()
class GetApiDrawingsResponse {
  const GetApiDrawingsResponse({
    required this.id,
    required this.userId,
    required this.mapId,
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.createdAt,
  });
  
  factory GetApiDrawingsResponse.fromJson(Map<String, Object?> json) => _$GetApiDrawingsResponseFromJson(json);
  
  final String id;
  final String userId;
  final String? mapId;
  final List<Points> points;
  final String color;
  final num strokeWidth;
  final String createdAt;

  Map<String, Object?> toJson() => _$GetApiDrawingsResponseToJson(this);
}
