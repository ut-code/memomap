// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'api_maps_id_request_body.g.dart';

@JsonSerializable()
class ApiMapsIdRequestBody {
  const ApiMapsIdRequestBody({
    this.name,
    this.description,
  });
  
  factory ApiMapsIdRequestBody.fromJson(Map<String, Object?> json) => _$ApiMapsIdRequestBodyFromJson(json);
  
  final String? name;
  final String? description;

  Map<String, Object?> toJson() => _$ApiMapsIdRequestBodyToJson(this);
}
