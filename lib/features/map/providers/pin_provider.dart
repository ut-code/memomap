import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:memomap/features/auth/providers/auth_provider.dart';
import 'package:memomap/features/map/data/local_pin_storage.dart';
import 'package:memomap/features/map/data/network_checker.dart';
import 'package:memomap/features/map/data/pin_repository.dart';
import 'package:memomap/features/map/providers/current_map_provider.dart';
import 'package:memomap/features/map/providers/map_provider.dart' show mapIdMappingProvider;
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

    final allPins = await syncService.getAllPins();
    final filteredPins = _filterByCurrentMap(allPins);
    state = AsyncValue.data(filteredPins);

    if (currentUserId != null) {
      final idMapping = ref.read(mapIdMappingProvider);
      if (idMapping.isNotEmpty) {
        await syncService.remapLocalMapIds(idMapping);
      }
      _syncInBackground(syncService);
    }

    return filteredPins;
  }

  Future<void> _syncInBackground(PinSyncService syncService) async {
    try {
      await syncService.syncWithServer();
      final allPins = await syncService.getAllPins();
      state = AsyncValue.data(_filterByCurrentMap(allPins));
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Background sync failed: $e\n$st');
      }
    }
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

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}
