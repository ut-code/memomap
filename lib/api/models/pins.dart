// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'pins.g.dart';

@JsonSerializable()
class Pins {
  const Pins({
    required this.latitude,
    required this.longitude,
    this.mapId,
  });
  
  factory Pins.fromJson(Map<String, Object?> json) => _$PinsFromJson(json);
  
  final num latitude;
  final num longitude;
  final String? mapId;

  Map<String, Object?> toJson() => _$PinsToJson(this);
}
