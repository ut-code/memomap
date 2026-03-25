// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'points4.g.dart';

@JsonSerializable()
class Points4 {
  const Points4({
    required this.lat,
    required this.lng,
  });
  
  factory Points4.fromJson(Map<String, Object?> json) => _$Points4FromJson(json);
  
  final num lat;
  final num lng;

  Map<String, Object?> toJson() => _$Points4ToJson(this);
}
