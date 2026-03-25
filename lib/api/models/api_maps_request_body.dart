// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'api_maps_request_body.g.dart';

@JsonSerializable()
class ApiMapsRequestBody {
  const ApiMapsRequestBody({
    required this.name,
    this.description,
  });
  
  factory ApiMapsRequestBody.fromJson(Map<String, Object?> json) => _$ApiMapsRequestBodyFromJson(json);
  
  final String name;
  final String? description;

  Map<String, Object?> toJson() => _$ApiMapsRequestBodyToJson(this);
}
