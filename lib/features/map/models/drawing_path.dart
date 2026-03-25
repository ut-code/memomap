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

  factory DrawingPath.fromJson(Map<String, dynamic> json) {
    final pointsList = json['points'] as List<dynamic>;
    return DrawingPath(
      points: pointsList
          .map((p) => LatLng(
                (p['lat'] as num).toDouble(),
                (p['lng'] as num).toDouble(),
              ))
          .toList(),
      color: Color(json['color'] as int),
      strokeWidth: (json['strokeWidth'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'points': points
          .map((p) => {
                'lat': p.latitude,
                'lng': p.longitude,
              })
          .toList(),
      'color': color.toARGB32(),
      'strokeWidth': strokeWidth,
    };
  }

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
