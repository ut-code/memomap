// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'points3.g.dart';

@JsonSerializable()
class Points3 {
  const Points3({
    required this.lat,
    required this.lng,
  });
  
  factory Points3.fromJson(Map<String, Object?> json) => _$Points3FromJson(json);
  
  final num lat;
  final num lng;

  Map<String, Object?> toJson() => _$Points3ToJson(this);
}
