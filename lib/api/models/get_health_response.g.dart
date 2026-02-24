// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_health_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GetHealthResponse _$GetHealthResponseFromJson(Map<String, dynamic> json) =>
    GetHealthResponse(
      status: json['status'] as String,
      timestamp: json['timestamp'] as String,
    );

Map<String, dynamic> _$GetHealthResponseToJson(GetHealthResponse instance) =>
    <String, dynamic>{
      'status': instance.status,
      'timestamp': instance.timestamp,
    };
