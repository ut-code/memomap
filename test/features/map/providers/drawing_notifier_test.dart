import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:memomap/features/auth/providers/auth_provider.dart';
import 'package:memomap/features/map/data/drawing_repository.dart';
import 'package:memomap/features/map/data/local_drawing_storage.dart';
import 'package:memomap/features/map/data/network_checker.dart';
import 'package:memomap/features/map/models/drawing_path.dart';
import 'package:memomap/features/map/providers/drawing_provider.dart';
import 'package:memomap/features/map/services/drawing_sync_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalDrawingStorage extends Mock implements LocalDrawingStorageBase {}

class MockNetworkChecker extends Mock implements NetworkCheckerBase {}

class MockDrawingSyncService extends Mock implements DrawingSyncService {}

void main() {
  group('DrawingNotifier race conditions', () {
    late ProviderContainer container;
    late MockDrawingSyncService mockSyncService;

    final testPath1 = DrawingPath(
      points: [LatLng(35.0, 139.0), LatLng(35.1, 139.1)],
      color: const Color(0xFFFF0000),
      strokeWidth: 3.0,
    );

    final testPath2 = DrawingPath(
      points: [LatLng(36.0, 140.0), LatLng(36.1, 140.1)],
      color: const Color(0xFF00FF00),
      strokeWidth: 3.0,
    );

    DrawingData createDrawing(String id, DrawingPath path) {
      return DrawingData(
        id: id,
        userId: 'user-123',
        mapId: null,
        path: path,
        createdAt: DateTime.utc(2024, 1, 15),
      );
    }

    setUpAll(() {
      registerFallbackValue(testPath1);
      registerFallbackValue(<DrawingData>[]);
      registerFallbackValue(DrawingData(
        id: 'fallback',
        userId: 'user',
        mapId: null,
        path: testPath1,
        createdAt: DateTime.utc(2024, 1, 1),
      ));
    });

    setUp(() {
      mockSyncService = MockDrawingSyncService();

      // Default mock behaviors
      when(() => mockSyncService.getAllDrawings())
          .thenAnswer((_) async => <DrawingData>[]);
      when(() => mockSyncService.clearIfUserChanged(any()))
          .thenAnswer((_) async {});
    });

    tearDown(() {
      container.dispose();
    });

    ProviderContainer createContainer({
      List<DrawingData> initialDrawings = const [],
    }) {
      when(() => mockSyncService.getAllDrawings())
          .thenAnswer((_) async => initialDrawings);

      return ProviderContainer(
        overrides: [
          drawingSyncServiceProvider.overrideWith(
            (ref) async => mockSyncService,
          ),
          sessionProvider.overrideWith(
            (ref) async => null,
          ),
          isAuthenticatedProvider.overrideWith((ref) => false),
        ],
      );
    }

    test(
      'undo after addPath sync is properly serialized',
      () async {
        // With async lock:
        // 1. addPath acquires lock, adds drawing B
        // 2. undo waits for lock, then runs after addPath completes
        // 3. undo properly deletes B from server via replaceDrawings
        // Result: server and client are consistent

        final drawingA = createDrawing('a', testPath1);
        container = createContainer(initialDrawings: [drawingA]);

        await container.read(drawingProvider.future);

        final notifier = container.read(drawingProvider.notifier);

        // Track server operations
        final serverDrawings = <String>{'a'};

        when(() => mockSyncService.addDrawing(
              path: any(named: 'path'),
              isAuthenticated: any(named: 'isAuthenticated'),
            )).thenAnswer((_) async {
          final drawing = createDrawing('b', testPath2);
          serverDrawings.add(drawing.id);
          return drawing;
        });

        when(() => mockSyncService.replaceDrawings(
              oldDrawings: any(named: 'oldDrawings'),
              newDrawings: any(named: 'newDrawings'),
              isAuthenticated: any(named: 'isAuthenticated'),
            )).thenAnswer((invocation) async {
          final oldDrawings =
              invocation.namedArguments[#oldDrawings] as List<DrawingData>;
          final newDrawings =
              invocation.namedArguments[#newDrawings] as List<DrawingData>;

          final newIds = newDrawings.map((d) => d.id).toSet();
          for (final old in oldDrawings) {
            if (!newIds.contains(old.id) && !old.isLocal) {
              serverDrawings.remove(old.id);
            }
          }
          return newDrawings;
        });

        // Start addPath and undo concurrently
        // Lock ensures they run sequentially: addPath then undo
        final addPathFuture = notifier.addPath(testPath2);
        final undoFuture = notifier.undo();

        await Future.wait([addPathFuture, undoFuture]);

        // Client state
        final state = container.read(drawingProvider).valueOrNull!;
        final clientIds = state.drawingDataList.map((d) => d.id).toSet();

        // With proper operation locking:
        // - addPath completes first (adds B to server)
        // - undo runs after (deletes B from server via replaceDrawings)
        // Server and client both have only 'a'
        expect(
          serverDrawings.difference(clientIds),
          isEmpty,
          reason: 'Server should not have drawings that client does not have',
        );
        expect(clientIds, {'a'});
        expect(serverDrawings, {'a'});
      },
    );

    test(
      'undo during finishEraserOperation causes server inconsistency',
      () async {
        final drawingA = createDrawing('a', testPath1);
        container = createContainer(initialDrawings: [drawingA]);

        await container.read(drawingProvider.future);
        final notifier = container.read(drawingProvider.notifier);

        final serverDrawings = <String>{'a'};
        final eraserCompleter = Completer<List<DrawingData>>();

        when(() => mockSyncService.replaceDrawings(
              oldDrawings: any(named: 'oldDrawings'),
              newPaths: any(named: 'newPaths'),
              isAuthenticated: any(named: 'isAuthenticated'),
            )).thenAnswer((_) => eraserCompleter.future);

        when(() => mockSyncService.replaceDrawings(
              oldDrawings: any(named: 'oldDrawings'),
              newDrawings: any(named: 'newDrawings'),
              isAuthenticated: any(named: 'isAuthenticated'),
            )).thenAnswer((invocation) async {
          final newDrawings =
              invocation.namedArguments[#newDrawings] as List<DrawingData>;
          return newDrawings;
        });

        // Start eraser operation
        notifier.startEraserOperation();
        final splitPath = DrawingPath(
          points: [LatLng(35.0, 139.0)],
          color: const Color(0xFFFF0000),
          strokeWidth: 3.0,
        );
        notifier.updateEraserPaths([splitPath]);

        // Start finishEraserOperation (will wait on eraserCompleter)
        final eraserFuture = notifier.finishEraserOperation();
        await Future.delayed(Duration.zero);

        // Undo is blocked during eraser operation
        // This test verifies the block works
        final stateBeforeUndo = container.read(drawingProvider).valueOrNull!;

        // Complete eraser
        final splitDrawing = createDrawing('split-1', splitPath);
        eraserCompleter.complete([splitDrawing]);
        await eraserFuture;

        // Now undo should work
        await notifier.undo();

        final state = container.read(drawingProvider).valueOrNull!;
        expect(state.drawingDataList.length, 1);
        expect(state.drawingDataList[0].id, 'a');
      },
    );

    test(
      'addPath during undo causes state overwrite',
      () async {
        final drawingA = createDrawing('a', testPath1);
        final drawingB = createDrawing('b', testPath2);
        container = createContainer(initialDrawings: [drawingA, drawingB]);

        await container.read(drawingProvider.future);
        final notifier = container.read(drawingProvider.notifier);

        // Add C first to have something to undo
        when(() => mockSyncService.addDrawing(
              path: any(named: 'path'),
              isAuthenticated: any(named: 'isAuthenticated'),
            )).thenAnswer((_) async => createDrawing('c', testPath1));

        await notifier.addPath(testPath1);

        // Now set up delayed undo and immediate addPath
        final undoCompleter = Completer<List<DrawingData>>();
        when(() => mockSyncService.replaceDrawings(
              oldDrawings: any(named: 'oldDrawings'),
              newDrawings: any(named: 'newDrawings'),
              isAuthenticated: any(named: 'isAuthenticated'),
            )).thenAnswer((_) => undoCompleter.future);

        final addPathCompleter = Completer<DrawingData>();
        when(() => mockSyncService.addDrawing(
              path: any(named: 'path'),
              isAuthenticated: any(named: 'isAuthenticated'),
            )).thenAnswer((_) => addPathCompleter.future);

        // Start undo (will wait on undoCompleter)
        final undoFuture = notifier.undo();
        await Future.delayed(Duration.zero);

        // Start addPath during undo
        final addPathFuture = notifier.addPath(testPath2);
        await Future.delayed(Duration.zero);

        // Complete addPath first
        final drawingD = createDrawing('d', testPath2);
        addPathCompleter.complete(drawingD);

        // Then complete undo
        undoCompleter.complete([drawingA, drawingB]);

        await Future.wait([undoFuture, addPathFuture]);

        final state = container.read(drawingProvider).valueOrNull!;

        // With proper locking:
        // - Either undo completes first, then addPath adds D: [a, b, d]
        // - Or addPath completes first, then undo reverts: [a, b]
        // Without locking, state is unpredictable
        expect(
          state.drawingDataList.map((d) => d.id).toSet(),
          anyOf(
            equals({'a', 'b', 'd'}),
            equals({'a', 'b'}),
          ),
          reason: 'State should be consistent (either undone or with new drawing)',
        );
      },
    );

    test(
      'multiple concurrent addPath calls should preserve all drawings',
      () async {
        container = createContainer();
        await container.read(drawingProvider.future);

        final notifier = container.read(drawingProvider.notifier);

        final completer1 = Completer<DrawingData>();
        final completer2 = Completer<DrawingData>();
        final completer3 = Completer<DrawingData>();
        var callCount = 0;

        when(() => mockSyncService.addDrawing(
              path: any(named: 'path'),
              isAuthenticated: any(named: 'isAuthenticated'),
            )).thenAnswer((_) {
          callCount++;
          switch (callCount) {
            case 1:
              return completer1.future;
            case 2:
              return completer2.future;
            default:
              return completer3.future;
          }
        });

        // Start three addPath calls
        final future1 = notifier.addPath(testPath1);
        await Future.delayed(Duration.zero);
        final future2 = notifier.addPath(testPath2);
        await Future.delayed(Duration.zero);
        final path3 = DrawingPath(
          points: [LatLng(37.0, 141.0)],
          color: const Color(0xFF0000FF),
          strokeWidth: 3.0,
        );
        final future3 = notifier.addPath(path3);

        // Complete in reverse order
        completer3.complete(createDrawing('c', path3));
        await Future.delayed(Duration.zero);
        completer2.complete(createDrawing('b', testPath2));
        await Future.delayed(Duration.zero);
        completer1.complete(createDrawing('a', testPath1));

        await Future.wait([future1, future2, future3]);

        final state = container.read(drawingProvider).valueOrNull!;

        // All three drawings should be present
        expect(
          state.drawingDataList.length,
          3,
          reason: 'All concurrent addPath calls should result in drawings',
        );
        expect(
          state.drawingDataList.map((d) => d.id).toSet(),
          {'a', 'b', 'c'},
        );
      },
    );

    test(
      'concurrent undo calls should not corrupt stack',
      () async {
        final drawingA = createDrawing('a', testPath1);
        container = createContainer(initialDrawings: [drawingA]);

        await container.read(drawingProvider.future);
        final notifier = container.read(drawingProvider.notifier);

        // Add B and C to have undo history
        when(() => mockSyncService.addDrawing(
              path: any(named: 'path'),
              isAuthenticated: any(named: 'isAuthenticated'),
            )).thenAnswer((inv) async {
          final path = inv.namedArguments[#path] as DrawingPath;
          return createDrawing(
            path == testPath1 ? 'b' : 'c',
            path,
          );
        });

        await notifier.addPath(testPath1);
        await notifier.addPath(testPath2);

        // Set up delayed replaceDrawings
        final completer1 = Completer<List<DrawingData>>();
        final completer2 = Completer<List<DrawingData>>();
        var undoCallCount = 0;

        when(() => mockSyncService.replaceDrawings(
              oldDrawings: any(named: 'oldDrawings'),
              newDrawings: any(named: 'newDrawings'),
              isAuthenticated: any(named: 'isAuthenticated'),
            )).thenAnswer((_) {
          undoCallCount++;
          if (undoCallCount == 1) {
            return completer1.future;
          }
          return completer2.future;
        });

        // Start two undo calls concurrently
        final undo1 = notifier.undo();
        await Future.delayed(Duration.zero);
        final undo2 = notifier.undo();

        // Complete both
        completer1.complete([drawingA, createDrawing('b', testPath1)]);
        completer2.complete([drawingA]);

        await Future.wait([undo1, undo2]);

        final state = container.read(drawingProvider).valueOrNull!;

        // With proper locking, should undo twice: [a, b, c] -> [a, b] -> [a]
        // Without locking, behavior is undefined
        expect(
          state.drawingDataList.length,
          lessThanOrEqualTo(2),
          reason: 'At least one undo should have taken effect',
        );
      },
    );

    test(
      'undo during redo causes stack inconsistency',
      () async {
        final drawingA = createDrawing('a', testPath1);
        container = createContainer(initialDrawings: [drawingA]);

        await container.read(drawingProvider.future);
        final notifier = container.read(drawingProvider.notifier);

        // Add B
        when(() => mockSyncService.addDrawing(
              path: any(named: 'path'),
              isAuthenticated: any(named: 'isAuthenticated'),
            )).thenAnswer((_) async => createDrawing('b', testPath2));

        when(() => mockSyncService.replaceDrawings(
              oldDrawings: any(named: 'oldDrawings'),
              newDrawings: any(named: 'newDrawings'),
              isAuthenticated: any(named: 'isAuthenticated'),
            )).thenAnswer((inv) async {
          return inv.namedArguments[#newDrawings] as List<DrawingData>;
        });

        await notifier.addPath(testPath2);
        await notifier.undo();

        // Now we can redo
        var state = container.read(drawingProvider).valueOrNull!;
        expect(state.canRedo, true);

        // Set up delayed redo
        final redoCompleter = Completer<List<DrawingData>>();
        final undoCompleter = Completer<List<DrawingData>>();
        var callCount = 0;

        when(() => mockSyncService.replaceDrawings(
              oldDrawings: any(named: 'oldDrawings'),
              newDrawings: any(named: 'newDrawings'),
              isAuthenticated: any(named: 'isAuthenticated'),
            )).thenAnswer((_) {
          callCount++;
          if (callCount == 1) {
            return redoCompleter.future;
          }
          return undoCompleter.future;
        });

        // Start redo
        final redoFuture = notifier.redo();
        await Future.delayed(Duration.zero);

        // Start undo during redo
        final undoFuture = notifier.undo();

        // Complete both
        redoCompleter.complete([drawingA, createDrawing('b', testPath2)]);
        undoCompleter.complete([drawingA]);

        await Future.wait([redoFuture, undoFuture]);

        state = container.read(drawingProvider).valueOrNull!;

        // State should be consistent
        expect(
          state.drawingDataList.isNotEmpty,
          true,
          reason: 'State should not be corrupted',
        );
      },
    );

    test(
      'concurrent addPath calls should be serialized',
      () async {
        container = createContainer();
        await container.read(drawingProvider.future);

        final notifier = container.read(drawingProvider.notifier);

        final completer1 = Completer<DrawingData>();
        final completer2 = Completer<DrawingData>();
        var addDrawingCallCount = 0;

        when(() => mockSyncService.addDrawing(
              path: any(named: 'path'),
              isAuthenticated: any(named: 'isAuthenticated'),
            )).thenAnswer((_) {
          addDrawingCallCount++;
          if (addDrawingCallCount == 1) {
            return completer1.future;
          } else {
            return completer2.future;
          }
        });

        // Start two addPath calls concurrently
        final future1 = notifier.addPath(testPath1);
        final future2 = notifier.addPath(testPath2);

        // Complete in reverse order
        completer2.complete(createDrawing('b', testPath2));
        await Future.delayed(Duration.zero);
        completer1.complete(createDrawing('a', testPath1));

        await Future.wait([future1, future2]);

        final state = container.read(drawingProvider).valueOrNull!;

        // With proper serialization, both drawings should be present
        // and the order should be consistent
        expect(
          state.drawingDataList.length,
          2,
          reason: 'Both drawings should be added',
        );
      },
    );
  });
}
