// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'points5.dart';

part 'drawings.g.dart';

@JsonSerializable()
class Drawings {
  const Drawings({
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.mapId,
  });
  
  factory Drawings.fromJson(Map<String, Object?> json) => _$DrawingsFromJson(json);
  
  final List<Points5> points;
  final String color;
  final num strokeWidth;
  final String? mapId;

  Map<String, Object?> toJson() => _$DrawingsToJson(this);
}
