import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memomap/features/auth/providers/auth_provider.dart';
import 'package:memomap/features/map/data/map_repository.dart';
import 'package:memomap/features/map/providers/current_map_provider.dart';
import 'package:memomap/features/map/providers/map_provider.dart';
import 'package:memomap/features/map/services/map_sync_service.dart';
import 'package:mocktail/mocktail.dart';

class MockMapSyncService extends Mock implements MapSyncService {}

void main() {
  group('CurrentMapIdNotifier', () {
    late MockMapSyncService mockSyncService;

    setUpAll(() {
      registerFallbackValue(MapData(
        id: 'fallback',
        userId: null,
        name: 'Fallback',
        description: null,
        createdAt: DateTime.now(),
        isLocal: true,
      ));
    });

    setUp(() {
      mockSyncService = MockMapSyncService();
      when(() => mockSyncService.clearIfUserChanged(any()))
          .thenAnswer((_) async {});
      when(() => mockSyncService.syncWithServer())
          .thenAnswer((_) async => <String, String>{});
      when(() => mockSyncService.setCurrentMapId(any()))
          .thenAnswer((_) async {});
    });

    test('should NOT create duplicate default map when reloading with existing map', () async {
      // Setup: 1 Default Map exists, saved as current
      final existingMap = MapData(
        id: 'existing-default-map',
        userId: null,
        name: 'Default Map',
        description: 'First map',
        createdAt: DateTime.now(),
        isLocal: true,
      );

      when(() => mockSyncService.getAllMaps())
          .thenAnswer((_) async => [existingMap]);
      when(() => mockSyncService.getCurrentMapId())
          .thenAnswer((_) async => existingMap.id);

      final container = ProviderContainer(
        overrides: [
          mapSyncServiceProvider.overrideWith((ref) async => mockSyncService),
          sessionProvider.overrideWith((ref) async => null),
          isAuthenticatedProvider.overrideWithValue(false),
        ],
      );

      // Trigger currentMapIdProvider to initialize
      container.read(currentMapIdProvider);

      // Wait for async initialization to complete
      await Future.delayed(const Duration(milliseconds: 500));

      // Verify: getCurrentMapId was called (proves initialization ran)
      verify(() => mockSyncService.getCurrentMapId()).called(1);

      // Verify: createMap should NOT be called
      verifyNever(() => mockSyncService.createMap(
            name: any(named: 'name'),
            description: any(named: 'description'),
            isAuthenticated: any(named: 'isAuthenticated'),
          ));

      // Verify: current map is the existing one
      expect(container.read(currentMapIdProvider), existingMap.id);

      // Verify: only 1 map exists
      final maps = await container.read(mapsProvider.future);
      expect(maps.length, 1);

      container.dispose();
    });

    test('should create default when cache is empty and savedMapId is stale', () async {
      // Scenario: savedMapId exists but maps list is empty (unauthenticated).
      // The saved map is unrecoverable, so a default map should be created.
      final savedMapId = 'saved-map-id';

      when(() => mockSyncService.getAllMaps()).thenAnswer((_) async => []);
      when(() => mockSyncService.getCurrentMapId())
          .thenAnswer((_) async => savedMapId);

      final createdMap = MapData(
        id: 'new-default-map',
        userId: null,
        name: 'Default Map',
        description: 'First map',
        createdAt: DateTime.now(),
        isLocal: true,
      );
      when(() => mockSyncService.createMap(
            name: any(named: 'name'),
            description: any(named: 'description'),
            isAuthenticated: any(named: 'isAuthenticated'),
          )).thenAnswer((_) async => createdMap);

      final container = ProviderContainer(
        overrides: [
          mapSyncServiceProvider.overrideWith((ref) async => mockSyncService),
          sessionProvider.overrideWith((ref) async => null),
          isAuthenticatedProvider.overrideWithValue(false),
        ],
      );

      // Trigger initialization
      container.read(currentMapIdProvider);
      await Future.delayed(const Duration(milliseconds: 500));

      // Should create a default map because the saved map is unrecoverable
      verify(() => mockSyncService.createMap(
            name: 'Default Map',
            description: 'First map',
            isAuthenticated: false,
          )).called(greaterThanOrEqualTo(1));

      container.dispose();
    });

    test('should NOT create new default when reloading with existing default map and pins', () async {
      // Scenario: User created default map, added pins, then reloads
      final existingDefault = MapData(
        id: 'default-map-with-pins',
        userId: null,
        name: 'Default Map',
        description: 'First map',
        createdAt: DateTime.now(),
        isLocal: true,
      );

      when(() => mockSyncService.getAllMaps())
          .thenAnswer((_) async => [existingDefault]);
      when(() => mockSyncService.getCurrentMapId())
          .thenAnswer((_) async => existingDefault.id);

      final container = ProviderContainer(
        overrides: [
          mapSyncServiceProvider.overrideWith((ref) async => mockSyncService),
          sessionProvider.overrideWith((ref) async => null),
          isAuthenticatedProvider.overrideWithValue(false),
        ],
      );

      container.read(currentMapIdProvider);
      await Future.delayed(const Duration(milliseconds: 500));

      // Should NOT create a new map
      verifyNever(() => mockSyncService.createMap(
            name: any(named: 'name'),
            description: any(named: 'description'),
            isAuthenticated: any(named: 'isAuthenticated'),
          ));

      expect(container.read(currentMapIdProvider), existingDefault.id);

      container.dispose();
    });

    test('should create default map via ensureValidMapSelected when maps is empty', () async {
      // Scenario: After sync, maps list is empty and currentMapId is stale.
      // ensureValidMapSelected() should create a default map.
      final staleMapId = 'stale-map-id';

      when(() => mockSyncService.getAllMaps())
          .thenAnswer((_) async => []);
      when(() => mockSyncService.getCurrentMapId())
          .thenAnswer((_) async => staleMapId);

      final createdMap = MapData(
        id: 'new-default-map',
        userId: null,
        name: 'Default Map',
        description: 'First map',
        createdAt: DateTime.now(),
        isLocal: true,
      );
      when(() => mockSyncService.createMap(
            name: any(named: 'name'),
            description: any(named: 'description'),
            isAuthenticated: any(named: 'isAuthenticated'),
          )).thenAnswer((_) async => createdMap);

      final container = ProviderContainer(
        overrides: [
          mapSyncServiceProvider.overrideWith((ref) async => mockSyncService),
          sessionProvider.overrideWith((ref) async => null),
          isAuthenticatedProvider.overrideWithValue(false),
        ],
      );

      // Initialize providers
      container.read(currentMapIdProvider);
      await Future.delayed(const Duration(milliseconds: 300));

      // Simulate post-sync: maps list is empty
      container.read(mapsProvider.notifier).state =
          const AsyncValue.data([]);

      // Call ensureValidMapSelected (as MapsNotifier.build() does after sync)
      await container
          .read(currentMapIdProvider.notifier)
          .ensureValidMapSelected();

      await Future.delayed(const Duration(milliseconds: 300));

      // Should have created a default map
      verify(() => mockSyncService.createMap(
            name: 'Default Map',
            description: 'First map',
            isAuthenticated: false,
          )).called(greaterThanOrEqualTo(1));

      container.dispose();
    });

    test('should create default map when savedMapId is null (first launch)', () async {
      // savedMapId == null means no map has been created yet
      // So we should create a default map
      when(() => mockSyncService.getAllMaps()).thenAnswer((_) async => []);
      when(() => mockSyncService.getCurrentMapId())
          .thenAnswer((_) async => null);

      final createdMap = MapData(
        id: 'new-default-map',
        userId: null,
        name: 'Default Map',
        description: 'First map',
        createdAt: DateTime.now(),
        isLocal: true,
      );
      when(() => mockSyncService.createMap(
            name: any(named: 'name'),
            description: any(named: 'description'),
            isAuthenticated: any(named: 'isAuthenticated'),
          )).thenAnswer((_) async => createdMap);

      final container = ProviderContainer(
        overrides: [
          mapSyncServiceProvider.overrideWith((ref) async => mockSyncService),
          sessionProvider.overrideWith((ref) async => null),
          isAuthenticatedProvider.overrideWithValue(false),
        ],
      );

      // Trigger initialization
      container.read(currentMapIdProvider);
      await Future.delayed(const Duration(milliseconds: 500));

      // Should create a default map because savedMapId is null.
      // May be called more than once in test due to mock getAllMaps always
      // returning [] (in real app, createMap updates mapsProvider state).
      verify(() => mockSyncService.createMap(
            name: 'Default Map',
            description: 'First map',
            isAuthenticated: false,
          )).called(greaterThanOrEqualTo(1));

      // currentMapId should be the new map
      expect(container.read(currentMapIdProvider), createdMap.id);

      container.dispose();
    });
  });
}
