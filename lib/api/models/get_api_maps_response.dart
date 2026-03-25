// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'get_api_maps_response.g.dart';

@JsonSerializable()
class GetApiMapsResponse {
  const GetApiMapsResponse({
    required this.id,
    required this.userId,
    required this.name,
    required this.description,
    required this.createdAt,
  });
  
  factory GetApiMapsResponse.fromJson(Map<String, Object?> json) => _$GetApiMapsResponseFromJson(json);
  
  final String id;
  final String userId;
  final String name;
  final String? description;
  final String createdAt;

  Map<String, Object?> toJson() => _$GetApiMapsResponseToJson(this);
}
