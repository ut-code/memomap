// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'patch_api_pins_id_response.g.dart';

@JsonSerializable()
class PatchApiPinsIdResponse {
  const PatchApiPinsIdResponse({
    required this.id,
    required this.userId,
    required this.mapId,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    required this.tagIds,
  });
  
  factory PatchApiPinsIdResponse.fromJson(Map<String, Object?> json) => _$PatchApiPinsIdResponseFromJson(json);
  
  final String id;
  final String userId;
  final String? mapId;
  final num latitude;
  final num longitude;
  final String createdAt;
  final List<String> tagIds;

  Map<String, Object?> toJson() => _$PatchApiPinsIdResponseToJson(this);
}
