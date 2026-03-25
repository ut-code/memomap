// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pins.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Pins _$PinsFromJson(Map<String, dynamic> json) => Pins(
  latitude: json['latitude'] as num,
  longitude: json['longitude'] as num,
  mapId: json['mapId'] as String?,
);

Map<String, dynamic> _$PinsToJson(Pins instance) => <String, dynamic>{
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'mapId': instance.mapId,
};
