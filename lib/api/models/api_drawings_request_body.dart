// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'points3.dart';

part 'api_drawings_request_body.g.dart';

@JsonSerializable()
class ApiDrawingsRequestBody {
  const ApiDrawingsRequestBody({
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.mapId,
  });
  
  factory ApiDrawingsRequestBody.fromJson(Map<String, Object?> json) => _$ApiDrawingsRequestBodyFromJson(json);
  
  final List<Points3> points;
  final String color;
  final num strokeWidth;
  final String? mapId;

  Map<String, Object?> toJson() => _$ApiDrawingsRequestBodyToJson(this);
}
