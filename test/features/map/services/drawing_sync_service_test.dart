import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:memomap/features/map/data/drawing_repository.dart';
import 'package:memomap/features/map/data/drawing_repository_base.dart';
import 'package:memomap/features/map/data/local_drawing_storage.dart';
import 'package:memomap/features/map/data/network_checker.dart';
import 'package:memomap/features/map/models/drawing_path.dart';
import 'package:memomap/features/map/services/drawing_sync_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalDrawingStorage extends Mock implements LocalDrawingStorageBase {}

class MockNetworkChecker extends Mock implements NetworkCheckerBase {}

class MockDrawingRepository extends Mock implements DrawingRepositoryBase {}

void main() {
  late DrawingSyncService service;
  late MockLocalDrawingStorage mockStorage;
  late MockNetworkChecker mockNetworkChecker;
  late MockDrawingRepository mockRepository;

  final testPath = DrawingPath(
    points: [LatLng(35.0, 139.0), LatLng(36.0, 140.0)],
    color: const Color(0xFFFF0000),
    strokeWidth: 3.0,
  );

  DrawingData createTestDrawing({
    String id = 'test-id',
    bool isLocal = false,
    String? userId,
  }) {
    return DrawingData(
      id: id,
      userId: userId ?? (isLocal ? null : 'user-123'),
      mapId: null,
      path: testPath,
      createdAt: DateTime.utc(2024, 1, 15),
      isLocal: isLocal,
    );
  }

  setUp(() {
    mockStorage = MockLocalDrawingStorage();
    mockNetworkChecker = MockNetworkChecker();
    mockRepository = MockDrawingRepository();

    service = DrawingSyncService(
      storage: mockStorage,
      networkChecker: mockNetworkChecker,
      repository: mockRepository,
    );
  });

  setUpAll(() {
    registerFallbackValue(testPath);
    registerFallbackValue(<DrawingData>[]);
  });

  group('getAllDrawings', () {
    test('returns combined cached and local drawings', () async {
      final cachedDrawings = [createTestDrawing(id: 'cached-1')];
      final localDrawings = [createTestDrawing(id: 'local-1', isLocal: true)];

      when(() => mockStorage.getCachedDrawings())
          .thenAnswer((_) async => cachedDrawings);
      when(() => mockStorage.getLocalDrawings())
          .thenAnswer((_) async => localDrawings);

      final result = await service.getAllDrawings();

      expect(result.length, 2);
      expect(result[0].id, 'cached-1');
      expect(result[1].id, 'local-1');
    });

    test('returns empty list when no drawings', () async {
      when(() => mockStorage.getCachedDrawings())
          .thenAnswer((_) async => []);
      when(() => mockStorage.getLocalDrawings())
          .thenAnswer((_) async => []);

      final result = await service.getAllDrawings();

      expect(result, isEmpty);
    });
  });

  group('addDrawing', () {
    test('adds to server when online and authenticated', () async {
      final serverDrawing = createTestDrawing(id: 'server-id');

      when(() => mockNetworkChecker.isOnline)
          .thenAnswer((_) async => true);
      when(() => mockRepository.addDrawing(any()))
          .thenAnswer((_) async => serverDrawing);
      when(() => mockStorage.getCachedDrawings())
          .thenAnswer((_) async => []);
      when(() => mockStorage.setCachedDrawings(any()))
          .thenAnswer((_) async {});

      final result = await service.addDrawing(
        path: testPath,
        isAuthenticated: true,
      );

      expect(result.id, 'server-id');
      expect(result.isLocal, false);
      verify(() => mockRepository.addDrawing(any())).called(1);
      verify(() => mockStorage.setCachedDrawings(any())).called(1);
    });

    test('adds locally when not authenticated', () async {
      when(() => mockStorage.getLocalDrawings())
          .thenAnswer((_) async => []);
      when(() => mockStorage.setLocalDrawings(any()))
          .thenAnswer((_) async {});

      final result = await service.addDrawing(
        path: testPath,
        isAuthenticated: false,
      );

      expect(result.isLocal, true);
      verifyNever(() => mockRepository.addDrawing(any()));
      verify(() => mockStorage.setLocalDrawings(any())).called(1);
    });

    test('adds locally when offline', () async {
      when(() => mockNetworkChecker.isOnline)
          .thenAnswer((_) async => false);
      when(() => mockStorage.getLocalDrawings())
          .thenAnswer((_) async => []);
      when(() => mockStorage.setLocalDrawings(any()))
          .thenAnswer((_) async {});

      final result = await service.addDrawing(
        path: testPath,
        isAuthenticated: true,
      );

      expect(result.isLocal, true);
      verifyNever(() => mockRepository.addDrawing(any()));
    });

    test('falls back to local when server returns null', () async {
      when(() => mockNetworkChecker.isOnline)
          .thenAnswer((_) async => true);
      when(() => mockRepository.addDrawing(any()))
          .thenAnswer((_) async => null);
      when(() => mockStorage.getLocalDrawings())
          .thenAnswer((_) async => []);
      when(() => mockStorage.setLocalDrawings(any()))
          .thenAnswer((_) async {});

      final result = await service.addDrawing(
        path: testPath,
        isAuthenticated: true,
      );

      expect(result.isLocal, true);
    });

    test('falls back to local on server error', () async {
      when(() => mockNetworkChecker.isOnline)
          .thenAnswer((_) async => true);
      when(() => mockRepository.addDrawing(any()))
          .thenThrow(Exception('Server error'));
      when(() => mockStorage.getLocalDrawings())
          .thenAnswer((_) async => []);
      when(() => mockStorage.setLocalDrawings(any()))
          .thenAnswer((_) async {});

      final result = await service.addDrawing(
        path: testPath,
        isAuthenticated: true,
      );

      expect(result.isLocal, true);
    });
  });

  group('deleteDrawing', () {
    test('removes from local storage for local drawing', () async {
      final localDrawing = createTestDrawing(id: 'local-1', isLocal: true);
      final existingLocalDrawings = [localDrawing];

      when(() => mockStorage.getLocalDrawings())
          .thenAnswer((_) async => existingLocalDrawings);
      when(() => mockStorage.setLocalDrawings(any()))
          .thenAnswer((_) async {});

      await service.deleteDrawing(
        drawing: localDrawing,
        isAuthenticated: true,
      );

      verify(() => mockStorage.setLocalDrawings([])).called(1);
      verifyNever(() => mockRepository.deleteDrawing(any()));
    });

    test('deletes from server when online and authenticated', () async {
      final serverDrawing = createTestDrawing(id: 'server-1');

      when(() => mockNetworkChecker.isOnline)
          .thenAnswer((_) async => true);
      when(() => mockRepository.deleteDrawing('server-1'))
          .thenAnswer((_) async {});
      when(() => mockStorage.getCachedDrawings())
          .thenAnswer((_) async => [serverDrawing]);
      when(() => mockStorage.setCachedDrawings(any()))
          .thenAnswer((_) async {});

      await service.deleteDrawing(
        drawing: serverDrawing,
        isAuthenticated: true,
      );

      verify(() => mockRepository.deleteDrawing('server-1')).called(1);
      verify(() => mockStorage.setCachedDrawings([])).called(1);
    });

    test('adds to pending deletions when offline', () async {
      final serverDrawing = createTestDrawing(id: 'server-1');

      when(() => mockNetworkChecker.isOnline)
          .thenAnswer((_) async => false);
      when(() => mockStorage.getPendingDeletions())
          .thenAnswer((_) async => []);
      when(() => mockStorage.setPendingDeletions(any()))
          .thenAnswer((_) async {});
      when(() => mockStorage.getCachedDrawings())
          .thenAnswer((_) async => [serverDrawing]);
      when(() => mockStorage.setCachedDrawings(any()))
          .thenAnswer((_) async {});

      await service.deleteDrawing(
        drawing: serverDrawing,
        isAuthenticated: true,
      );

      verify(() => mockStorage.setPendingDeletions(['server-1'])).called(1);
      verify(() => mockStorage.setCachedDrawings([])).called(1);
      verifyNever(() => mockRepository.deleteDrawing(any()));
    });

    test('adds to pending deletions on server error', () async {
      final serverDrawing = createTestDrawing(id: 'server-1');

      when(() => mockNetworkChecker.isOnline)
          .thenAnswer((_) async => true);
      when(() => mockRepository.deleteDrawing('server-1'))
          .thenThrow(Exception('Server error'));
      when(() => mockStorage.getPendingDeletions())
          .thenAnswer((_) async => []);
      when(() => mockStorage.setPendingDeletions(any()))
          .thenAnswer((_) async {});
      when(() => mockStorage.getCachedDrawings())
          .thenAnswer((_) async => [serverDrawing]);
      when(() => mockStorage.setCachedDrawings(any()))
          .thenAnswer((_) async {});

      await service.deleteDrawing(
        drawing: serverDrawing,
        isAuthenticated: true,
      );

      verify(() => mockStorage.setPendingDeletions(['server-1'])).called(1);
    });
  });

  group('syncWithServer', () {
    test('skips sync when offline', () async {
      when(() => mockNetworkChecker.isOnline)
          .thenAnswer((_) async => false);

      await service.syncWithServer();

      verifyNever(() => mockRepository.getDrawings());
      verifyNever(() => mockRepository.deleteDrawing(any()));
      verifyNever(() => mockRepository.uploadLocalDrawings(any()));
    });

    test('processes pending deletions', () async {
      when(() => mockNetworkChecker.isOnline)
          .thenAnswer((_) async => true);
      when(() => mockStorage.getPendingDeletions())
          .thenAnswer((_) async => ['pending-1', 'pending-2']);
      when(() => mockRepository.deleteDrawing(any()))
          .thenAnswer((_) async {});
      when(() => mockStorage.setPendingDeletions(any()))
          .thenAnswer((_) async {});
      when(() => mockStorage.getLocalDrawings())
          .thenAnswer((_) async => []);
      when(() => mockRepository.getDrawings())
          .thenAnswer((_) async => []);
      when(() => mockStorage.setCachedDrawings(any()))
          .thenAnswer((_) async {});

      await service.syncWithServer();

      verify(() => mockRepository.deleteDrawing('pending-1')).called(1);
      verify(() => mockRepository.deleteDrawing('pending-2')).called(1);
      verify(() => mockStorage.setPendingDeletions([])).called(1);
    });

    test('uploads local drawings', () async {
      final localDrawing = createTestDrawing(id: 'local-1', isLocal: true);
      final uploadedDrawing = createTestDrawing(id: 'server-new');

      when(() => mockNetworkChecker.isOnline)
          .thenAnswer((_) async => true);
      when(() => mockStorage.getPendingDeletions())
          .thenAnswer((_) async => []);
      when(() => mockStorage.getLocalDrawings())
          .thenAnswer((_) async => [localDrawing]);
      when(() => mockRepository.uploadLocalDrawings(any()))
          .thenAnswer((_) async => [uploadedDrawing]);
      when(() => mockStorage.setLocalDrawings(any()))
          .thenAnswer((_) async {});
      when(() => mockRepository.getDrawings())
          .thenAnswer((_) async => [uploadedDrawing]);
      when(() => mockStorage.setCachedDrawings(any()))
          .thenAnswer((_) async {});

      await service.syncWithServer();

      verify(() => mockRepository.uploadLocalDrawings(any())).called(1);
      verify(() => mockStorage.setLocalDrawings([])).called(1);
    });

    test('refreshes cache from server', () async {
      final serverDrawings = [
        createTestDrawing(id: 'server-1'),
        createTestDrawing(id: 'server-2'),
      ];

      when(() => mockNetworkChecker.isOnline)
          .thenAnswer((_) async => true);
      when(() => mockStorage.getPendingDeletions())
          .thenAnswer((_) async => []);
      when(() => mockStorage.getLocalDrawings())
          .thenAnswer((_) async => []);
      when(() => mockRepository.getDrawings())
          .thenAnswer((_) async => serverDrawings);
      when(() => mockStorage.setCachedDrawings(any()))
          .thenAnswer((_) async {});

      await service.syncWithServer();

      verify(() => mockStorage.setCachedDrawings(serverDrawings)).called(1);
    });
  });

  group('replaceDrawings', () {
    test('preserves unchanged paths and deletes removed paths', () async {
      final path1 = DrawingPath(
        points: [LatLng(35.0, 139.0)],
        color: const Color(0xFFFF0000),
        strokeWidth: 3.0,
      );
      final path2 = DrawingPath(
        points: [LatLng(36.0, 140.0)],
        color: const Color(0xFF00FF00),
        strokeWidth: 3.0,
      );
      final drawing1 = DrawingData(
        id: 'drawing-1',
        userId: 'user-123',
        mapId: null,
        path: path1,
        createdAt: DateTime.utc(2024, 1, 15),
      );
      final drawing2 = DrawingData(
        id: 'drawing-2',
        userId: 'user-123',
        mapId: null,
        path: path2,
        createdAt: DateTime.utc(2024, 1, 15),
      );
      final oldDrawings = [drawing1, drawing2];

      // path1 is preserved, path2 is removed
      final newPaths = [path1];

      when(() => mockNetworkChecker.isOnline).thenAnswer((_) async => true);
      when(() => mockRepository.deleteDrawing('drawing-2'))
          .thenAnswer((_) async {});
      when(() => mockStorage.getCachedDrawings())
          .thenAnswer((_) async => [drawing1, drawing2]);
      when(() => mockStorage.setCachedDrawings(any()))
          .thenAnswer((_) async {});

      final result = await service.replaceDrawings(
        oldDrawings: oldDrawings,
        newPaths: newPaths,
        isAuthenticated: true,
      );

      expect(result.length, 1);
      expect(result[0].id, 'drawing-1');
      verify(() => mockRepository.deleteDrawing('drawing-2')).called(1);
      verifyNever(() => mockRepository.deleteDrawing('drawing-1'));
    });

    test('adds new paths from eraser split', () async {
      final path1 = DrawingPath(
        points: [LatLng(35.0, 139.0), LatLng(35.5, 139.5)],
        color: const Color(0xFFFF0000),
        strokeWidth: 3.0,
      );
      final drawing1 = DrawingData(
        id: 'drawing-1',
        userId: 'user-123',
        mapId: null,
        path: path1,
        createdAt: DateTime.utc(2024, 1, 15),
      );
      final oldDrawings = [drawing1];

      // Original path is removed, two new split paths are created
      final splitPath1 = DrawingPath(
        points: [LatLng(35.0, 139.0)],
        color: const Color(0xFFFF0000),
        strokeWidth: 3.0,
      );
      final splitPath2 = DrawingPath(
        points: [LatLng(35.5, 139.5)],
        color: const Color(0xFFFF0000),
        strokeWidth: 3.0,
      );
      final newPaths = [splitPath1, splitPath2];

      final serverDrawingSplit1 = DrawingData(
        id: 'server-split-1',
        userId: 'user-123',
        mapId: null,
        path: splitPath1,
        createdAt: DateTime.utc(2024, 1, 15),
      );
      final serverDrawingSplit2 = DrawingData(
        id: 'server-split-2',
        userId: 'user-123',
        mapId: null,
        path: splitPath2,
        createdAt: DateTime.utc(2024, 1, 15),
      );

      when(() => mockNetworkChecker.isOnline).thenAnswer((_) async => true);
      when(() => mockRepository.deleteDrawing('drawing-1'))
          .thenAnswer((_) async {});
      when(() => mockRepository.addDrawing(splitPath1))
          .thenAnswer((_) async => serverDrawingSplit1);
      when(() => mockRepository.addDrawing(splitPath2))
          .thenAnswer((_) async => serverDrawingSplit2);
      when(() => mockStorage.getCachedDrawings())
          .thenAnswer((_) async => [drawing1]);
      when(() => mockStorage.setCachedDrawings(any()))
          .thenAnswer((_) async {});

      final result = await service.replaceDrawings(
        oldDrawings: oldDrawings,
        newPaths: newPaths,
        isAuthenticated: true,
      );

      expect(result.length, 2);
      expect(result.map((d) => d.id).toList(), ['server-split-1', 'server-split-2']);
      verify(() => mockRepository.deleteDrawing('drawing-1')).called(1);
      verify(() => mockRepository.addDrawing(any())).called(2);
    });

    test('handles local drawings correctly when deleted', () async {
      final path1 = DrawingPath(
        points: [LatLng(35.0, 139.0)],
        color: const Color(0xFFFF0000),
        strokeWidth: 3.0,
      );
      final localDrawing = DrawingData(
        id: 'local-1',
        userId: null,
        mapId: null,
        path: path1,
        createdAt: DateTime.utc(2024, 1, 15),
        isLocal: true,
      );
      final oldDrawings = [localDrawing];
      final newPaths = <DrawingPath>[];

      when(() => mockStorage.getLocalDrawings())
          .thenAnswer((_) async => [localDrawing]);
      when(() => mockStorage.setLocalDrawings(any()))
          .thenAnswer((_) async {});

      final result = await service.replaceDrawings(
        oldDrawings: oldDrawings,
        newPaths: newPaths,
        isAuthenticated: false,
      );

      expect(result, isEmpty);
      verify(() => mockStorage.setLocalDrawings([])).called(1);
      verifyNever(() => mockRepository.deleteDrawing(any()));
    });

    test('persists to local storage when not authenticated', () async {
      final path1 = DrawingPath(
        points: [LatLng(35.0, 139.0)],
        color: const Color(0xFFFF0000),
        strokeWidth: 3.0,
      );
      final drawing1 = DrawingData(
        id: 'drawing-1',
        userId: 'user-123',
        mapId: null,
        path: path1,
        createdAt: DateTime.utc(2024, 1, 15),
      );

      final newPath = DrawingPath(
        points: [LatLng(36.0, 140.0)],
        color: const Color(0xFF00FF00),
        strokeWidth: 3.0,
      );

      // deleteDrawing checks isOnline even when not authenticated for non-local drawings
      when(() => mockNetworkChecker.isOnline).thenAnswer((_) async => false);
      when(() => mockStorage.getLocalDrawings())
          .thenAnswer((_) async => []);
      when(() => mockStorage.setLocalDrawings(any()))
          .thenAnswer((_) async {});
      when(() => mockStorage.getCachedDrawings())
          .thenAnswer((_) async => [drawing1]);
      when(() => mockStorage.setCachedDrawings(any()))
          .thenAnswer((_) async {});
      when(() => mockStorage.getPendingDeletions())
          .thenAnswer((_) async => []);
      when(() => mockStorage.setPendingDeletions(any()))
          .thenAnswer((_) async {});

      final result = await service.replaceDrawings(
        oldDrawings: [drawing1],
        newPaths: [newPath],
        isAuthenticated: false,
      );

      expect(result.length, 1);
      expect(result[0].isLocal, true);
      verifyNever(() => mockRepository.addDrawing(any()));
    });

    test('handles offline scenario with pending deletions', () async {
      final path1 = DrawingPath(
        points: [LatLng(35.0, 139.0)],
        color: const Color(0xFFFF0000),
        strokeWidth: 3.0,
      );
      final drawing1 = DrawingData(
        id: 'drawing-1',
        userId: 'user-123',
        mapId: null,
        path: path1,
        createdAt: DateTime.utc(2024, 1, 15),
      );

      when(() => mockNetworkChecker.isOnline).thenAnswer((_) async => false);
      when(() => mockStorage.getPendingDeletions())
          .thenAnswer((_) async => []);
      when(() => mockStorage.setPendingDeletions(any()))
          .thenAnswer((_) async {});
      when(() => mockStorage.getCachedDrawings())
          .thenAnswer((_) async => [drawing1]);
      when(() => mockStorage.setCachedDrawings(any()))
          .thenAnswer((_) async {});

      final result = await service.replaceDrawings(
        oldDrawings: [drawing1],
        newPaths: [],
        isAuthenticated: true,
      );

      expect(result, isEmpty);
      verify(() => mockStorage.setPendingDeletions(['drawing-1'])).called(1);
      verifyNever(() => mockRepository.deleteDrawing(any()));
    });

    test('preserves paths by object identity', () async {
      final path1 = DrawingPath(
        points: [LatLng(35.0, 139.0)],
        color: const Color(0xFFFF0000),
        strokeWidth: 3.0,
      );
      final path2 = DrawingPath(
        points: [LatLng(36.0, 140.0)],
        color: const Color(0xFF00FF00),
        strokeWidth: 3.0,
      );
      final drawing1 = DrawingData(
        id: 'drawing-1',
        userId: 'user-123',
        mapId: null,
        path: path1,
        createdAt: DateTime.utc(2024, 1, 15),
      );
      final drawing2 = DrawingData(
        id: 'drawing-2',
        userId: 'user-123',
        mapId: null,
        path: path2,
        createdAt: DateTime.utc(2024, 1, 15),
      );

      // Same path object references maintained
      final newPaths = [path1, path2];

      final result = await service.replaceDrawings(
        oldDrawings: [drawing1, drawing2],
        newPaths: newPaths,
        isAuthenticated: true,
      );

      expect(result.length, 2);
      expect(result[0].id, 'drawing-1');
      expect(result[1].id, 'drawing-2');
      verifyNever(() => mockRepository.deleteDrawing(any()));
      verifyNever(() => mockRepository.addDrawing(any()));
    });

    test('preserves drawings by ID even with different path objects', () async {
      // Simulates undo after server sync: same ID but different path objects
      final pathB1 = DrawingPath(
        points: [LatLng(35.0, 139.0)],
        color: const Color(0xFFFF0000),
        strokeWidth: 3.0,
      );
      final pathB2 = DrawingPath(
        points: [LatLng(35.0, 139.0)],
        color: const Color(0xFFFF0000),
        strokeWidth: 3.0,
      );

      final drawingB_old = DrawingData(
        id: 'b',
        userId: 'user-123',
        mapId: null,
        path: pathB1,
        createdAt: DateTime.utc(2024, 1, 15),
      );
      final drawingB_new = DrawingData(
        id: 'b',
        userId: 'user-123',
        mapId: null,
        path: pathB2,
        createdAt: DateTime.utc(2024, 1, 15),
      );

      final result = await service.replaceDrawings(
        oldDrawings: [drawingB_old],
        newDrawings: [drawingB_new],
        isAuthenticated: true,
      );

      // Same ID: should NOT add or delete
      verifyNever(() => mockRepository.addDrawing(any()));
      verifyNever(() => mockRepository.deleteDrawing(any()));
      expect(result.length, 1);
      expect(result[0].id, 'b');
    });

    test('undo after eraser: deletes split drawings and re-adds original', () async {
      // Before eraser: drawingA
      // After eraser: splitA1, splitA2 (drawingA deleted)
      // Undo: restore drawingA (needs re-add), delete splitA1, splitA2
      final pathA = DrawingPath(
        points: [LatLng(35.0, 139.0), LatLng(35.5, 139.5)],
        color: const Color(0xFFFF0000),
        strokeWidth: 3.0,
      );
      final pathA1 = DrawingPath(
        points: [LatLng(35.0, 139.0)],
        color: const Color(0xFFFF0000),
        strokeWidth: 3.0,
      );
      final pathA2 = DrawingPath(
        points: [LatLng(35.5, 139.5)],
        color: const Color(0xFFFF0000),
        strokeWidth: 3.0,
      );

      final drawingA = DrawingData(
        id: 'a',
        userId: 'user-123',
        mapId: null,
        path: pathA,
        createdAt: DateTime.utc(2024, 1, 15),
      );
      final splitA1 = DrawingData(
        id: 'split-1',
        userId: 'user-123',
        mapId: null,
        path: pathA1,
        createdAt: DateTime.utc(2024, 1, 15),
      );
      final splitA2 = DrawingData(
        id: 'split-2',
        userId: 'user-123',
        mapId: null,
        path: pathA2,
        createdAt: DateTime.utc(2024, 1, 15),
      );

      final serverDrawingA = DrawingData(
        id: 'server-a-new',
        userId: 'user-123',
        mapId: null,
        path: pathA,
        createdAt: DateTime.utc(2024, 1, 15),
      );

      when(() => mockNetworkChecker.isOnline).thenAnswer((_) async => true);
      when(() => mockRepository.deleteDrawing('split-1'))
          .thenAnswer((_) async {});
      when(() => mockRepository.deleteDrawing('split-2'))
          .thenAnswer((_) async {});
      when(() => mockRepository.addDrawing(pathA))
          .thenAnswer((_) async => serverDrawingA);
      when(() => mockStorage.getCachedDrawings())
          .thenAnswer((_) async => [splitA1, splitA2]);
      when(() => mockStorage.setCachedDrawings(any()))
          .thenAnswer((_) async {});

      final result = await service.replaceDrawings(
        oldDrawings: [splitA1, splitA2],
        newDrawings: [drawingA],
        isAuthenticated: true,
      );

      // Split drawings should be deleted
      verify(() => mockRepository.deleteDrawing('split-1')).called(1);
      verify(() => mockRepository.deleteDrawing('split-2')).called(1);
      // Original should be re-added (it was deleted during eraser)
      verify(() => mockRepository.addDrawing(pathA)).called(1);
      expect(result.length, 1);
      expect(result[0].id, 'server-a-new');
    });

    test('eraser with newDrawings: preserves unchanged, adds splits, deletes original', () async {
      final pathA = DrawingPath(
        points: [LatLng(35.0, 139.0), LatLng(35.5, 139.5)],
        color: const Color(0xFFFF0000),
        strokeWidth: 3.0,
      );
      final pathB = DrawingPath(
        points: [LatLng(36.0, 140.0)],
        color: const Color(0xFF00FF00),
        strokeWidth: 3.0,
      );
      final pathA1 = DrawingPath(
        points: [LatLng(35.0, 139.0)],
        color: const Color(0xFFFF0000),
        strokeWidth: 3.0,
      );

      final drawingA = DrawingData(
        id: 'a',
        userId: 'user-123',
        mapId: null,
        path: pathA,
        createdAt: DateTime.utc(2024, 1, 15),
      );
      final drawingB = DrawingData(
        id: 'b',
        userId: 'user-123',
        mapId: null,
        path: pathB,
        createdAt: DateTime.utc(2024, 1, 15),
      );
      // Split drawing has local ID (new)
      final splitA1 = DrawingData(
        id: 'local-split-1',
        userId: null,
        mapId: null,
        path: pathA1,
        createdAt: DateTime.utc(2024, 1, 15),
        isLocal: true,
      );

      final serverSplitA1 = DrawingData(
        id: 'server-split-1',
        userId: 'user-123',
        mapId: null,
        path: pathA1,
        createdAt: DateTime.utc(2024, 1, 15),
      );

      when(() => mockNetworkChecker.isOnline).thenAnswer((_) async => true);
      when(() => mockRepository.deleteDrawing('a')).thenAnswer((_) async {});
      when(() => mockRepository.addDrawing(pathA1))
          .thenAnswer((_) async => serverSplitA1);
      when(() => mockStorage.getCachedDrawings())
          .thenAnswer((_) async => [drawingA, drawingB]);
      when(() => mockStorage.setCachedDrawings(any()))
          .thenAnswer((_) async {});

      final result = await service.replaceDrawings(
        oldDrawings: [drawingA, drawingB],
        newDrawings: [splitA1, drawingB], // B unchanged (same object)
        isAuthenticated: true,
      );

      // A should be deleted (not in new)
      verify(() => mockRepository.deleteDrawing('a')).called(1);
      // B should be preserved (same ID)
      verifyNever(() => mockRepository.deleteDrawing('b'));
      verifyNever(() => mockRepository.addDrawing(pathB));
      // Split should be added (local/new)
      verify(() => mockRepository.addDrawing(pathA1)).called(1);

      expect(result.length, 2);
    });
  });

  group('remapLocalMapIds', () {
    test('should update mapIds of local drawings matching the mapping',
        () async {
      final localDrawings = [
        DrawingData(
          id: 'drawing-1',
          userId: null,
          mapId: 'local-map-1',
          path: testPath,
          createdAt: DateTime.utc(2024, 1, 15),
          isLocal: true,
        ),
        DrawingData(
          id: 'drawing-2',
          userId: null,
          mapId: 'local-map-2',
          path: testPath,
          createdAt: DateTime.utc(2024, 1, 16),
          isLocal: true,
        ),
      ];

      when(() => mockStorage.getLocalDrawings())
          .thenAnswer((_) async => localDrawings);
      when(() => mockStorage.setLocalDrawings(any()))
          .thenAnswer((_) async {});

      await service.remapLocalMapIds({
        'local-map-1': 'server-map-1',
      });

      final captured =
          verify(() => mockStorage.setLocalDrawings(captureAny())).captured;
      final updatedDrawings = captured.last as List<DrawingData>;

      expect(updatedDrawings[0].mapId, 'server-map-1');
      expect(updatedDrawings[1].mapId, 'local-map-2');
    });

    test('should do nothing when mapping is empty', () async {
      await service.remapLocalMapIds({});

      verifyNever(() => mockStorage.getLocalDrawings());
      verifyNever(() => mockStorage.setLocalDrawings(any()));
    });
  });

  group('clearIfUserChanged', () {
    test('clears all when user changes', () async {
      when(() => mockStorage.getLastUserId())
          .thenAnswer((_) async => 'old-user');
      when(() => mockStorage.clearAll())
          .thenAnswer((_) async {});
      when(() => mockStorage.setLastUserId('new-user'))
          .thenAnswer((_) async {});

      await service.clearIfUserChanged('new-user');

      verify(() => mockStorage.clearAll()).called(1);
      verify(() => mockStorage.setLastUserId('new-user')).called(1);
    });

    test('does not clear when user is same', () async {
      when(() => mockStorage.getLastUserId())
          .thenAnswer((_) async => 'same-user');
      when(() => mockStorage.setLastUserId('same-user'))
          .thenAnswer((_) async {});

      await service.clearIfUserChanged('same-user');

      verifyNever(() => mockStorage.clearAll());
      verify(() => mockStorage.setLastUserId('same-user')).called(1);
    });

    test('does not clear when no previous user', () async {
      when(() => mockStorage.getLastUserId())
          .thenAnswer((_) async => null);
      when(() => mockStorage.setLastUserId('new-user'))
          .thenAnswer((_) async {});

      await service.clearIfUserChanged('new-user');

      verifyNever(() => mockStorage.clearAll());
      verify(() => mockStorage.setLastUserId('new-user')).called(1);
    });
  });
}
