// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'get_api_me_response.g.dart';

@JsonSerializable()
class GetApiMeResponse {
  const GetApiMeResponse({
    required this.userId,
    required this.email,
  });
  
  factory GetApiMeResponse.fromJson(Map<String, Object?> json) => _$GetApiMeResponseFromJson(json);
  
  final String userId;
  final String email;

  Map<String, Object?> toJson() => _$GetApiMeResponseToJson(this);
}
