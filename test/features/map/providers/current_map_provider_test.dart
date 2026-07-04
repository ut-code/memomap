import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:memomap/features/auth/data/auth_models.dart';
import 'package:memomap/features/auth/providers/auth_provider.dart';
import 'package:memomap/features/map/data/map_repository.dart';
import 'package:memomap/features/map/providers/current_map_provider.dart';
import 'package:memomap/features/map/providers/drawing_provider.dart';
import 'package:memomap/features/map/providers/map_provider.dart';
import 'package:memomap/features/map/providers/pin_provider.dart';
import 'package:memomap/features/map/services/map_sync_service.dart';
import 'package:mocktail/mocktail.dart';

class MockMapSyncService extends Mock implements MapSyncService {}

class _StubPinsNotifier extends AsyncNotifier<List<PinData>>
    implements PinsNotifier {
  _StubPinsNotifier(this._initial);

  final List<PinData> _initial;

  @override
  Future<List<PinData>> build() async => _initial;

  // Real PinsNotifier exposes syncDone as a signal that its build's remap
  // has settled. This stub has no sync to do, so resolve immediately.
  @override
  Future<void> get syncDone => Future.value();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubDrawingNotifier extends AsyncNotifier<DrawingState>
    implements DrawingNotifier {
  _StubDrawingNotifier(this._initial);

  final List<DrawingData> _initial;

  @override
  Future<DrawingState> build() async => DrawingState(
        drawingDataList: _initial,
        selectedColor: const Color(0xFFFF0000),
        strokeWidth: 3,
        isDrawingMode: false,
      );

  @override
  Future<void> get syncDone => Future.value();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SessionResponse _sessionFor(String userId) {
  return SessionResponse(
    session: Session(
      id: 'sess-$userId',
      userId: userId,
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    ),
    user: User(
      id: userId,
      email: '$userId@test',
      name: userId,
      emailVerified: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  );
}

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
      when(() => mockSyncService.setCurrentMapId(any(), any()))
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
      when(() => mockSyncService.getCurrentMapId(any()))
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
      verify(() => mockSyncService.getCurrentMapId(any())).called(1);

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
      when(() => mockSyncService.getCurrentMapId(any()))
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
      when(() => mockSyncService.getCurrentMapId(any()))
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
      when(() => mockSyncService.getCurrentMapId(any()))
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

    test(
        'guest → login: keeps guest map id so mapIdMapping can remap it (does NOT create a new default)',
        () async {
      const localGuestId = 'local-guest-uuid';
      const serverUploadedId = 'server-uploaded-uuid';

      // Initial state: guest mode with one local default already selected.
      when(() => mockSyncService.getAllMaps()).thenAnswer((_) async => [
            MapData(
              id: localGuestId,
              userId: null,
              name: 'Default Map',
              description: null,
              createdAt: DateTime.utc(2024, 1, 1),
              isLocal: true,
            ),
          ]);
      when(() => mockSyncService.getCurrentMapId(null))
          .thenAnswer((_) async => localGuestId);
      // New user has no per-user saved map yet.
      when(() => mockSyncService.getCurrentMapId('user-1'))
          .thenAnswer((_) async => null);

      final mockSessionStateProvider =
          StateProvider<SessionResponse?>((ref) => null);

      final container = ProviderContainer(
        overrides: [
          mapSyncServiceProvider.overrideWith((ref) async => mockSyncService),
          sessionProvider.overrideWith((ref) async {
            return ref.watch(mockSessionStateProvider);
          }),
          isAuthenticatedProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);

      // Boot guest session.
      container.read(currentMapIdProvider);
      await Future.delayed(const Duration(milliseconds: 200));
      expect(container.read(currentMapIdProvider), localGuestId);

      // Simulate login: session flips, then maps sync uploads the guest map
      // and publishes an id mapping.
      container.read(mockSessionStateProvider.notifier).state =
          _sessionFor('user-1');
      await Future.delayed(const Duration(milliseconds: 100));

      container.read(mapIdMappingProvider.notifier).state = {
        localGuestId: serverUploadedId,
      };
      await Future.delayed(const Duration(milliseconds: 100));

      // The mapIdMapping listener should have flipped state to the
      // uploaded server id. _createDefaultMap must NOT have been called
      // (otherwise the guest pin's mapId would be orphaned).
      expect(container.read(currentMapIdProvider), serverUploadedId);
      verifyNever(() => mockSyncService.createMap(
            name: any(named: 'name'),
            description: any(named: 'description'),
            isAuthenticated: any(named: 'isAuthenticated'),
          ));
    });

    test(
        'guest → login when user has a saved map id: restores saved map',
        () async {
      const localGuestId = 'local-guest-uuid';
      const savedServerId = 'previously-saved-server-id';

      final guestMap = MapData(
        id: localGuestId,
        userId: null,
        name: 'Default Map',
        description: null,
        createdAt: DateTime.utc(2024, 1, 1),
        isLocal: true,
      );
      final savedServerMap = MapData(
        id: savedServerId,
        userId: 'user-1',
        name: 'My Map',
        description: null,
        createdAt: DateTime.utc(2024, 1, 2),
      );

      when(() => mockSyncService.getAllMaps())
          .thenAnswer((_) async => [guestMap, savedServerMap]);
      when(() => mockSyncService.getCurrentMapId(null))
          .thenAnswer((_) async => localGuestId);
      when(() => mockSyncService.getCurrentMapId('user-1'))
          .thenAnswer((_) async => savedServerId);

      final mockSessionStateProvider =
          StateProvider<SessionResponse?>((ref) => null);

      final container = ProviderContainer(
        overrides: [
          mapSyncServiceProvider.overrideWith((ref) async => mockSyncService),
          sessionProvider.overrideWith((ref) async {
            return ref.watch(mockSessionStateProvider);
          }),
          isAuthenticatedProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);

      container.read(currentMapIdProvider);
      await Future.delayed(const Duration(milliseconds: 200));
      expect(container.read(currentMapIdProvider), localGuestId);

      container.read(mockSessionStateProvider.notifier).state =
          _sessionFor('user-1');
      // Let the session listener fire & resolve before the maps-changed
      // listener kicks in (otherwise it could pick the guest map again).
      await Future.delayed(const Duration(milliseconds: 100));
      // Simulate the post-login maps sync — server maps include the saved one.
      container.read(mapsProvider.notifier).state =
          AsyncValue.data([savedServerMap, guestMap]);
      await Future.delayed(const Duration(milliseconds: 200));

      verify(() => mockSyncService.getCurrentMapId('user-1'))
          .called(greaterThanOrEqualTo(1));
      expect(container.read(currentMapIdProvider), savedServerId);
    });

    test(
        '_listenToMapsChanges remaps via pending mapIdMapping instead of selecting first',
        () async {
      const localGuestId = 'local-guest-uuid';
      const uploadedId = 'uploaded-server-uuid';
      const unrelatedId = 'unrelated-server-uuid';

      when(() => mockSyncService.getAllMaps()).thenAnswer((_) async => []);
      when(() => mockSyncService.getCurrentMapId(any()))
          .thenAnswer((_) async => localGuestId);

      final container = ProviderContainer(
        overrides: [
          mapSyncServiceProvider.overrideWith((ref) async => mockSyncService),
          sessionProvider.overrideWith((ref) async => null),
          isAuthenticatedProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);

      container.read(currentMapIdProvider);
      await Future.delayed(const Duration(milliseconds: 200));
      expect(container.read(currentMapIdProvider), localGuestId);

      // Simulate the race where mapIdMapping is set FIRST, then mapsProvider
      // emits new maps that include the uploaded id (but not the original
      // local id). Without the remap fallback, the listener would pick
      // unrelatedId via _selectFirstMap. With it, it picks uploadedId.
      container.read(mapIdMappingProvider.notifier).state = {
        localGuestId: uploadedId,
      };
      container.read(mapsProvider.notifier).state = AsyncValue.data([
        MapData(
          id: unrelatedId,
          userId: 'user-1',
          name: 'Other',
          description: null,
          createdAt: DateTime.utc(2024, 1, 1),
        ),
        MapData(
          id: uploadedId,
          userId: 'user-1',
          name: 'Default Map',
          description: null,
          createdAt: DateTime.utc(2024, 1, 2),
        ),
      ]);
      await Future.delayed(const Duration(milliseconds: 200));

      expect(container.read(currentMapIdProvider), uploadedId);
    });

    test(
        'cold start with auth session (still loading): does NOT create a guest default map',
        () async {
      // Scenario: app reopened with a valid session cookie. sessionProvider
      // is briefly AsyncLoading before resolving to the user. During that
      // window, _loadCurrentMapId must NOT eagerly create a "Default Map"
      // (otherwise the local default leaks into mapsProvider sync after
      // session settles and gets uploaded — that's the duplication bug).
      const savedServerMapId = 'saved-server-map';
      final sessionCompleter = Completer<SessionResponse?>();

      when(() => mockSyncService.getCurrentMapId(null))
          .thenAnswer((_) async => null);
      when(() => mockSyncService.getCurrentMapId('user-1'))
          .thenAnswer((_) async => savedServerMapId);
      when(() => mockSyncService.getAllMaps()).thenAnswer((_) async => [
            MapData(
              id: savedServerMapId,
              userId: 'user-1',
              name: 'M',
              description: null,
              createdAt: DateTime.utc(2024, 1, 1),
            ),
          ]);

      final container = ProviderContainer(
        overrides: [
          mapSyncServiceProvider.overrideWith((ref) async => mockSyncService),
          sessionProvider.overrideWith((ref) async => sessionCompleter.future),
          // isAuthenticatedProvider is computed from sessionProvider; do
          // not override so it tracks the loading → settled transition.
        ],
      );
      addTearDown(container.dispose);

      // Trigger currentMapIdProvider while session is still loading.
      container.read(currentMapIdProvider);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Resolve session as the logged-in user.
      sessionCompleter.complete(_sessionFor('user-1'));
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(container.read(currentMapIdProvider), savedServerMapId);
      verifyNever(() => mockSyncService.createMap(
            name: any(named: 'name'),
            description: any(named: 'description'),
            isAuthenticated: any(named: 'isAuthenticated'),
          ));
    });

    test('logout (auth → null) reloads guest savedMapId via _loadCurrentMapId',
        () async {
      const userMapId = 'user-saved-map';
      const guestMapId = 'guest-saved-map';

      when(() => mockSyncService.getCurrentMapId('user-1'))
          .thenAnswer((_) async => userMapId);
      when(() => mockSyncService.getCurrentMapId(null))
          .thenAnswer((_) async => guestMapId);
      when(() => mockSyncService.getAllMaps()).thenAnswer((_) async => [
            MapData(
              id: userMapId,
              userId: 'user-1',
              name: 'U',
              description: null,
              createdAt: DateTime.utc(2024, 1, 1),
            ),
            MapData(
              id: guestMapId,
              userId: null,
              name: 'G',
              description: null,
              createdAt: DateTime.utc(2024, 1, 1),
              isLocal: true,
            ),
          ]);

      final sessionStateProvider =
          StateProvider<SessionResponse?>((ref) => _sessionFor('user-1'));

      final container = ProviderContainer(
        overrides: [
          mapSyncServiceProvider.overrideWith((ref) async => mockSyncService),
          sessionProvider.overrideWith(
              (ref) async => ref.watch(sessionStateProvider)),
        ],
      );
      addTearDown(container.dispose);

      container.read(currentMapIdProvider);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(container.read(currentMapIdProvider), userMapId);

      // Logout
      container.read(sessionStateProvider.notifier).state = null;
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(container.read(currentMapIdProvider), guestMapId);
    });

    test('user switch (A → B) drops A\'s map id and loads B\'s', () async {
      const userAMap = 'user-a-map';
      const userBMap = 'user-b-map';

      when(() => mockSyncService.getCurrentMapId('user-a'))
          .thenAnswer((_) async => userAMap);
      when(() => mockSyncService.getCurrentMapId('user-b'))
          .thenAnswer((_) async => userBMap);
      when(() => mockSyncService.getAllMaps()).thenAnswer((_) async => [
            MapData(
              id: userAMap,
              userId: 'user-a',
              name: 'A',
              description: null,
              createdAt: DateTime.utc(2024, 1, 1),
            ),
            MapData(
              id: userBMap,
              userId: 'user-b',
              name: 'B',
              description: null,
              createdAt: DateTime.utc(2024, 1, 1),
            ),
          ]);

      final sessionStateProvider =
          StateProvider<SessionResponse?>((ref) => _sessionFor('user-a'));

      final container = ProviderContainer(
        overrides: [
          mapSyncServiceProvider.overrideWith((ref) async => mockSyncService),
          sessionProvider.overrideWith(
              (ref) async => ref.watch(sessionStateProvider)),
        ],
      );
      addTearDown(container.dispose);

      container.read(currentMapIdProvider);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(container.read(currentMapIdProvider), userAMap);

      container.read(sessionStateProvider.notifier).state =
          _sessionFor('user-b');
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(container.read(currentMapIdProvider), userBMap);
    });

    test(
        'cold start + auth + no per-user saved + server has maps: empty newly-created Default Map gets cleaned up and existing map is selected',
        () async {
      // Approach D: at cold start we eagerly create a Default Map.
      // After mapsProvider syncs, if our just-created Default Map is empty
      // and there's another map, delete the redundant one and switch to it.
      const existingServerMapId = 'existing-server-map';
      const newlyCreatedMapId = 'newly-created-default';

      final existingMap = MapData(
        id: existingServerMapId,
        userId: 'user-1',
        name: 'My Real Map',
        description: null,
        createdAt: DateTime.utc(2024, 1, 1),
      );
      final newlyCreatedMap = MapData(
        id: newlyCreatedMapId,
        userId: 'user-1',
        name: 'Default Map',
        description: 'First map',
        createdAt: DateTime.utc(2024, 1, 2),
      );

      when(() => mockSyncService.getCurrentMapId('user-1'))
          .thenAnswer((_) async => null);
      when(() => mockSyncService.getCurrentMapId(null))
          .thenAnswer((_) async => null);
      // Real syncService.createMap caches the new map in storage, so the
      // next getAllMaps reflects it. We mirror that by flipping the stub
      // once createMap is called.
      var createMapCalled = false;
      when(() => mockSyncService.getAllMaps()).thenAnswer((_) async {
        return createMapCalled
            ? [newlyCreatedMap, existingMap]
            : [existingMap];
      });
      when(() => mockSyncService.createMap(
            name: any(named: 'name'),
            description: any(named: 'description'),
            isAuthenticated: any(named: 'isAuthenticated'),
          )).thenAnswer((_) async {
        createMapCalled = true;
        return newlyCreatedMap;
      });
      when(() => mockSyncService.deleteMap(
            map: any(named: 'map'),
            isAuthenticated: any(named: 'isAuthenticated'),
          )).thenAnswer((_) async {});

      final container = ProviderContainer(
        overrides: [
          mapSyncServiceProvider.overrideWith((ref) async => mockSyncService),
          sessionProvider.overrideWith((ref) async => _sessionFor('user-1')),
          // Both pins and drawings are empty — the just-created Default Map
          // has no content, so cleanup should delete it.
          pinsProvider.overrideWith(() => _StubPinsNotifier(const [])),
          drawingProvider.overrideWith(() => _StubDrawingNotifier(const [])),
        ],
      );
      addTearDown(container.dispose);

      container.read(currentMapIdProvider);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // Cleanup deleted the redundant Default Map.
      verify(() => mockSyncService.deleteMap(
            map: any(
                named: 'map',
                that: predicate<MapData>((m) => m.id == newlyCreatedMapId)),
            isAuthenticated: any(named: 'isAuthenticated'),
          )).called(1);
      // And switched to the existing map.
      expect(container.read(currentMapIdProvider), existingServerMapId);
    });

    test(
        'cold start + auth + no per-user saved + server has maps: non-empty newly-created Default Map is kept (has a pin)',
        () async {
      // Approach D: if our just-created Default Map has any content,
      // keep it — user data must not be lost. The duplicate stays.
      const existingServerMapId = 'existing-server-map';
      const newlyCreatedMapId = 'newly-created-default';

      final existingMap = MapData(
        id: existingServerMapId,
        userId: 'user-1',
        name: 'My Real Map',
        description: null,
        createdAt: DateTime.utc(2024, 1, 1),
      );
      final newlyCreatedMap = MapData(
        id: newlyCreatedMapId,
        userId: 'user-1',
        name: 'Default Map',
        description: 'First map',
        createdAt: DateTime.utc(2024, 1, 2),
      );

      // Simulate a pin already attached to the freshly-created Default Map
      // (e.g., the user had a guest pin that got remapped here).
      final pinOnNewDefault = PinData(
        id: 'pin-on-new-default',
        userId: 'user-1',
        mapId: newlyCreatedMapId,
        position: const LatLng(35.0, 139.0),
        createdAt: DateTime.utc(2024, 1, 2),
      );

      when(() => mockSyncService.getCurrentMapId('user-1'))
          .thenAnswer((_) async => null);
      when(() => mockSyncService.getCurrentMapId(null))
          .thenAnswer((_) async => null);
      var createMapCalled = false;
      when(() => mockSyncService.getAllMaps()).thenAnswer((_) async {
        return createMapCalled
            ? [newlyCreatedMap, existingMap]
            : [existingMap];
      });
      when(() => mockSyncService.createMap(
            name: any(named: 'name'),
            description: any(named: 'description'),
            isAuthenticated: any(named: 'isAuthenticated'),
          )).thenAnswer((_) async {
        createMapCalled = true;
        return newlyCreatedMap;
      });
      when(() => mockSyncService.deleteMap(
            map: any(named: 'map'),
            isAuthenticated: any(named: 'isAuthenticated'),
          )).thenAnswer((_) async {});

      final container = ProviderContainer(
        overrides: [
          mapSyncServiceProvider.overrideWith((ref) async => mockSyncService),
          sessionProvider.overrideWith((ref) async => _sessionFor('user-1')),
          pinsProvider.overrideWith(() => _StubPinsNotifier([pinOnNewDefault])),
          drawingProvider.overrideWith(() => _StubDrawingNotifier(const [])),
        ],
      );
      addTearDown(container.dispose);

      container.read(currentMapIdProvider);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // Cleanup must NOT have run — the map has user data.
      verifyNever(() => mockSyncService.deleteMap(
            map: any(named: 'map'),
            isAuthenticated: any(named: 'isAuthenticated'),
          ));
      // currentMapId stays on the just-created one (don't switch away from
      // the user's content).
      expect(container.read(currentMapIdProvider), newlyCreatedMapId);
    });

    test('should create default map when savedMapId is null (first launch)', () async {
      // savedMapId == null means no map has been created yet
      // So we should create a default map
      when(() => mockSyncService.getAllMaps()).thenAnswer((_) async => []);
      when(() => mockSyncService.getCurrentMapId(any()))
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
