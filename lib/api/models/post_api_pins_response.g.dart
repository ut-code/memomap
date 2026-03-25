// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post_api_pins_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PostApiPinsResponse _$PostApiPinsResponseFromJson(Map<String, dynamic> json) =>
    PostApiPinsResponse(
      id: json['id'] as String,
      userId: json['userId'] as String,
      mapId: json['mapId'] as String?,
      latitude: json['latitude'] as num,
      longitude: json['longitude'] as num,
      createdAt: json['createdAt'] as String,
    );

Map<String, dynamic> _$PostApiPinsResponseToJson(
  PostApiPinsResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'mapId': instance.mapId,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'createdAt': instance.createdAt,
};
