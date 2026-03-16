// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'api_pins_request_body.g.dart';

@JsonSerializable()
class ApiPinsRequestBody {
  const ApiPinsRequestBody({
    required this.latitude,
    required this.longitude,
    this.mapId,
  });
  
  factory ApiPinsRequestBody.fromJson(Map<String, Object?> json) => _$ApiPinsRequestBodyFromJson(json);
  
  final num latitude;
  final num longitude;
  final String? mapId;

  Map<String, Object?> toJson() => _$ApiPinsRequestBodyToJson(this);
}
