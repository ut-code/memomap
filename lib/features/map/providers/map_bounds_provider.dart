import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

class MapBounds {
  final LatLng center;
  final double radius;

  const MapBounds({
    required this.center,
    required this.radius,
  });

  bool contains(LatLng point) {
    // 中心からの距離を計算
    final latDiff = center.latitude - point.latitude;
    final lngDiff = center.longitude - point.longitude;
    final distance = math.sqrt(latDiff * latDiff + lngDiff * lngDiff);
    
    return distance <= radius;
  }
}

final mapBoundsProvider = StateProvider<MapBounds?>((ref) => null);
