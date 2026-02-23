// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'get_api_pins_response.g.dart';

@JsonSerializable()
class GetApiPinsResponse {
  const GetApiPinsResponse({
    required this.id,
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
  });
  
  factory GetApiPinsResponse.fromJson(Map<String, Object?> json) => _$GetApiPinsResponseFromJson(json);
  
  final String id;
  final String userId;
  final num latitude;
  final num longitude;
  final String createdAt;

  Map<String, Object?> toJson() => _$GetApiPinsResponseToJson(this);
}
