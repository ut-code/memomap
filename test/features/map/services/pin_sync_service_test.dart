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
  });

  setUp(() {
    mockStorage = MockLocalPinStorage();
    mockNetworkChecker = MockNetworkChecker();
    mockRepository = MockPinRepository();

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
