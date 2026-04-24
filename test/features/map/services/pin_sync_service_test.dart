import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:memomap/features/map/data/pin_repository.dart';
import 'package:memomap/features/map/services/pin_sync_service.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

void main() {
  late MockLocalPinStorage mockStorage;
  late MockNetworkChecker mockNetworkChecker;
  late MockPinRepository mockRepository;
  late PinSyncService syncService;

  setUpAll(() {
    registerFallbackValue(const LatLng(0, 0));
    registerFallbackValue(<PinData>[]);
    registerFallbackValue(<String>[]);
    registerFallbackValue(<String, List<String>>{});
  });

  setUp(() {
    mockStorage = MockLocalPinStorage();
    mockNetworkChecker = MockNetworkChecker();
    mockRepository = MockPinRepository();

    // Default stubs for tag-update related methods added in tag feature.
    // Individual tests can override as needed.
    when(() => mockStorage.getPendingTagUpdates())
        .thenAnswer((_) async => <String, List<String>>{});
    when(() => mockStorage.setPendingTagUpdates(any()))
        .thenAnswer((_) async {});

    syncService = PinSyncService(
      storage: mockStorage,
      networkChecker: mockNetworkChecker,
      repository: mockRepository,
    );
  });

  group('PinSyncService', () {
    group('getAllPins', () {
      test('should return cached + local pins immediately', () async {
        final cachedPins = [
          PinData(
            id: 'cached-1',
            userId: 'user-1',
            position: const LatLng(35.6762, 139.6503),
            createdAt: DateTime.utc(2024, 1, 15),
            isLocal: false,
          ),
        ];
        final localPins = [
          PinData(
            id: 'local-1',
            userId: null,
            position: const LatLng(35.6895, 139.6917),
            createdAt: DateTime.utc(2024, 1, 16),
            isLocal: true,
          ),
        ];

        when(() => mockStorage.getCachedPins())
            .thenAnswer((_) async => cachedPins);
        when(() => mockStorage.getLocalPins())
            .thenAnswer((_) async => localPins);

        final pins = await syncService.getAllPins();

        expect(pins.length, 2);
        expect(pins.any((p) => p.id == 'cached-1'), true);
        expect(pins.any((p) => p.id == 'local-1'), true);
      });

      test('should return empty list when no pins exist', () async {
        when(() => mockStorage.getCachedPins())
            .thenAnswer((_) async => []);
        when(() => mockStorage.getLocalPins())
            .thenAnswer((_) async => []);

        final pins = await syncService.getAllPins();

        expect(pins, isEmpty);
      });
    });

    group('addPin', () {
      test('should add to server when online and authenticated', () async {
        final position = const LatLng(35.6762, 139.6503);
        final serverPin = PinData(
          id: 'server-id',
          userId: 'user-1',
          position: position,
          createdAt: DateTime.utc(2024, 1, 15),
          isLocal: false,
        );

        when(() => mockNetworkChecker.isOnline)
            .thenAnswer((_) async => true);
        when(() => mockRepository.addPin(position))
            .thenAnswer((_) async => serverPin);
        when(() => mockStorage.getCachedPins())
            .thenAnswer((_) async => []);
        when(() => mockStorage.setCachedPins(any()))
            .thenAnswer((_) async {});

        final result = await syncService.addPin(
          position: position,
          isAuthenticated: true,
        );

        expect(result.id, 'server-id');
        expect(result.isLocal, false);
        verify(() => mockRepository.addPin(position)).called(1);
      });

      test('should add to local storage when offline', () async {
        final position = const LatLng(35.6762, 139.6503);

        when(() => mockNetworkChecker.isOnline)
            .thenAnswer((_) async => false);
        when(() => mockStorage.getLocalPins())
            .thenAnswer((_) async => []);
        when(() => mockStorage.setLocalPins(any()))
            .thenAnswer((_) async {});

        final result = await syncService.addPin(
          position: position,
          isAuthenticated: true,
        );

        expect(result.isLocal, true);
        verifyNever(() => mockRepository.addPin(any()));
        verify(() => mockStorage.setLocalPins(any())).called(1);
      });

      test('should add to local storage when not authenticated', () async {
        final position = const LatLng(35.6762, 139.6503);

        when(() => mockStorage.getLocalPins())
            .thenAnswer((_) async => []);
        when(() => mockStorage.setLocalPins(any()))
            .thenAnswer((_) async {});

        final result = await syncService.addPin(
          position: position,
          isAuthenticated: false,
        );

        expect(result.isLocal, true);
        verifyNever(() => mockNetworkChecker.isOnline);
        verifyNever(() => mockRepository.addPin(any()));
      });

      test('should fallback to local when server fails', () async {
        final position = const LatLng(35.6762, 139.6503);

        when(() => mockNetworkChecker.isOnline)
            .thenAnswer((_) async => true);
        when(() => mockRepository.addPin(position))
            .thenThrow(Exception('Server error'));
        when(() => mockStorage.getLocalPins())
            .thenAnswer((_) async => []);
        when(() => mockStorage.setLocalPins(any()))
            .thenAnswer((_) async {});

        final result = await syncService.addPin(
          position: position,
          isAuthenticated: true,
        );

        expect(result.isLocal, true);
      });
    });

    group('deletePin', () {
      test('should delete from server when online and server pin', () async {
        final pin = PinData(
          id: 'server-pin',
          userId: 'user-1',
          position: const LatLng(35.6762, 139.6503),
          createdAt: DateTime.utc(2024, 1, 15),
          isLocal: false,
        );

        when(() => mockNetworkChecker.isOnline)
            .thenAnswer((_) async => true);
        when(() => mockRepository.deletePin('server-pin'))
            .thenAnswer((_) async {});
        when(() => mockStorage.getCachedPins())
            .thenAnswer((_) async => [pin]);
        when(() => mockStorage.setCachedPins(any()))
            .thenAnswer((_) async {});

        await syncService.deletePin(
          pin: pin,
          isAuthenticated: true,
        );

        verify(() => mockRepository.deletePin('server-pin')).called(1);
      });

      test('should delete from local storage when local pin', () async {
        final pin = PinData(
          id: 'local-pin',
          userId: null,
          position: const LatLng(35.6762, 139.6503),
          createdAt: DateTime.utc(2024, 1, 15),
          isLocal: true,
        );

        when(() => mockStorage.getLocalPins())
            .thenAnswer((_) async => [pin]);
        when(() => mockStorage.setLocalPins(any()))
            .thenAnswer((_) async {});

        await syncService.deletePin(
          pin: pin,
          isAuthenticated: false,
        );

        verify(() => mockStorage.setLocalPins([])).called(1);
        verifyNever(() => mockRepository.deletePin(any()));
      });

      test('should add to pending deletions when offline and server pin', () async {
        final pin = PinData(
          id: 'server-pin',
          userId: 'user-1',
          position: const LatLng(35.6762, 139.6503),
          createdAt: DateTime.utc(2024, 1, 15),
          isLocal: false,
        );

        when(() => mockNetworkChecker.isOnline)
            .thenAnswer((_) async => false);
        when(() => mockStorage.getCachedPins())
            .thenAnswer((_) async => [pin]);
        when(() => mockStorage.setCachedPins(any()))
            .thenAnswer((_) async {});
        when(() => mockStorage.getPendingDeletions())
            .thenAnswer((_) async => []);
        when(() => mockStorage.setPendingDeletions(any()))
            .thenAnswer((_) async {});

        await syncService.deletePin(
          pin: pin,
          isAuthenticated: true,
        );

        verify(() => mockStorage.setPendingDeletions(['server-pin'])).called(1);
        verifyNever(() => mockRepository.deletePin(any()));
      });
    });

    group('syncWithServer', () {
      test('should process pending deletions first', () async {
        final pendingDeletions = ['delete-1', 'delete-2'];
        final serverPins = [
          PinData(
            id: 'pin-1',
            userId: 'user-1',
            position: const LatLng(35.6762, 139.6503),
            createdAt: DateTime.utc(2024, 1, 15),
            isLocal: false,
          ),
        ];

        when(() => mockNetworkChecker.isOnline)
            .thenAnswer((_) async => true);
        when(() => mockStorage.getPendingDeletions())
            .thenAnswer((_) async => pendingDeletions);
        when(() => mockStorage.setPendingDeletions(any()))
            .thenAnswer((_) async {});
        when(() => mockRepository.deletePin(any()))
            .thenAnswer((_) async {});
        when(() => mockStorage.getLocalPins())
            .thenAnswer((_) async => []);
        when(() => mockStorage.setLocalPins(any()))
            .thenAnswer((_) async {});
        when(() => mockRepository.getPins())
            .thenAnswer((_) async => serverPins);
        when(() => mockStorage.setCachedPins(any()))
            .thenAnswer((_) async {});

        await syncService.syncWithServer();

        verify(() => mockRepository.deletePin('delete-1')).called(1);
        verify(() => mockRepository.deletePin('delete-2')).called(1);
        verify(() => mockStorage.setPendingDeletions([])).called(1);
      });

      test('should upload local pins to server', () async {
        final localPins = [
          PinData(
            id: 'local-1',
            userId: null,
            position: const LatLng(35.6762, 139.6503),
            createdAt: DateTime.utc(2024, 1, 15),
            isLocal: true,
          ),
        ];
        final uploadedPins = [
          PinData(
            id: 'server-1',
            userId: 'user-1',
            position: const LatLng(35.6762, 139.6503),
            createdAt: DateTime.utc(2024, 1, 15),
            isLocal: false,
          ),
        ];

        when(() => mockNetworkChecker.isOnline)
            .thenAnswer((_) async => true);
        when(() => mockStorage.getPendingDeletions())
            .thenAnswer((_) async => []);
        when(() => mockStorage.getLocalPins())
            .thenAnswer((_) async => localPins);
        when(() => mockRepository.uploadLocalPins(localPins))
            .thenAnswer((_) async => uploadedPins);
        when(() => mockStorage.setLocalPins(any()))
            .thenAnswer((_) async {});
        when(() => mockRepository.getPins())
            .thenAnswer((_) async => uploadedPins);
        when(() => mockStorage.setCachedPins(any()))
            .thenAnswer((_) async {});

        await syncService.syncWithServer();

        verify(() => mockRepository.uploadLocalPins(localPins)).called(1);
        verify(() => mockStorage.setLocalPins([])).called(1);
      });

      test('should update cached pins from server', () async {
        final serverPins = [
          PinData(
            id: 'pin-1',
            userId: 'user-1',
            position: const LatLng(35.6762, 139.6503),
            createdAt: DateTime.utc(2024, 1, 15),
            isLocal: false,
          ),
        ];

        when(() => mockNetworkChecker.isOnline)
            .thenAnswer((_) async => true);
        when(() => mockStorage.getPendingDeletions())
            .thenAnswer((_) async => []);
        when(() => mockStorage.getLocalPins())
            .thenAnswer((_) async => []);
        when(() => mockRepository.getPins())
            .thenAnswer((_) async => serverPins);
        when(() => mockStorage.setCachedPins(serverPins))
            .thenAnswer((_) async {});

        await syncService.syncWithServer();

        verify(() => mockStorage.setCachedPins(serverPins)).called(1);
      });

      test('should not sync when offline', () async {
        when(() => mockNetworkChecker.isOnline)
            .thenAnswer((_) async => false);

        await syncService.syncWithServer();

        verifyNever(() => mockRepository.getPins());
        verifyNever(() => mockStorage.setCachedPins(any()));
      });

      test('should handle deletion errors gracefully', () async {
        when(() => mockNetworkChecker.isOnline)
            .thenAnswer((_) async => true);
        when(() => mockStorage.getPendingDeletions())
            .thenAnswer((_) async => ['delete-1']);
        when(() => mockRepository.deletePin('delete-1'))
            .thenThrow(Exception('Server error'));
        when(() => mockStorage.setPendingDeletions(['delete-1']))
            .thenAnswer((_) async {});
        when(() => mockStorage.getLocalPins())
            .thenAnswer((_) async => []);
        when(() => mockRepository.getPins())
            .thenAnswer((_) async => []);
        when(() => mockStorage.setCachedPins(any()))
            .thenAnswer((_) async {});

        // Should not throw
        await syncService.syncWithServer();

        // Failed deletion remains in pending list
        verify(() => mockStorage.setPendingDeletions(['delete-1'])).called(1);
      });
    });

    group('edge cases', () {
      test('offline add then delete should remove from local storage only', () async {
        final position = const LatLng(35.6762, 139.6503);

        when(() => mockNetworkChecker.isOnline)
            .thenAnswer((_) async => false);

        // First add pin offline
        when(() => mockStorage.getLocalPins())
            .thenAnswer((_) async => []);
        when(() => mockStorage.setLocalPins(any()))
            .thenAnswer((_) async {});

        final addedPin = await syncService.addPin(
          position: position,
          isAuthenticated: true,
        );

        // Verify pin was added locally
        verify(() => mockStorage.setLocalPins(any())).called(1);

        // Now delete it while still offline
        when(() => mockStorage.getLocalPins())
            .thenAnswer((_) async => [addedPin]);

        await syncService.deletePin(
          pin: addedPin,
          isAuthenticated: true,
        );

        // Should not add to pending deletions since it was a local pin
        verifyNever(() => mockStorage.setPendingDeletions(any()));
      });
    });

    group('updatePinTags', () {
      test('updates local pin tagIds without calling server', () async {
        final localPin = PinData(
          id: 'local-1',
          userId: null,
          position: const LatLng(35.0, 139.0),
          createdAt: DateTime.utc(2024, 1, 15),
          isLocal: true,
          tagIds: const [],
        );

        when(() => mockStorage.getLocalPins())
            .thenAnswer((_) async => [localPin]);
        when(() => mockStorage.setLocalPins(any()))
            .thenAnswer((_) async {});

        final result = await syncService.updatePinTags(
          pinId: 'local-1',
          tagIds: ['t1', 't2'],
          isAuthenticated: true,
        );

        expect(result?.id, 'local-1');
        expect(result?.tagIds, ['t1', 't2']);

        final captured =
            verify(() => mockStorage.setLocalPins(captureAny())).captured;
        final saved = captured.last as List<PinData>;
        expect(saved.single.tagIds, ['t1', 't2']);

        verifyNever(() => mockRepository.updatePinTags(any(), any()));
      });

      test('server pin: optimistic + server call when online + auth',
          () async {
        final serverPin = PinData(
          id: 'srv-1',
          userId: 'user-1',
          position: const LatLng(35.0, 139.0),
          createdAt: DateTime.utc(2024, 1, 15),
          isLocal: false,
          tagIds: const ['old'],
        );
        final serverResult = serverPin.copyWith(tagIds: ['t1', 't2']);

        when(() => mockStorage.getLocalPins()).thenAnswer((_) async => []);
        // First call returns current cache; subsequent calls should reflect optimistic update.
        final caches = <List<PinData>>[
          [serverPin],
          [serverPin.copyWith(tagIds: ['t1', 't2'])],
        ];
        var callIdx = 0;
        when(() => mockStorage.getCachedPins())
            .thenAnswer((_) async => caches[callIdx++]);
        when(() => mockStorage.setCachedPins(any())).thenAnswer((_) async {});
        when(() => mockNetworkChecker.isOnline).thenAnswer((_) async => true);
        when(() => mockRepository.updatePinTags('srv-1', ['t1', 't2']))
            .thenAnswer((_) async => serverResult);

        final result = await syncService.updatePinTags(
          pinId: 'srv-1',
          tagIds: ['t1', 't2'],
          isAuthenticated: true,
        );

        expect(result?.id, 'srv-1');
        expect(result?.tagIds, ['t1', 't2']);
        verify(() => mockRepository.updatePinTags('srv-1', ['t1', 't2']))
            .called(1);
        // setCachedPins should have been called twice: optimistic + server response
        verify(() => mockStorage.setCachedPins(any())).called(2);
      });

      test('server pin: offline queues pending tag update', () async {
        final serverPin = PinData(
          id: 'srv-1',
          userId: 'user-1',
          position: const LatLng(35.0, 139.0),
          createdAt: DateTime.utc(2024, 1, 15),
          isLocal: false,
          tagIds: const [],
        );

        when(() => mockStorage.getLocalPins()).thenAnswer((_) async => []);
        when(() => mockStorage.getCachedPins())
            .thenAnswer((_) async => [serverPin]);
        when(() => mockStorage.setCachedPins(any())).thenAnswer((_) async {});
        when(() => mockNetworkChecker.isOnline).thenAnswer((_) async => false);

        final result = await syncService.updatePinTags(
          pinId: 'srv-1',
          tagIds: ['t1'],
          isAuthenticated: true,
        );

        expect(result?.tagIds, ['t1']);
        verifyNever(() => mockRepository.updatePinTags(any(), any()));

        final captured =
            verify(() => mockStorage.setPendingTagUpdates(captureAny()))
                .captured;
        final savedMap = captured.last as Map<String, List<String>>;
        expect(savedMap, {'srv-1': ['t1']});
      });

      test('server pin: unauthenticated queues pending tag update', () async {
        final serverPin = PinData(
          id: 'srv-1',
          userId: 'user-1',
          position: const LatLng(35.0, 139.0),
          createdAt: DateTime.utc(2024, 1, 15),
          isLocal: false,
          tagIds: const [],
        );

        when(() => mockStorage.getLocalPins()).thenAnswer((_) async => []);
        when(() => mockStorage.getCachedPins())
            .thenAnswer((_) async => [serverPin]);
        when(() => mockStorage.setCachedPins(any())).thenAnswer((_) async {});
        when(() => mockNetworkChecker.isOnline).thenAnswer((_) async => true);

        final result = await syncService.updatePinTags(
          pinId: 'srv-1',
          tagIds: ['t1'],
          isAuthenticated: false,
        );

        expect(result?.tagIds, ['t1']);
        verifyNever(() => mockRepository.updatePinTags(any(), any()));

        final captured =
            verify(() => mockStorage.setPendingTagUpdates(captureAny()))
                .captured;
        final savedMap = captured.last as Map<String, List<String>>;
        expect(savedMap, {'srv-1': ['t1']});
      });

      test('server pin: server error queues pending update and returns optimistic',
          () async {
        final serverPin = PinData(
          id: 'srv-1',
          userId: 'user-1',
          position: const LatLng(35.0, 139.0),
          createdAt: DateTime.utc(2024, 1, 15),
          isLocal: false,
          tagIds: const [],
        );

        when(() => mockStorage.getLocalPins()).thenAnswer((_) async => []);
        when(() => mockStorage.getCachedPins())
            .thenAnswer((_) async => [serverPin]);
        when(() => mockStorage.setCachedPins(any())).thenAnswer((_) async {});
        when(() => mockNetworkChecker.isOnline).thenAnswer((_) async => true);
        when(() => mockRepository.updatePinTags('srv-1', ['t1']))
            .thenThrow(Exception('boom'));

        final result = await syncService.updatePinTags(
          pinId: 'srv-1',
          tagIds: ['t1'],
          isAuthenticated: true,
        );

        expect(result?.id, 'srv-1');
        expect(result?.tagIds, ['t1']);

        final captured =
            verify(() => mockStorage.setPendingTagUpdates(captureAny()))
                .captured;
        final savedMap = captured.last as Map<String, List<String>>;
        expect(savedMap, {'srv-1': ['t1']});
      });
    });

    group('remapLocalTagIds', () {
      test('does nothing when mapping is empty', () async {
        await syncService.remapLocalTagIds({});

        verifyNever(() => mockStorage.getLocalPins());
        verifyNever(() => mockStorage.setLocalPins(any()));
        verifyNever(() => mockStorage.getCachedPins());
        verifyNever(() => mockStorage.setCachedPins(any()));
        verifyNever(() => mockStorage.setPendingTagUpdates(any()));
      });

      test('remaps tagIds in local pins, cached pins, and pending updates',
          () async {
        final localPin = PinData(
          id: 'local-1',
          userId: null,
          position: const LatLng(35.0, 139.0),
          createdAt: DateTime.utc(2024, 1, 15),
          isLocal: true,
          tagIds: const ['old-1', 'old-2', 'keep'],
        );
        final cachedPin = PinData(
          id: 'srv-1',
          userId: 'user-1',
          position: const LatLng(36.0, 140.0),
          createdAt: DateTime.utc(2024, 1, 15),
          isLocal: false,
          tagIds: const ['old-1'],
        );

        when(() => mockStorage.getLocalPins())
            .thenAnswer((_) async => [localPin]);
        when(() => mockStorage.setLocalPins(any()))
            .thenAnswer((_) async {});
        when(() => mockStorage.getCachedPins())
            .thenAnswer((_) async => [cachedPin]);
        when(() => mockStorage.setCachedPins(any()))
            .thenAnswer((_) async {});
        when(() => mockStorage.getPendingTagUpdates()).thenAnswer(
          (_) async => {'srv-1': ['old-1', 'keep']},
        );

        await syncService.remapLocalTagIds({
          'old-1': 'new-1',
          'old-2': 'new-2',
        });

        final localCaptured =
            verify(() => mockStorage.setLocalPins(captureAny())).captured;
        final savedLocal = localCaptured.last as List<PinData>;
        expect(savedLocal.single.tagIds, ['new-1', 'new-2', 'keep']);

        final cachedCaptured =
            verify(() => mockStorage.setCachedPins(captureAny())).captured;
        final savedCached = cachedCaptured.last as List<PinData>;
        expect(savedCached.single.tagIds, ['new-1']);

        final pendingCaptured =
            verify(() => mockStorage.setPendingTagUpdates(captureAny()))
                .captured;
        final savedPending =
            pendingCaptured.last as Map<String, List<String>>;
        expect(savedPending, {'srv-1': ['new-1', 'keep']});
      });

      test('does not touch pending updates when empty', () async {
        when(() => mockStorage.getLocalPins()).thenAnswer((_) async => []);
        when(() => mockStorage.setLocalPins(any())).thenAnswer((_) async {});
        when(() => mockStorage.getCachedPins()).thenAnswer((_) async => []);
        when(() => mockStorage.setCachedPins(any())).thenAnswer((_) async {});
        when(() => mockStorage.getPendingTagUpdates())
            .thenAnswer((_) async => <String, List<String>>{});

        await syncService.remapLocalTagIds({'old': 'new'});

        verifyNever(() => mockStorage.setPendingTagUpdates(any()));
      });
    });

    group('syncWithServer with tag updates', () {
      test('processes pending tag updates and clears queue on success',
          () async {
        when(() => mockNetworkChecker.isOnline).thenAnswer((_) async => true);
        when(() => mockStorage.getPendingDeletions())
            .thenAnswer((_) async => []);
        when(() => mockStorage.getLocalPins()).thenAnswer((_) async => []);
        when(() => mockStorage.getPendingTagUpdates()).thenAnswer(
          (_) async => {'srv-1': ['t1'], 'srv-2': ['t2']},
        );
        when(() => mockRepository.updatePinTags(any(), any()))
            .thenAnswer((_) async => null);
        when(() => mockRepository.getPins()).thenAnswer((_) async => []);
        when(() => mockStorage.setCachedPins(any())).thenAnswer((_) async {});

        await syncService.syncWithServer();

        verify(() => mockRepository.updatePinTags('srv-1', ['t1'])).called(1);
        verify(() => mockRepository.updatePinTags('srv-2', ['t2'])).called(1);

        final captured =
            verify(() => mockStorage.setPendingTagUpdates(captureAny()))
                .captured;
        final savedMap = captured.last as Map<String, List<String>>;
        expect(savedMap, isEmpty);
      });

      test('keeps failed entries in the pending tag updates queue', () async {
        when(() => mockNetworkChecker.isOnline).thenAnswer((_) async => true);
        when(() => mockStorage.getPendingDeletions())
            .thenAnswer((_) async => []);
        when(() => mockStorage.getLocalPins()).thenAnswer((_) async => []);
        when(() => mockStorage.getPendingTagUpdates()).thenAnswer(
          (_) async => {'srv-1': ['t1'], 'srv-2': ['t2']},
        );
        when(() => mockRepository.updatePinTags('srv-1', ['t1']))
            .thenAnswer((_) async => null);
        when(() => mockRepository.updatePinTags('srv-2', ['t2']))
            .thenThrow(Exception('boom'));
        when(() => mockRepository.getPins()).thenAnswer((_) async => []);
        when(() => mockStorage.setCachedPins(any())).thenAnswer((_) async {});

        await syncService.syncWithServer();

        final captured =
            verify(() => mockStorage.setPendingTagUpdates(captureAny()))
                .captured;
        final savedMap = captured.last as Map<String, List<String>>;
        expect(savedMap, {'srv-2': ['t2']});
      });

      test('uploading local pins queues tagIds of uploaded pins', () async {
        final localPinA = PinData(
          id: 'local-A',
          userId: null,
          position: const LatLng(35.0, 139.0),
          createdAt: DateTime.utc(2024, 1, 15),
          isLocal: true,
          tagIds: const ['t1', 't2'],
        );
        final localPinB = PinData(
          id: 'local-B',
          userId: null,
          position: const LatLng(36.0, 140.0),
          createdAt: DateTime.utc(2024, 1, 15),
          isLocal: true,
          tagIds: const [],
        );
        final uploadedA = PinData(
          id: 'srv-A',
          userId: 'user-1',
          position: const LatLng(35.0, 139.0),
          createdAt: DateTime.utc(2024, 1, 15),
          isLocal: false,
        );
        final uploadedB = PinData(
          id: 'srv-B',
          userId: 'user-1',
          position: const LatLng(36.0, 140.0),
          createdAt: DateTime.utc(2024, 1, 15),
          isLocal: false,
        );

        when(() => mockNetworkChecker.isOnline).thenAnswer((_) async => true);
        when(() => mockStorage.getPendingDeletions())
            .thenAnswer((_) async => []);
        when(() => mockStorage.getLocalPins())
            .thenAnswer((_) async => [localPinA, localPinB]);
        when(() => mockRepository.uploadLocalPins([localPinA, localPinB]))
            .thenAnswer((_) async => [uploadedA, uploadedB]);
        when(() => mockStorage.setLocalPins(any())).thenAnswer((_) async {});
        // First call: _uploadLocalPins reads (empty). Second: _processPendingTagUpdates reads new map.
        final pendingCalls = <Map<String, List<String>>>[
          {},
          {'srv-A': ['t1', 't2']},
        ];
        var pendingIdx = 0;
        when(() => mockStorage.getPendingTagUpdates())
            .thenAnswer((_) async => pendingCalls[pendingIdx++]);
        when(() => mockRepository.updatePinTags(any(), any()))
            .thenAnswer((_) async => null);
        when(() => mockRepository.getPins()).thenAnswer((_) async => []);
        when(() => mockStorage.setCachedPins(any())).thenAnswer((_) async {});

        await syncService.syncWithServer();

        // setPendingTagUpdates called twice: first with the upload-queued map,
        // then with the remaining after _processPendingTagUpdates finishes.
        final captured =
            verify(() => mockStorage.setPendingTagUpdates(captureAny()))
                .captured;
        final firstSaved = captured[0] as Map<String, List<String>>;
        expect(firstSaved, {'srv-A': ['t1', 't2']});
        // Only the A upload got queued; B had empty tagIds
        expect(firstSaved.containsKey('srv-B'), false);
      });
    });

    group('remapLocalMapIds', () {
      test('should update mapIds of local pins matching the mapping', () async {
        final localPins = [
          PinData(
            id: 'pin-1',
            userId: null,
            mapId: 'local-map-1',
            position: const LatLng(35.6762, 139.6503),
            createdAt: DateTime.utc(2024, 1, 15),
            isLocal: true,
          ),
          PinData(
            id: 'pin-2',
            userId: null,
            mapId: 'local-map-2',
            position: const LatLng(35.6895, 139.6917),
            createdAt: DateTime.utc(2024, 1, 16),
            isLocal: true,
          ),
        ];

        when(() => mockStorage.getLocalPins())
            .thenAnswer((_) async => localPins);
        when(() => mockStorage.setLocalPins(any()))
            .thenAnswer((_) async {});

        await syncService.remapLocalMapIds({
          'local-map-1': 'server-map-1',
        });

        final captured =
            verify(() => mockStorage.setLocalPins(captureAny())).captured;
        final updatedPins = captured.last as List<PinData>;

        expect(updatedPins[0].mapId, 'server-map-1');
        expect(updatedPins[1].mapId, 'local-map-2');
      });

      test('should do nothing when mapping is empty', () async {
        await syncService.remapLocalMapIds({});

        verifyNever(() => mockStorage.getLocalPins());
        verifyNever(() => mockStorage.setLocalPins(any()));
      });
    });

    group('clearIfUserChanged', () {
      test('should clear local data when user signs out', () async {
        when(() => mockStorage.getLastUserId())
            .thenAnswer((_) async => 'user-1');
        when(() => mockStorage.clearAll())
            .thenAnswer((_) async {});
        when(() => mockStorage.setLastUserId(null))
            .thenAnswer((_) async {});

        await syncService.clearIfUserChanged(null);

        verify(() => mockStorage.clearAll()).called(1);
        verify(() => mockStorage.setLastUserId(null)).called(1);
      });

      test('should clear local data when switching to different user', () async {
        when(() => mockStorage.getLastUserId())
            .thenAnswer((_) async => 'user-1');
        when(() => mockStorage.clearAll())
            .thenAnswer((_) async {});
        when(() => mockStorage.setLastUserId('user-2'))
            .thenAnswer((_) async {});

        await syncService.clearIfUserChanged('user-2');

        verify(() => mockStorage.clearAll()).called(1);
        verify(() => mockStorage.setLastUserId('user-2')).called(1);
      });

      test('should not clear local data when user remains the same', () async {
        when(() => mockStorage.getLastUserId())
            .thenAnswer((_) async => 'user-1');
        when(() => mockStorage.setLastUserId('user-1'))
            .thenAnswer((_) async {});

        await syncService.clearIfUserChanged('user-1');

        verifyNever(() => mockStorage.clearAll());
        verify(() => mockStorage.setLastUserId('user-1')).called(1);
      });

      test('should not clear local data when signing in from unauthenticated state', () async {
        when(() => mockStorage.getLastUserId())
            .thenAnswer((_) async => null);
        when(() => mockStorage.setLastUserId('user-1'))
            .thenAnswer((_) async {});

        await syncService.clearIfUserChanged('user-1');

        verifyNever(() => mockStorage.clearAll());
        verify(() => mockStorage.setLastUserId('user-1')).called(1);
      });

      test('should not clear local data when both are null', () async {
        when(() => mockStorage.getLastUserId())
            .thenAnswer((_) async => null);
        when(() => mockStorage.setLastUserId(null))
            .thenAnswer((_) async {});

        await syncService.clearIfUserChanged(null);

        verifyNever(() => mockStorage.clearAll());
        verify(() => mockStorage.setLastUserId(null)).called(1);
      });
    });
  });
}
