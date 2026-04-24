// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'api_pins_id_request_body.g.dart';

@JsonSerializable()
class ApiPinsIdRequestBody {
  const ApiPinsIdRequestBody({
    this.tagIds,
  });
  
  factory ApiPinsIdRequestBody.fromJson(Map<String, Object?> json) => _$ApiPinsIdRequestBodyFromJson(json);
  
  final List<String>? tagIds;

  Map<String, Object?> toJson() => _$ApiPinsIdRequestBodyToJson(this);
}
