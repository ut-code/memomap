// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'put_api_pins_id_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PutApiPinsIdResponse _$PutApiPinsIdResponseFromJson(
  Map<String, dynamic> json,
) => PutApiPinsIdResponse(
  id: json['id'] as String,
  userId: json['userId'] as String,
  mapId: json['mapId'] as String?,
  latitude: json['latitude'] as num,
  longitude: json['longitude'] as num,
  createdAt: json['createdAt'] as String,
  memo: json['memo'] as String?,
);

Map<String, dynamic> _$PutApiPinsIdResponseToJson(
  PutApiPinsIdResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'mapId': instance.mapId,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'createdAt': instance.createdAt,
  'memo': instance.memo,
};
