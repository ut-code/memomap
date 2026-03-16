import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memomap/features/auth/providers/auth_provider.dart';
import 'package:memomap/features/map/data/local_map_storage.dart';
import 'package:memomap/features/map/data/map_repository.dart';
import 'package:memomap/features/map/providers/current_map_provider.dart';
import 'package:memomap/features/map/providers/pin_provider.dart';
import 'package:memomap/features/map/services/map_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:memomap/features/map/data/map_repository.dart' show MapData;

final localMapStorageProvider = Provider<LocalMapStorageBase>((ref) {
  final prefs = SharedPreferencesAsync();
  return SharedPreferencesLocalMapStorage(prefs);
});

final mapRepositoryProvider = FutureProvider<MapRepository>((ref) async {
  return MapRepository.getInstance();
});

final mapSyncServiceProvider = FutureProvider<MapSyncService>((ref) async {
  final storage = ref.watch(localMapStorageProvider);
  final networkChecker = ref.watch(networkCheckerProvider);
  final repository = await ref.watch(mapRepositoryProvider.future);

  return MapSyncService(
    storage: storage,
    networkChecker: networkChecker,
    repository: repository,
  );
});

/// Holds the local→server map ID mapping from the last sync.
/// Used by pin/drawing/currentMap providers to remap IDs after local maps are uploaded.
final mapIdMappingProvider = StateProvider<Map<String, String>>((ref) => {});

final mapsProvider = AsyncNotifierProvider<MapsNotifier, List<MapData>>(() {
  return MapsNotifier();
});

class MapsNotifier extends AsyncNotifier<List<MapData>> {
  @override
  Future<List<MapData>> build() async {
    final syncService = await ref.watch(mapSyncServiceProvider.future);

    // ref.watch triggers rebuild when session changes.
    // Do NOT use ref.listen + invalidateSelf together with ref.watch
    // on the same provider — it causes concurrent builds and double uploads.
    final session = await ref.watch(sessionProvider.future);
    final currentUserId = session?.user.id;
    final isAuthenticated = ref.read(isAuthenticatedProvider);

    // Clear before reading to avoid briefly showing previous user's data
    await syncService.clearIfUserChanged(currentUserId);

    final cachedMaps = await syncService.getAllMaps();
    state = AsyncValue.data(cachedMaps);

    if (isAuthenticated) {
      final idMapping = await syncService.syncWithServer();

      if (idMapping.isNotEmpty) {
        ref.read(mapIdMappingProvider.notifier).state = idMapping;
      }

      final freshMaps = await syncService.getAllMaps();
      state = AsyncValue.data(freshMaps);
      return freshMaps;
    }

    return cachedMaps;
  }

  Future<MapData?> createMap({required String name, String? description}) async {
    final isAuthenticated = ref.read(isAuthenticatedProvider);
    final syncService = await ref.read(mapSyncServiceProvider.future);

    try {
      final newMap = await syncService.createMap(
        name: name,
        description: description,
        isAuthenticated: isAuthenticated,
      );

      state = AsyncValue.data([newMap, ...(state.value ?? [])]);
      return newMap;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Failed to create map: $e\n$st');
      }
      return null;
    }
  }

  Future<void> updateMap(MapData map, {String? name, String? description}) async {
    final isAuthenticated = ref.read(isAuthenticatedProvider);
    final syncService = await ref.read(mapSyncServiceProvider.future);

    try {
      final updatedMap = await syncService.updateMap(
        map: map,
        name: name,
        description: description,
        isAuthenticated: isAuthenticated,
      );

      if (updatedMap != null) {
        state = AsyncValue.data(
          (state.value ?? []).map((m) => m.id == updatedMap.id ? updatedMap : m).toList(),
        );
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Failed to update map: $e\n$st');
      }
    }
  }

  Future<void> deleteMap(MapData map) async {
    final isAuthenticated = ref.read(isAuthenticatedProvider);
    final syncService = await ref.read(mapSyncServiceProvider.future);

    state = AsyncValue.data(
      (state.value ?? []).where((m) => m.id != map.id).toList(),
    );

    try {
      await syncService.deleteMap(
        map: map,
        isAuthenticated: isAuthenticated,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Failed to delete map: $e\n$st');
      }
    }

    await ref.read(currentMapIdProvider.notifier).ensureValidMapSelected();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}
