import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:memomap/features/map/data/drawing_repository.dart';
import 'package:memomap/features/map/models/drawing_path.dart';

void main() {
  group('DrawingData', () {
    final testPath = DrawingPath(
      points: [
        LatLng(35.681236, 139.767125),
        LatLng(35.689521, 139.691704),
      ],
      color: const Color(0xFFFF0000),
      strokeWidth: 5.0,
    );

    test('local() generates UUID and sets isLocal=true', () {
      final drawing = DrawingData.local(testPath);

      expect(drawing.id, isNotEmpty);
      expect(drawing.id.length, 36); // UUID format
      expect(drawing.userId, isNull);
      expect(drawing.mapId, isNull);
      expect(drawing.path.points.length, 2);
      expect(drawing.isLocal, isTrue);
      expect(drawing.createdAt, isNotNull);
    });

    test('local() generates unique IDs for each call', () {
      final drawing1 = DrawingData.local(testPath);
      final drawing2 = DrawingData.local(testPath);

      expect(drawing1.id, isNot(equals(drawing2.id)));
    });

    test('toJson converts all fields correctly', () {
      final now = DateTime.utc(2024, 1, 15, 10, 30, 0);
      final drawing = DrawingData(
        id: 'test-uuid-123',
        userId: 'user-456',
        mapId: 'map-789',
        path: testPath,
        createdAt: now,
        isLocal: false,
      );

      final json = drawing.toJson();

      expect(json['id'], 'test-uuid-123');
      expect(json['userId'], 'user-456');
      expect(json['mapId'], 'map-789');
      expect(json['path'], isA<Map<String, dynamic>>());
      expect(json['createdAt'], '2024-01-15T10:30:00.000Z');
      expect(json['isLocal'], false);
    });

    test('fromJson restores DrawingData from JSON', () {
      final json = {
        'id': 'test-uuid-123',
        'userId': 'user-456',
        'mapId': 'map-789',
        'path': {
          'points': [
            {'lat': 35.681236, 'lng': 139.767125},
            {'lat': 35.689521, 'lng': 139.691704},
          ],
          'color': 0xFFFF0000,
          'strokeWidth': 5.0,
        },
        'createdAt': '2024-01-15T10:30:00.000Z',
        'isLocal': false,
      };

      final drawing = DrawingData.fromJson(json);

      expect(drawing.id, 'test-uuid-123');
      expect(drawing.userId, 'user-456');
      expect(drawing.mapId, 'map-789');
      expect(drawing.path.points.length, 2);
      expect(drawing.path.color, const Color(0xFFFF0000));
      expect(drawing.createdAt, DateTime.utc(2024, 1, 15, 10, 30, 0));
      expect(drawing.isLocal, false);
    });

    test('fromJson handles null userId and mapId', () {
      final json = {
        'id': 'test-uuid-123',
        'userId': null,
        'mapId': null,
        'path': {
          'points': <Map<String, dynamic>>[],
          'color': 0xFF000000,
          'strokeWidth': 1.0,
        },
        'createdAt': '2024-01-15T10:30:00.000Z',
        'isLocal': true,
      };

      final drawing = DrawingData.fromJson(json);

      expect(drawing.userId, isNull);
      expect(drawing.mapId, isNull);
      expect(drawing.isLocal, isTrue);
    });

    test('roundtrip: toJson -> fromJson preserves all data', () {
      final now = DateTime.utc(2024, 1, 15, 10, 30, 0);
      final original = DrawingData(
        id: 'test-uuid-123',
        userId: 'user-456',
        mapId: 'map-789',
        path: testPath,
        createdAt: now,
        isLocal: false,
      );

      final json = original.toJson();
      final restored = DrawingData.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.userId, original.userId);
      expect(restored.mapId, original.mapId);
      expect(restored.path.points.length, original.path.points.length);
      expect(restored.path.color, original.path.color);
      expect(restored.path.strokeWidth, original.path.strokeWidth);
      expect(restored.createdAt, original.createdAt);
      expect(restored.isLocal, original.isLocal);
    });
  });
}
