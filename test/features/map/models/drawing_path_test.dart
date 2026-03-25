import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:memomap/features/map/models/drawing_path.dart';

void main() {
  group('DrawingPath serialization', () {
    test('toJson converts points, color, and strokeWidth correctly', () {
      final path = DrawingPath(
        points: [
          LatLng(35.681236, 139.767125),
          LatLng(35.689521, 139.691704),
        ],
        color: const Color(0xFFFF0000),
        strokeWidth: 5.0,
      );

      final json = path.toJson();

      expect(json['points'], [
        {'lat': 35.681236, 'lng': 139.767125},
        {'lat': 35.689521, 'lng': 139.691704},
      ]);
      expect(json['color'], 0xFFFF0000);
      expect(json['strokeWidth'], 5.0);
    });

    test('fromJson restores DrawingPath from JSON', () {
      final json = {
        'points': [
          {'lat': 35.681236, 'lng': 139.767125},
          {'lat': 35.689521, 'lng': 139.691704},
        ],
        'color': 0xFFFF0000,
        'strokeWidth': 5.0,
      };

      final path = DrawingPath.fromJson(json);

      expect(path.points.length, 2);
      expect(path.points[0].latitude, 35.681236);
      expect(path.points[0].longitude, 139.767125);
      expect(path.points[1].latitude, 35.689521);
      expect(path.points[1].longitude, 139.691704);
      expect(path.color, const Color(0xFFFF0000));
      expect(path.strokeWidth, 5.0);
    });

    test('roundtrip: toJson -> fromJson preserves data', () {
      final original = DrawingPath(
        points: [
          LatLng(35.681236, 139.767125),
          LatLng(35.689521, 139.691704),
          LatLng(35.6762, 139.6503),
        ],
        color: const Color(0x80FF5500),
        strokeWidth: 3.5,
      );

      final json = original.toJson();
      final restored = DrawingPath.fromJson(json);

      expect(restored.points.length, original.points.length);
      for (var i = 0; i < original.points.length; i++) {
        expect(restored.points[i].latitude, original.points[i].latitude);
        expect(restored.points[i].longitude, original.points[i].longitude);
      }
      expect(restored.color, original.color);
      expect(restored.strokeWidth, original.strokeWidth);
    });

    test('fromJson handles empty points list', () {
      final json = {
        'points': <Map<String, dynamic>>[],
        'color': 0xFF000000,
        'strokeWidth': 1.0,
      };

      final path = DrawingPath.fromJson(json);

      expect(path.points, isEmpty);
      expect(path.color, const Color(0xFF000000));
      expect(path.strokeWidth, 1.0);
    });
  });
}
