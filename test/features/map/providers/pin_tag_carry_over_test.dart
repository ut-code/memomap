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
/// {local→server} map id mapping during build.
class _StubMapsNotifier extends MapsNotifier {
  static const localMapId = 'local-map-uuid';
  static const serverMapId = 'server-map-uuid';

  @override
  Future<List<MapData>> build() async {
    // Defer state mutation past the synchronous initialization phase —
    // Riverpod forbids modifying other providers during build init.
    await Future<void>.delayed(Duration.zero);
    ref.read(mapIdMappingProvider.notifier).state = {
      localMapId: serverMapId,
    };
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

  @override
  Future<List<TagData>> build() async {
    await Future<void>.delayed(Duration.zero);
    ref.read(tagIdMappingProvider.notifier).state = {
      localTagId: serverTagId,
    };
    return const [];
  }
}

/// MapsNotifier whose build awaits an external Completer — lets the test
/// hold pinsProvider's `await mapsProvider.future` and assert that the
/// optimistic mid-build state set is visible to consumers.
class _GatedMapsNotifier extends MapsNotifier {
  _GatedMapsNotifier(this._gate, this._mapId);

  final Completer<void> _gate;
  final String _mapId;

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
  Future<List<TagData>> build() async {
    await _gate.future;
    return const [];
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, String>{});
    registerFallbackValue(<PinData>[]);
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
    expect(settled!.single.id, 'fresh-pin',
        reason: 'final state should reflect post-sync pins');
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
}
