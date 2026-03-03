import 'dart:ui';
import 'package:latlong2/latlong.dart';

class DrawingPath {
  final List<LatLng> points;
  final Color color;
  final double strokeWidth;

  DrawingPath({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });

  DrawingPath copyWith({
    List<LatLng>? points,
    Color? color,
    double? strokeWidth,
  }) {
    return DrawingPath(
      points: points ?? this.points,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
    );
  }
}
