// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'get_health_response.g.dart';

@JsonSerializable()
class GetHealthResponse {
  const GetHealthResponse({
    required this.status,
    required this.timestamp,
  });
  
  factory GetHealthResponse.fromJson(Map<String, Object?> json) => _$GetHealthResponseFromJson(json);
  
  final String status;
  final String timestamp;

  Map<String, Object?> toJson() => _$GetHealthResponseToJson(this);
}
