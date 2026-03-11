// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'drawings.dart';

part 'api_drawings_batch_request_body.g.dart';

@JsonSerializable()
class ApiDrawingsBatchRequestBody {
  const ApiDrawingsBatchRequestBody({
    required this.drawings,
  });
  
  factory ApiDrawingsBatchRequestBody.fromJson(Map<String, Object?> json) => _$ApiDrawingsBatchRequestBodyFromJson(json);
  
  final List<Drawings> drawings;

  Map<String, Object?> toJson() => _$ApiDrawingsBatchRequestBodyToJson(this);
}
