// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drawings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Drawings _$DrawingsFromJson(Map<String, dynamic> json) => Drawings(
  points: (json['points'] as List<dynamic>)
      .map((e) => Points5.fromJson(e as Map<String, dynamic>))
      .toList(),
  color: json['color'] as String,
  strokeWidth: json['strokeWidth'] as num,
  mapId: json['mapId'] as String?,
);

Map<String, dynamic> _$DrawingsToJson(Drawings instance) => <String, dynamic>{
  'points': instance.points,
  'color': instance.color,
  'strokeWidth': instance.strokeWidth,
  'mapId': instance.mapId,
};
