import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:memomap/features/auth/providers/auth_provider.dart';
import 'package:memomap/features/map/data/local_pin_storage.dart';
import 'package:memomap/features/map/data/network_checker.dart';
import 'package:memomap/features/map/data/pin_repository.dart';
import 'package:memomap/features/map/providers/current_map_provider.dart';
import 'package:memomap/features/map/providers/map_provider.dart'
    show mapIdMappingProvider, mapsProvider;
import 'package:memomap/features/map/providers/tag_provider.dart'
    show tagIdMappingProvider, tagsProvider;
import 'package:memomap/features/map/services/pin_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:memomap/features/map/data/pin_repository.dart' show PinData;

final localPinStorageProvider = Provider<LocalPinStorageBase>((ref) {
  final prefs = SharedPreferencesAsync();
  return SharedPreferencesLocalPinStorage(prefs);
});

final networkCheckerProvider = Provider<NetworkCheckerBase>((ref) {
  return ConnectivityPlusNetworkChecker();
});

final pinRepositoryProvider = FutureProvider<PinRepository>((ref) async {
  return PinRepository.getInstance();
});

final pinSyncServiceProvider = FutureProvider<PinSyncService>((ref) async {
  final storage = ref.watch(localPinStorageProvider);
  final networkChecker = ref.watch(networkCheckerProvider);
  final repository = await ref.watch(pinRepositoryProvider.future);

  return PinSyncService(
    storage: storage,
    networkChecker: networkChecker,
    repository: repository,
  );
});

final pinsProvider = AsyncNotifierProvider<PinsNotifier, List<PinData>>(() {
  return PinsNotifier();
});

class PinsNotifier extends AsyncNotifier<List<PinData>> {
  Completer<void> _syncCompleter = Completer<void>();

  /// Resolves when this build has finished remapping local IDs and
  /// published its final state. Used by `currentMapProvider`'s
  /// empty-default cleanup to read post-sync pin state instead of the
  /// mid-build cached snapshot that `.future` would return.
  Future<void> get syncDone => _syncCompleter.future;

  String? get _currentMapId => ref.read(currentMapIdProvider);

  List<PinData> _filterByCurrentMap(List<PinData> pins) {
    final mapId = _currentMapId;
    if (mapId == null) {
      return [];
    }
    return pins.where((p) => p.mapId == mapId).toList();
  }

  @override
  Future<List<PinData>> build() async {
    if (_syncCompleter.isCompleted) {
      _syncCompleter = Completer<void>();
    }

    try {
      ref.listen(sessionProvider, (prev, next) {
        final prevUserId = prev?.valueOrNull?.user.id;
        final nextUserId = next.valueOrNull?.user.id;
        if (prevUserId != nextUserId) {
          ref.invalidateSelf();
        }
      });

      ref.listen(currentMapIdProvider, (prev, next) {
        if (prev != next) {
          ref.invalidateSelf();
        }
      });

      final syncService = await ref.watch(pinSyncServiceProvider.future);
      final session = ref.read(sessionProvider).valueOrNull;
      final currentUserId = session?.user.id;

      // Clear before reading to avoid briefly showing previous user's data
      await syncService.clearIfUserChanged(currentUserId);

      // Optimistic display: show cached pins immediately while we wait for
      // dependent providers (maps, tags) to settle.
      final initialPins = await syncService.getAllPins();
      state = AsyncValue.data(_filterByCurrentMap(initialPins));

      if (currentUserId != null) {
        // Wait for map and tag sync to publish their id mappings. We CANNOT
        // use `ref.watch(mapsProvider.future)` — that resolves at the
        // mid-build `state = AsyncData(cached)` publish, before mapping is
        // set, and the subsequent remap runs against an empty map. Reading
        // `.notifier` triggers each notifier's build (its synchronous
        // prefix resets the completer), so `syncDone` returns this
        // session's fresh Future.
        final mapsNotifier = ref.read(mapsProvider.notifier);
        final tagsNotifier = ref.read(tagsProvider.notifier);
        await mapsNotifier.syncDone;
        await tagsNotifier.syncDone;

        final idMapping = ref.read(mapIdMappingProvider);
        if (idMapping.isNotEmpty) {
          await syncService.remapLocalMapIds(idMapping);
        }
        final tagMapping = ref.read(tagIdMappingProvider);
        if (tagMapping.isNotEmpty) {
          await syncService.remapLocalTagIds(tagMapping);
        }
      }

      final filteredPins = await _publishFilteredFromStorage(syncService);

      if (currentUserId != null) {
        _syncInBackground(syncService);
      }

      // React to tag ID mapping updates (tags uploaded in background).
      ref.listen(tagIdMappingProvider, (prev, next) async {
        if (next.isNotEmpty && next != prev) {
          final svc = await ref.read(pinSyncServiceProvider.future);
          await svc.remapLocalTagIds(next);
          await _publishFilteredFromStorage(svc);
        }
      });

      return filteredPins;
    } finally {
      if (!_syncCompleter.isCompleted) _syncCompleter.complete();
    }
  }

  Future<void> _syncInBackground(PinSyncService syncService) async {
    try {
      await syncService.syncWithServer();
      await _publishFilteredFromStorage(syncService);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Background sync failed: $e\n$st');
      }
    }
  }

  /// Reads pins from storage, filters by current map, and publishes to
  /// state — preserving any pins the user added optimistically via
  /// [addPin] / [updatePinTags] while this method was waiting. Storage
  /// doesn't include them until their server round-trip persists them,
  /// so a naive overwrite would flash the pin off the map until the next
  /// refresh. Returns the published list for callers that need it.
  Future<List<PinData>> _publishFilteredFromStorage(
      PinSyncService syncService) async {
    final allPins = await syncService.getAllPins();
    final filteredPins = _filterByCurrentMap(allPins);
    final currentPins = state.value ?? const <PinData>[];
    final freshIds = filteredPins.map((p) => p.id).toSet();
    final preserved =
        currentPins.where((p) => !freshIds.contains(p.id)).toList();
    final merged = [...preserved, ...filteredPins];
    state = AsyncValue.data(merged);
    return merged;
  }

  Future<void> addPin(LatLng position) async {
    final isAuthenticated = ref.read(isAuthenticatedProvider);
    final syncService = await ref.read(pinSyncServiceProvider.future);
    final mapId = _currentMapId;

    final previous = state.value ?? [];
    final optimisticPin = PinData.local(position, mapId: mapId);
    state = AsyncValue.data([optimisticPin, ...previous]);

    try {
      final realPin = await syncService.addPin(
        position: position,
        isAuthenticated: isAuthenticated,
        mapId: mapId,
      );

      state = AsyncValue.data(
        state.value!.map((p) => p.id == optimisticPin.id ? realPin : p).toList(),
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Failed to add pin: $e\n$st');
      }
      state = AsyncValue.data(previous);
    }
  }

  Future<void> deletePin(String id) async {
    final pin = state.value?.where((p) => p.id == id).firstOrNull;
    if (pin == null) return;

    final isAuthenticated = ref.read(isAuthenticatedProvider);
    final syncService = await ref.read(pinSyncServiceProvider.future);

    state = AsyncValue.data(
      (state.value ?? []).where((p) => p.id != id).toList(),
    );

    try {
      await syncService.deletePin(
        pin: pin,
        isAuthenticated: isAuthenticated,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Failed to delete pin: $e\n$st');
      }
    }
  }

  Future<void> updatePinTags(String pinId, List<String> tagIds) async {
    final isAuthenticated = ref.read(isAuthenticatedProvider);
    final syncService = await ref.read(pinSyncServiceProvider.future);

    final previous = state.value ?? [];
    final idx = previous.indexWhere((p) => p.id == pinId);
    if (idx < 0) return;

    final optimistic = [...previous];
    optimistic[idx] = previous[idx].copyWith(tagIds: tagIds);
    state = AsyncValue.data(optimistic);

    try {
      await syncService.updatePinTags(
        pinId: pinId,
        tagIds: tagIds,
        isAuthenticated: isAuthenticated,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Failed to update pin tags: $e\n$st');
      }
      state = AsyncValue.data(previous);
    }
  }

  /// Remove a tag ID from the local state of all pins (used after a tag is deleted).
  void removeTagFromAllPins(String tagId) {
    final current = state.value;
    if (current == null) return;
    final updated = current
        .map((p) => p.tagIds.contains(tagId)
            ? p.copyWith(tagIds: p.tagIds.where((id) => id != tagId).toList())
            : p)
        .toList();
    state = AsyncValue.data(updated);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}
