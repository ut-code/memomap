// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post_api_pins_batch_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PostApiPinsBatchResponse _$PostApiPinsBatchResponseFromJson(
  Map<String, dynamic> json,
) => PostApiPinsBatchResponse(
  id: json['id'] as String,
  userId: json['userId'] as String,
  latitude: json['latitude'] as num,
  longitude: json['longitude'] as num,
  createdAt: json['createdAt'] as String,
);

Map<String, dynamic> _$PostApiPinsBatchResponseToJson(
  PostApiPinsBatchResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'createdAt': instance.createdAt,
};
