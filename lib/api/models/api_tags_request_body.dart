// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'api_tags_request_body.g.dart';

@JsonSerializable()
class ApiTagsRequestBody {
  const ApiTagsRequestBody({
    required this.name,
    required this.color,
  });
  
  factory ApiTagsRequestBody.fromJson(Map<String, Object?> json) => _$ApiTagsRequestBodyFromJson(json);
  
  final String name;
  final String color;

  Map<String, Object?> toJson() => _$ApiTagsRequestBodyToJson(this);
}
