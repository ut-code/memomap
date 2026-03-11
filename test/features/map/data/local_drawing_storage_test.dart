import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:memomap/features/map/data/drawing_repository.dart';
import 'package:memomap/features/map/data/local_drawing_storage.dart';
import 'package:memomap/features/map/models/drawing_path.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalDrawingStorage extends Mock implements LocalDrawingStorageBase {}

void main() {
  group('LocalDrawingStorageBase mock usage', () {
    late MockLocalDrawingStorage mockStorage;

    setUp(() {
      mockStorage = MockLocalDrawingStorage();
    });

    DrawingData createTestDrawing({
      String id = 'test-id',
      bool isLocal = false,
    }) {
      return DrawingData(
        id: id,
        userId: isLocal ? null : 'user-123',
        mapId: null,
        path: DrawingPath(
          points: [LatLng(35.0, 139.0), LatLng(36.0, 140.0)],
          color: const Color(0xFFFF0000),
          strokeWidth: 3.0,
        ),
        createdAt: DateTime.utc(2024, 1, 15),
        isLocal: isLocal,
      );
    }

    group('cachedDrawings', () {
      test('should return empty list when no cached drawings', () async {
        when(() => mockStorage.getCachedDrawings())
            .thenAnswer((_) async => []);

        final drawings = await mockStorage.getCachedDrawings();
        expect(drawings, isEmpty);
      });

      test('should store and retrieve cached drawings', () async {
        final drawings = [
          createTestDrawing(id: 'drawing-1'),
          createTestDrawing(id: 'drawing-2'),
        ];

        when(() => mockStorage.setCachedDrawings(drawings))
            .thenAnswer((_) async {});
        when(() => mockStorage.getCachedDrawings())
            .thenAnswer((_) async => drawings);

        await mockStorage.setCachedDrawings(drawings);
        final retrieved = await mockStorage.getCachedDrawings();

        expect(retrieved.length, 2);
        expect(retrieved[0].id, 'drawing-1');
        expect(retrieved[1].id, 'drawing-2');
        verify(() => mockStorage.setCachedDrawings(drawings)).called(1);
      });
    });

    group('localDrawings', () {
      test('should return empty list when no local drawings', () async {
        when(() => mockStorage.getLocalDrawings())
            .thenAnswer((_) async => []);

        final drawings = await mockStorage.getLocalDrawings();
        expect(drawings, isEmpty);
      });

      test('should store and retrieve local drawings', () async {
        final drawings = [
          createTestDrawing(id: 'local-1', isLocal: true),
          createTestDrawing(id: 'local-2', isLocal: true),
        ];

        when(() => mockStorage.setLocalDrawings(drawings))
            .thenAnswer((_) async {});
        when(() => mockStorage.getLocalDrawings())
            .thenAnswer((_) async => drawings);

        await mockStorage.setLocalDrawings(drawings);
        final retrieved = await mockStorage.getLocalDrawings();

        expect(retrieved.length, 2);
        expect(retrieved[0].id, 'local-1');
        expect(retrieved[0].isLocal, true);
      });
    });

    group('pendingDeletions', () {
      test('should return empty list when no pending deletions', () async {
        when(() => mockStorage.getPendingDeletions())
            .thenAnswer((_) async => []);

        final ids = await mockStorage.getPendingDeletions();
        expect(ids, isEmpty);
      });

      test('should store and retrieve pending deletions', () async {
        final ids = ['id-1', 'id-2', 'id-3'];

        when(() => mockStorage.setPendingDeletions(ids))
            .thenAnswer((_) async {});
        when(() => mockStorage.getPendingDeletions())
            .thenAnswer((_) async => ids);

        await mockStorage.setPendingDeletions(ids);
        final retrieved = await mockStorage.getPendingDeletions();

        expect(retrieved, ['id-1', 'id-2', 'id-3']);
      });
    });

    group('lastUserId', () {
      test('should return null when no last user id', () async {
        when(() => mockStorage.getLastUserId())
            .thenAnswer((_) async => null);

        final result = await mockStorage.getLastUserId();
        expect(result, isNull);
      });

      test('should store and retrieve last user id', () async {
        when(() => mockStorage.setLastUserId('user-123'))
            .thenAnswer((_) async {});
        when(() => mockStorage.getLastUserId())
            .thenAnswer((_) async => 'user-123');

        await mockStorage.setLastUserId('user-123');
        final result = await mockStorage.getLastUserId();
        expect(result, 'user-123');
      });
    });

    group('clearAll', () {
      test('should clear all stored data', () async {
        when(() => mockStorage.clearAll())
            .thenAnswer((_) async {});

        await mockStorage.clearAll();

        verify(() => mockStorage.clearAll()).called(1);
      });
    });
  });
}
