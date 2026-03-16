// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_api_maps_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GetApiMapsResponse _$GetApiMapsResponseFromJson(Map<String, dynamic> json) =>
    GetApiMapsResponse(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      createdAt: json['createdAt'] as String,
    );

Map<String, dynamic> _$GetApiMapsResponseToJson(GetApiMapsResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'name': instance.name,
      'description': instance.description,
      'createdAt': instance.createdAt,
    };
