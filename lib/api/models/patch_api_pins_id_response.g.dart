// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patch_api_pins_id_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchApiPinsIdResponse _$PatchApiPinsIdResponseFromJson(
  Map<String, dynamic> json,
) => PatchApiPinsIdResponse(
  id: json['id'] as String,
  userId: json['userId'] as String,
  mapId: json['mapId'] as String?,
  latitude: json['latitude'] as num,
  longitude: json['longitude'] as num,
  createdAt: json['createdAt'] as String,
  tagIds: (json['tagIds'] as List<dynamic>).map((e) => e as String).toList(),
);

Map<String, dynamic> _$PatchApiPinsIdResponseToJson(
  PatchApiPinsIdResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'mapId': instance.mapId,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'createdAt': instance.createdAt,
  'tagIds': instance.tagIds,
};
