// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'put_api_maps_id_response.g.dart';

@JsonSerializable()
class PutApiMapsIdResponse {
  const PutApiMapsIdResponse({
    required this.id,
    required this.userId,
    required this.name,
    required this.description,
    required this.createdAt,
  });
  
  factory PutApiMapsIdResponse.fromJson(Map<String, Object?> json) => _$PutApiMapsIdResponseFromJson(json);
  
  final String id;
  final String userId;
  final String name;
  final String? description;
  final String createdAt;

  Map<String, Object?> toJson() => _$PutApiMapsIdResponseToJson(this);
}
