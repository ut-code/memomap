// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'points.g.dart';

@JsonSerializable()
class Points {
  const Points({
    required this.lat,
    required this.lng,
  });
  
  factory Points.fromJson(Map<String, Object?> json) => _$PointsFromJson(json);
  
  final num lat;
  final num lng;

  Map<String, Object?> toJson() => _$PointsToJson(this);
}
