import 'package:flutter_test/flutter_test.dart';
import 'package:memomap/features/map/data/map_repository.dart';
import 'package:memomap/features/map/services/map_sync_service.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

void main() {
  late MockLocalMapStorage mockStorage;
  late MockNetworkChecker mockNetworkChecker;
  late MockMapRepository mockRepository;
  late MapSyncService syncService;

  setUpAll(() {
    registerFallbackValue(<MapData>[]);
    registerFallbackValue(<String>[]);
  });

  setUp(() {
    mockStorage = MockLocalMapStorage();
    mockNetworkChecker = MockNetworkChecker();
    mockRepository = MockMapRepository();

    syncService = MapSyncService(
      storage: mockStorage,
      networkChecker: mockNetworkChecker,
      repository: mockRepository,
    );
  });

  group('MapSyncService', () {
    group('getAllMaps', () {
      test('should return cached + local maps', () async {
        final cachedMaps = [
          MapData(
            id: 'cached-1',
            userId: 'user-1',
            name: 'Cached Map',
            createdAt: DateTime.utc(2024, 1, 15),
          ),
        ];
        final localMaps = [
          MapData(
            id: 'local-1',
            userId: null,
            name: 'Local Map',
            createdAt: DateTime.utc(2024, 1, 16),
            isLocal: true,
          ),
        ];

        when(() => mockStorage.getCachedMaps())
            .thenAnswer((_) async => cachedMaps);
        when(() => mockStorage.getLocalMaps())
            .thenAnswer((_) async => localMaps);

        final maps = await syncService.getAllMaps();

        expect(maps.length, 2);
        expect(maps.any((m) => m.id == 'cached-1'), true);
        expect(maps.any((m) => m.id == 'local-1'), true);
      });
    });

    group('createMap', () {
      test('should create on server when online and authenticated', () async {
        final serverMap = MapData(
          id: 'server-id',
          userId: 'user-1',
          name: 'Test Map',
          createdAt: DateTime.utc(2024, 1, 15),
        );

        when(() => mockNetworkChecker.isOnline)
            .thenAnswer((_) async => true);
        when(() => mockRepository.createMap(
              name: 'Test Map',
              description: null,
            )).thenAnswer((_) async => serverMap);
        when(() => mockStorage.getCachedMaps())
            .thenAnswer((_) async => []);
        when(() => mockStorage.setCachedMaps(any()))
            .thenAnswer((_) async {});

        final result = await syncService.createMap(
          name: 'Test Map',
          isAuthenticated: true,
        );

        expect(result.id, 'server-id');
        expect(result.isLocal, false);
        verify(() => mockRepository.createMap(
              name: 'Test Map',
              description: null,
            )).called(1);
      });

      test('should create locally when offline', () async {
        when(() => mockNetworkChecker.isOnline)
            .thenAnswer((_) async => false);
        when(() => mockStorage.getLocalMaps())
            .thenAnswer((_) async => []);
        when(() => mockStorage.setLocalMaps(any()))
            .thenAnswer((_) async {});

        final result = await syncService.createMap(
          name: 'Test Map',
          isAuthenticated: true,
        );

        expect(result.isLocal, true);
        expect(result.name, 'Test Map');
        verifyNever(() => mockRepository.createMap(
              name: any(named: 'name'),
              description: any(named: 'description'),
            ));
      });

      test('should create locally when not authenticated', () async {
        when(() => mockNetworkChecker.isOnline)
            .thenAnswer((_) async => true);
        when(() => mockStorage.getLocalMaps())
            .thenAnswer((_) async => []);
        when(() => mockStorage.setLocalMaps(any()))
            .thenAnswer((_) async {});

        final result = await syncService.createMap(
          name: 'Test Map',
          isAuthenticated: false,
        );

        expect(result.isLocal, true);
      });
    });

    group('deleteMap', () {
      test('should delete from local storage when local map', () async {
        final localMap = MapData(
          id: 'local-1',
          userId: null,
          name: 'Local Map',
          createdAt: DateTime.utc(2024, 1, 15),
          isLocal: true,
        );

        when(() => mockStorage.getLocalMaps())
            .thenAnswer((_) async => [localMap]);
        when(() => mockStorage.setLocalMaps(any()))
            .thenAnswer((_) async {});

        await syncService.deleteMap(
          map: localMap,
          isAuthenticated: false,
        );

        verify(() => mockStorage.setLocalMaps([])).called(1);
        verifyNever(() => mockRepository.deleteMap(any()));
      });

      test('should delete from server when online and server map', () async {
        final serverMap = MapData(
          id: 'server-1',
          userId: 'user-1',
          name: 'Server Map',
          createdAt: DateTime.utc(2024, 1, 15),
        );

        when(() => mockNetworkChecker.isOnline)
            .thenAnswer((_) async => true);
        when(() => mockRepository.deleteMap('server-1'))
            .thenAnswer((_) async {});
        when(() => mockStorage.getCachedMaps())
            .thenAnswer((_) async => [serverMap]);
        when(() => mockStorage.setCachedMaps(any()))
            .thenAnswer((_) async {});

        await syncService.deleteMap(
          map: serverMap,
          isAuthenticated: true,
        );

        verify(() => mockRepository.deleteMap('server-1')).called(1);
      });

      test('should add to pending deletions when offline and server map',
          () async {
        final serverMap = MapData(
          id: 'server-1',
          userId: 'user-1',
          name: 'Server Map',
          createdAt: DateTime.utc(2024, 1, 15),
        );

        when(() => mockNetworkChecker.isOnline)
            .thenAnswer((_) async => false);
        when(() => mockStorage.getCachedMaps())
            .thenAnswer((_) async => [serverMap]);
        when(() => mockStorage.setCachedMaps(any()))
            .thenAnswer((_) async {});
        when(() => mockStorage.getPendingDeletions())
            .thenAnswer((_) async => []);
        when(() => mockStorage.setPendingDeletions(any()))
            .thenAnswer((_) async {});

        await syncService.deleteMap(
          map: serverMap,
          isAuthenticated: true,
        );

        verify(() => mockStorage.setPendingDeletions(['server-1'])).called(1);
        verifyNever(() => mockRepository.deleteMap(any()));
      });
    });

    group('syncWithServer', () {
      test('should not sync when offline', () async {
        when(() => mockNetworkChecker.isOnline)
            .thenAnswer((_) async => false);

        final result = await syncService.syncWithServer();

        expect(result, isEmpty);
        verifyNever(() => mockRepository.getMaps());
      });

      test('should process pending deletions', () async {
        when(() => mockNetworkChecker.isOnline)
            .thenAnswer((_) async => true);
        when(() => mockStorage.getPendingDeletions())
            .thenAnswer((_) async => ['del-1', 'del-2']);
        when(() => mockStorage.setPendingDeletions(any()))
            .thenAnswer((_) async {});
        when(() => mockRepository.deleteMap(any()))
            .thenAnswer((_) async {});
        when(() => mockStorage.getLocalMaps())
            .thenAnswer((_) async => []);
        when(() => mockRepository.getMaps())
            .thenAnswer((_) async => []);
        when(() => mockStorage.setCachedMaps(any()))
            .thenAnswer((_) async {});

        await syncService.syncWithServer();

        verify(() => mockRepository.deleteMap('del-1')).called(1);
        verify(() => mockRepository.deleteMap('del-2')).called(1);
        verify(() => mockStorage.setPendingDeletions([])).called(1);
      });

      test('should upload local maps and return ID mapping', () async {
        final localMap = MapData(
          id: 'local-uuid',
          userId: null,
          name: 'My Map',
          createdAt: DateTime.utc(2024, 1, 15),
          isLocal: true,
        );
        final serverMap = MapData(
          id: 'server-uuid',
          userId: 'user-1',
          name: 'My Map',
          createdAt: DateTime.utc(2024, 1, 15),
        );

        when(() => mockNetworkChecker.isOnline)
            .thenAnswer((_) async => true);
        when(() => mockStorage.getPendingDeletions())
            .thenAnswer((_) async => []);
        when(() => mockStorage.setPendingDeletions(any()))
            .thenAnswer((_) async {});
        when(() => mockStorage.getLocalMaps())
            .thenAnswer((_) async => [localMap]);
        when(() => mockRepository.uploadLocalMaps(any()))
            .thenAnswer((_) async => {'local-uuid': 'server-uuid'});
        when(() => mockStorage.setLocalMaps(any()))
            .thenAnswer((_) async {});
        when(() => mockRepository.getMaps())
            .thenAnswer((_) async => [serverMap]);
        when(() => mockStorage.setCachedMaps(any()))
            .thenAnswer((_) async {});

        final idMapping = await syncService.syncWithServer();

        expect(idMapping, {'local-uuid': 'server-uuid'});
        verify(() => mockStorage.setLocalMaps([])).called(1);
      });

      test('should return empty mapping when no local maps', () async {
        when(() => mockNetworkChecker.isOnline)
            .thenAnswer((_) async => true);
        when(() => mockStorage.getPendingDeletions())
            .thenAnswer((_) async => []);
        when(() => mockStorage.setPendingDeletions(any()))
            .thenAnswer((_) async {});
        when(() => mockStorage.getLocalMaps())
            .thenAnswer((_) async => []);
        when(() => mockRepository.getMaps())
            .thenAnswer((_) async => []);
        when(() => mockStorage.setCachedMaps(any()))
            .thenAnswer((_) async {});

        final idMapping = await syncService.syncWithServer();

        expect(idMapping, isEmpty);
      });

      test('should handle pending deletion errors gracefully', () async {
        when(() => mockNetworkChecker.isOnline)
            .thenAnswer((_) async => true);
        when(() => mockStorage.getPendingDeletions())
            .thenAnswer((_) async => ['del-1']);
        when(() => mockRepository.deleteMap('del-1'))
            .thenThrow(Exception('Server error'));
        when(() => mockStorage.setPendingDeletions(['del-1']))
            .thenAnswer((_) async {});
        when(() => mockStorage.getLocalMaps())
            .thenAnswer((_) async => []);
        when(() => mockRepository.getMaps())
            .thenAnswer((_) async => []);
        when(() => mockStorage.setCachedMaps(any()))
            .thenAnswer((_) async {});

        await syncService.syncWithServer();

        verify(() => mockStorage.setPendingDeletions(['del-1'])).called(1);
      });

      test('should not duplicate maps after sync (local map uploaded)', () async {
        final localMap = MapData(
          id: 'local-uuid',
          userId: null,
          name: 'My Map',
          createdAt: DateTime.utc(2024, 1, 15),
          isLocal: true,
        );
        final serverMap = MapData(
          id: 'server-uuid',
          userId: 'user-1',
          name: 'My Map',
          createdAt: DateTime.utc(2024, 1, 15),
        );

        // Before sync: local storage has the local map, cache is empty
        var currentLocalMaps = [localMap];
        var currentCachedMaps = <MapData>[];

        when(() => mockNetworkChecker.isOnline)
            .thenAnswer((_) async => true);
        when(() => mockStorage.getPendingDeletions())
            .thenAnswer((_) async => []);
        when(() => mockStorage.setPendingDeletions(any()))
            .thenAnswer((_) async {});
        when(() => mockStorage.getLocalMaps())
            .thenAnswer((_) async => currentLocalMaps);
        when(() => mockStorage.setLocalMaps(any())).thenAnswer((inv) async {
          currentLocalMaps =
              inv.positionalArguments[0] as List<MapData>;
        });
        when(() => mockStorage.getCachedMaps())
            .thenAnswer((_) async => currentCachedMaps);
        when(() => mockStorage.setCachedMaps(any())).thenAnswer((inv) async {
          currentCachedMaps =
              inv.positionalArguments[0] as List<MapData>;
        });
        when(() => mockRepository.uploadLocalMaps(any()))
            .thenAnswer((_) async => {'local-uuid': 'server-uuid'});
        when(() => mockRepository.getMaps())
            .thenAnswer((_) async => [serverMap]);

        await syncService.syncWithServer();

        // After sync, getAllMaps should return exactly 1 map (no duplication)
        final allMaps = await syncService.getAllMaps();
        expect(allMaps.length, 1);
        expect(allMaps.first.id, 'server-uuid');
      });
    });

    group('clearIfUserChanged', () {
      test('should clear when user changed', () async {
        when(() => mockStorage.getLastUserId())
            .thenAnswer((_) async => 'user-1');
        when(() => mockStorage.clearAll()).thenAnswer((_) async {});
        when(() => mockStorage.setLastUserId('user-2'))
            .thenAnswer((_) async {});

        await syncService.clearIfUserChanged('user-2');

        verify(() => mockStorage.clearAll()).called(1);
      });

      test('should not clear when user is the same', () async {
        when(() => mockStorage.getLastUserId())
            .thenAnswer((_) async => 'user-1');
        when(() => mockStorage.setLastUserId('user-1'))
            .thenAnswer((_) async {});

        await syncService.clearIfUserChanged('user-1');

        verifyNever(() => mockStorage.clearAll());
      });
    });
  });
}
