import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:memomap/features/auth/data/auth_models.dart';
import 'package:memomap/features/auth/providers/auth_provider.dart';
import 'package:memomap/features/map/data/map_repository.dart';
import 'package:memomap/features/map/data/pin_repository.dart';
import 'package:memomap/features/map/data/tag_repository.dart';
import 'package:memomap/features/map/providers/current_map_provider.dart';
import 'package:memomap/features/map/providers/map_provider.dart';
import 'package:memomap/features/map/providers/pin_provider.dart';
import 'package:memomap/features/map/providers/tag_provider.dart';
import 'package:memomap/features/map/services/map_sync_service.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

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

/// Pre-synced maps stub: emits a single server map and publishes a
/// {local→server} map id mapping during build. Overrides `syncDone` with
/// its own Completer so consumers observe completion after the mapping
/// publish rather than after the parent class's uninitialized completer.
class _StubMapsNotifier extends MapsNotifier {
  static const localMapId = 'local-map-uuid';
  static const serverMapId = 'server-map-uuid';

  final _done = Completer<void>();

  @override
  Future<void> get syncDone => _done.future;

  @override
  Future<List<MapData>> build() async {
    // Defer state mutation past the synchronous initialization phase —
    // Riverpod forbids modifying other providers during build init.
    await Future<void>.delayed(Duration.zero);
    ref.read(mapIdMappingProvider.notifier).state = {
      localMapId: serverMapId,
    };
    _done.complete();
    return [
      MapData(
        id: serverMapId,
        userId: 'user-1',
        name: 'M',
        description: null,
        createdAt: DateTime.utc(2024, 1, 1),
      ),
    ];
  }
}

/// Pre-synced tags stub: publishes a {local→server} tag id mapping during
/// build, returning an empty visible list (server fetch result).
class _StubTagsNotifier extends TagsNotifier {
  static const localTagId = 'local-tag-uuid';
  static const serverTagId = 'server-tag-uuid';

  final _done = Completer<void>();

  @override
  Future<void> get syncDone => _done.future;

  @override
  Future<List<TagData>> build() async {
    await Future<void>.delayed(Duration.zero);
    ref.read(tagIdMappingProvider.notifier).state = {
      localTagId: serverTagId,
    };
    _done.complete();
    return const [];
  }
}

/// MapsNotifier whose build awaits an external Completer — lets the test
/// hold pinsProvider's `await mapsProvider.notifier.syncDone` and assert
/// that the optimistic mid-build state set is visible to consumers. The
/// stub aliases `syncDone` to the same gate so releasing the gate both
/// unblocks build and signals pinsProvider.
class _GatedMapsNotifier extends MapsNotifier {
  _GatedMapsNotifier(this._gate, this._mapId);

  final Completer<void> _gate;
  final String _mapId;

  @override
  Future<void> get syncDone => _gate.future;

  @override
  Future<List<MapData>> build() async {
    await _gate.future;
    return [
      MapData(
        id: _mapId,
        userId: 'user-1',
        name: 'M',
        description: null,
        createdAt: DateTime.utc(2024, 1, 1),
      ),
    ];
  }
}

class _GatedTagsNotifier extends TagsNotifier {
  _GatedTagsNotifier(this._gate);

  final Completer<void> _gate;

  @override
  Future<void> get syncDone => _gate.future;

  @override
  Future<List<TagData>> build() async {
    await _gate.future;
    return const [];
  }
}

/// Maps stub that mimics production timing precisely:
///   1. Immediately publish an "optimistic" cached state (fires `.future`).
///   2. Await an external gate (simulates the slow `syncWithServer` call).
///   3. Publish the id mapping AFTER the gate is released.
///   4. Signal `syncDone` and return the fresh state.
///
/// This is the ONLY stub that distinguishes `.future` from `syncDone`. If
/// pinsProvider ever regresses to awaiting `mapsProvider.future`, it will
/// unblock at step 1, read an empty mapping in step 2, skip remap, and the
/// regression test asserting `remapLocalMapIds(mapping)` was called will
/// fail.
class _OptimisticThenSyncMapsNotifier extends MapsNotifier {
  _OptimisticThenSyncMapsNotifier({
    required this.syncGate,
    required this.mapId,
    required this.mapping,
  });

  final Completer<void> syncGate;
  final String mapId;
  final Map<String, String> mapping;

  final _done = Completer<void>();

  @override
  Future<void> get syncDone => _done.future;

  MapData _map(String id, String name) => MapData(
        id: id,
        userId: 'user-1',
        name: name,
        description: null,
        createdAt: DateTime.utc(2024, 1, 1),
      );

  @override
  Future<List<MapData>> build() async {
    // Step 1: optimistic mid-build publish. This resolves `.future`.
    state = AsyncValue.data([_map(mapId, 'cached')]);

    // Step 2: yield so `.future` awaiters would proceed here if they
    // used `.future`.
    await syncGate.future;

    // Step 3: publish mapping AFTER the wait.
    ref.read(mapIdMappingProvider.notifier).state = mapping;
    _done.complete();

    return [_map(mapId, 'fresh')];
  }
}

class _OptimisticThenSyncTagsNotifier extends TagsNotifier {
  _OptimisticThenSyncTagsNotifier({
    required this.syncGate,
    required this.mapping,
  });

  final Completer<void> syncGate;
  final Map<String, String> mapping;

  final _done = Completer<void>();

  @override
  Future<void> get syncDone => _done.future;

  @override
  Future<List<TagData>> build() async {
    state = const AsyncValue.data([]);
    await syncGate.future;
    ref.read(tagIdMappingProvider.notifier).state = mapping;
    _done.complete();
    return const [];
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, String>{});
    registerFallbackValue(<PinData>[]);
    registerFallbackValue(const LatLng(0, 0));
  });

  test(
      'optimistic UI: pinsProvider shows cached pins while waiting for maps/tags to settle',
      () async {
    // While authed, pinsProvider awaits mapsProvider.future and
    // tagsProvider.future before its final state set so it can remap local
    // ids. The optimistic display (mid-build `state = AsyncData(cached)`)
    // is what keeps the UI populated during that wait — otherwise the
    // user sees a loading spinner every time the app reopens.
    const mapId = 'the-map-id';
    final cachedPin = PinData(
      id: 'cached-pin',
      userId: 'user-1',
      mapId: mapId,
      position: const LatLng(35.0, 139.0),
      createdAt: DateTime.utc(2024, 1, 1),
    );
    final freshPin = PinData(
      id: 'fresh-pin',
      userId: 'user-1',
      mapId: mapId,
      position: const LatLng(35.5, 139.5),
      createdAt: DateTime.utc(2024, 1, 2),
    );

    final mapsGate = Completer<void>();
    final tagsGate = Completer<void>();

    final mockPinSync = MockPinSyncService();
    when(() => mockPinSync.clearIfUserChanged(any()))
        .thenAnswer((_) async {});
    when(() => mockPinSync.remapLocalMapIds(any())).thenAnswer((_) async {});
    when(() => mockPinSync.remapLocalTagIds(any())).thenAnswer((_) async {});
    when(() => mockPinSync.syncWithServer()).thenAnswer((_) async {});

    // 1st call (mid-build, pre-await) → cached. Subsequent calls (after
    // sync) → fresh.
    var getPinsCallCount = 0;
    when(() => mockPinSync.getAllPins()).thenAnswer((_) async {
      getPinsCallCount++;
      return getPinsCallCount == 1 ? [cachedPin] : [freshPin];
    });

    final mockMapSync = MockMapSyncService();
    when(() => mockMapSync.getCurrentMapId(any())).thenAnswer((_) async => mapId);
    when(() => mockMapSync.setCurrentMapId(any(), any()))
        .thenAnswer((_) async {});

    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith((ref) async => _sessionFor('user-1')),
        isAuthenticatedProvider.overrideWithValue(true),
        mapSyncServiceProvider.overrideWith((ref) async => mockMapSync),
        mapsProvider.overrideWith(() => _GatedMapsNotifier(mapsGate, mapId)),
        tagsProvider.overrideWith(() => _GatedTagsNotifier(tagsGate)),
        pinSyncServiceProvider.overrideWith((ref) async => mockPinSync),
      ],
    );
    addTearDown(container.dispose);

    // Settle currentMapIdProvider FIRST. Otherwise pinsProvider's
    // ref.listen(currentMapIdProvider, invalidateSelf) fires mid-build,
    // invalidating the optimistic state set we want to observe.
    container.read(currentMapIdProvider);
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(container.read(currentMapIdProvider), mapId,
        reason: 'currentMapIdProvider should settle to the gated map id');

    container.read(pinsProvider);

    // Pump microtasks so the optimistic mid-build state set propagates.
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    final mid = container.read(pinsProvider).valueOrNull;
    expect(mid, isNotNull,
        reason:
            'cached pins should be visible before maps/tags futures settle');
    expect(mid!.single.id, 'cached-pin');

    // Release the gates so build can continue past the awaits.
    mapsGate.complete();
    tagsGate.complete();

    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    final settled = container.read(pinsProvider).valueOrNull;
    expect(settled, isNotNull);
    // Merge preservation keeps cachedPin in state (production wouldn't
    // drop it either — cached storage isn't wiped by remap), so we
    // assert freshPin arrived rather than checking for a single element.
    expect(settled!.any((p) => p.id == 'fresh-pin'), isTrue,
        reason: 'final state should include post-sync pins');
  });

  test(
      'pinsProvider applies tagIdMapping (remapLocalTagIds) BEFORE running its sync',
      () async {
    final tagMapping = {_StubTagsNotifier.localTagId: _StubTagsNotifier.serverTagId};

    final mockPinSync = MockPinSyncService();
    when(() => mockPinSync.clearIfUserChanged(any()))
        .thenAnswer((_) async {});
    when(() => mockPinSync.getAllPins()).thenAnswer((_) async => const []);
    when(() => mockPinSync.remapLocalMapIds(any())).thenAnswer((_) async {});
    when(() => mockPinSync.remapLocalTagIds(any())).thenAnswer((_) async {});
    when(() => mockPinSync.syncWithServer()).thenAnswer((_) async {});

    // currentMapIdProvider's constructor pulls mapSyncServiceProvider, so
    // satisfy that with a permissive mock so it can settle.
    final mockMapSync = MockMapSyncService();
    when(() => mockMapSync.getCurrentMapId(any())).thenAnswer(
        (_) async => _StubMapsNotifier.serverMapId);
    when(() => mockMapSync.setCurrentMapId(any(), any()))
        .thenAnswer((_) async {});

    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith((ref) async => _sessionFor('user-1')),
        isAuthenticatedProvider.overrideWithValue(true),
        mapSyncServiceProvider.overrideWith((ref) async => mockMapSync),
        // Stub maps & tags so we can deterministically publish their
        // mappings without going through real Notifier builds.
        mapsProvider.overrideWith(() => _StubMapsNotifier()),
        tagsProvider.overrideWith(() => _StubTagsNotifier()),
        pinSyncServiceProvider.overrideWith((ref) async => mockPinSync),
      ],
    );
    addTearDown(container.dispose);

    container.read(pinsProvider);
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    // remapLocalTagIds MUST be called with the tag mapping, AND it must
    // happen BEFORE pin syncWithServer. With the old code, tagsProvider's
    // sync was fire-and-forget so remapLocalTagIds ran (if at all) only
    // via the listener AFTER pin syncWithServer had already uploaded pins
    // and queued pendingTagUpdates with stale local tag ids.
    verifyInOrder([
      () => mockPinSync.remapLocalTagIds(tagMapping),
      () => mockPinSync.syncWithServer(),
    ]);
  });

  test(
      'pinsProvider waits for MAPPING PUBLISH — not for maps/tags .future — before remap',
      () async {
    // Regression guard for the `.future` vs `syncDone` distinction.
    //
    // `mapsProvider.future` and `tagsProvider.future` resolve at the FIRST
    // mid-build `state = AsyncData(cached)` set — BEFORE the sync publishes
    // the id mapping. If pinsProvider awaits `.future`, it reads an empty
    // mapping and skips remap entirely, silently breaking guest→login
    // carry-over. This test uses stubs that reproduce that exact timing;
    // any regression to `.future` will make the `remapLocalMapIds` /
    // `remapLocalTagIds` assertions below fail.
    final mapGate = Completer<void>();
    final tagGate = Completer<void>();
    const mapMapping = {'local-map-id': 'server-map-id'};
    const tagMapping = {'local-tag-id': 'server-tag-id'};

    final mockPinSync = MockPinSyncService();
    when(() => mockPinSync.clearIfUserChanged(any()))
        .thenAnswer((_) async {});
    when(() => mockPinSync.getAllPins()).thenAnswer((_) async => const []);
    when(() => mockPinSync.remapLocalMapIds(any())).thenAnswer((_) async {});
    when(() => mockPinSync.remapLocalTagIds(any())).thenAnswer((_) async {});
    when(() => mockPinSync.syncWithServer()).thenAnswer((_) async {});

    final mockMapSync = MockMapSyncService();
    when(() => mockMapSync.getCurrentMapId(any()))
        .thenAnswer((_) async => 'server-map-id');
    when(() => mockMapSync.setCurrentMapId(any(), any()))
        .thenAnswer((_) async {});

    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith((ref) async => _sessionFor('user-1')),
        isAuthenticatedProvider.overrideWithValue(true),
        mapSyncServiceProvider.overrideWith((ref) async => mockMapSync),
        mapsProvider.overrideWith(
          () => _OptimisticThenSyncMapsNotifier(
            syncGate: mapGate,
            mapId: 'server-map-id',
            mapping: mapMapping,
          ),
        ),
        tagsProvider.overrideWith(
          () => _OptimisticThenSyncTagsNotifier(
            syncGate: tagGate,
            mapping: tagMapping,
          ),
        ),
        pinSyncServiceProvider.overrideWith((ref) async => mockPinSync),
      ],
    );
    addTearDown(container.dispose);

    // Settle currentMapIdProvider FIRST — otherwise pinsProvider's
    // currentMap listener invalidates build mid-run and remap runs
    // multiple times, obscuring the correctness assertion below.
    container.read(currentMapIdProvider);
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    container.read(pinsProvider);

    // Let build reach the wait. If pinsProvider erroneously used
    // `.future`, it would proceed past this point and call remap with
    // empty mappings.
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    // Neither remap should have run yet — mappings haven't been
    // published, and syncDone hasn't fired.
    verifyNever(() => mockPinSync.remapLocalMapIds(any()));
    verifyNever(() => mockPinSync.remapLocalTagIds(any()));

    // Release the gates. Now mappings publish and syncDone fires.
    mapGate.complete();
    tagGate.complete();

    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    // Remap MUST have been called with the correct mappings — not `{}`.
    verify(() => mockPinSync.remapLocalMapIds(mapMapping)).called(1);
    verify(() => mockPinSync.remapLocalTagIds(tagMapping)).called(1);
  });

  test(
      'optimistic addPin during build survives the post-syncDone state overwrite',
      () async {
    // Regression guard for the interaction between pinsProvider's mid-build
    // state overwrite and addPin's optimistic update.
    //
    // Sequence:
    //   t0  build sets state = cached (from local storage)
    //   t1  build blocks on mapsNotifier.syncDone
    //   t2  user taps → addPin sets state = [optimistic, ...cached]
    //   t3  addPin's server POST completes → state = [real, ...cached]
    //   t4  mapsSyncDone fires → build reads getAllPins from storage
    //       (which does NOT include the new pin because our mock addPin
    //       does not persist to storage — same effect as a slow storage
    //       write in production) → publishes filteredPins
    //   t5  build finishes
    //
    // Without merge preservation the t4 publish overwrites [real, cached]
    // with [cached], and the pin disappears until _syncInBackground
    // refreshes from the server. This test asserts the state at t5 still
    // contains the pin.
    const mapId = 'server-map-id';
    final cachedPin = PinData(
      id: 'cached-pin',
      userId: 'user-1',
      mapId: mapId,
      position: const LatLng(35.0, 139.0),
      createdAt: DateTime.utc(2024, 1, 1),
    );
    final realPin = PinData(
      id: 'real-pin-from-server',
      userId: 'user-1',
      mapId: mapId,
      position: const LatLng(35.5, 139.5),
      createdAt: DateTime.utc(2024, 1, 2),
    );

    final mapsGate = Completer<void>();
    final tagsGate = Completer<void>();

    final mockPinSync = MockPinSyncService();
    when(() => mockPinSync.clearIfUserChanged(any()))
        .thenAnswer((_) async {});
    when(() => mockPinSync.remapLocalMapIds(any())).thenAnswer((_) async {});
    when(() => mockPinSync.remapLocalTagIds(any())).thenAnswer((_) async {});
    // Do NOT run syncWithServer (which would refresh cache with realPin);
    // we want to observe the state AFTER build's overwrite but BEFORE any
    // background refresh could paper over the bug.
    when(() => mockPinSync.syncWithServer())
        .thenAnswer((_) => Completer<void>().future);
    // Storage always returns cachedPin only — our mock addPin does not
    // persist. This mirrors the real race: build's getAllPins reads
    // storage BEFORE the server POST has persisted the new pin.
    when(() => mockPinSync.getAllPins()).thenAnswer((_) async => [cachedPin]);
    when(() => mockPinSync.addPin(
          position: any(named: 'position'),
          isAuthenticated: any(named: 'isAuthenticated'),
          mapId: any(named: 'mapId'),
        )).thenAnswer((_) async => realPin);

    final mockMapSync = MockMapSyncService();
    when(() => mockMapSync.getCurrentMapId(any())).thenAnswer((_) async => mapId);
    when(() => mockMapSync.setCurrentMapId(any(), any()))
        .thenAnswer((_) async {});

    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith((ref) async => _sessionFor('user-1')),
        isAuthenticatedProvider.overrideWithValue(true),
        mapSyncServiceProvider.overrideWith((ref) async => mockMapSync),
        mapsProvider.overrideWith(() => _GatedMapsNotifier(mapsGate, mapId)),
        tagsProvider.overrideWith(() => _GatedTagsNotifier(tagsGate)),
        pinSyncServiceProvider.overrideWith((ref) async => mockPinSync),
      ],
    );
    addTearDown(container.dispose);

    // Settle currentMapIdProvider first so its listener doesn't invalidate
    // pinsProvider mid-test.
    container.read(currentMapIdProvider);
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    // Kick off pins.build; it publishes cached and then blocks on gates.
    container.read(pinsProvider);
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    final afterCached = container.read(pinsProvider).valueOrNull;
    expect(afterCached?.single.id, cachedPin.id);

    // User taps to add a pin while build is still blocked.
    await container
        .read(pinsProvider.notifier)
        .addPin(const LatLng(35.5, 139.5));

    final afterAdd = container.read(pinsProvider).valueOrNull;
    expect(afterAdd, isNotNull);
    expect(afterAdd!.any((p) => p.id == realPin.id), isTrue,
        reason: 'realPin should be visible immediately after addPin');

    // Now release the gates. build resumes, reads getAllPins (which
    // does NOT include realPin), and calls _publishFilteredFromStorage.
    // Without merge preservation this would overwrite state to
    // [cachedPin] and drop realPin.
    mapsGate.complete();
    tagsGate.complete();
    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    final settled = container.read(pinsProvider).valueOrNull;
    expect(settled, isNotNull);
    expect(settled!.any((p) => p.id == realPin.id), isTrue,
        reason:
            'realPin must survive build\'s post-syncDone state overwrite');
    expect(settled.any((p) => p.id == cachedPin.id), isTrue,
        reason: 'cachedPin should still be present');
  });
}
