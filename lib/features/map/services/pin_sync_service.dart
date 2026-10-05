import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:memomap/features/map/data/local_pin_storage.dart';
import 'package:memomap/features/map/data/network_checker.dart';
import 'package:memomap/features/map/data/pin_repository.dart';
import 'package:memomap/features/map/data/pin_repository_base.dart';

class PinSyncService {
  final LocalPinStorageBase storage;
  final NetworkCheckerBase networkChecker;
  final PinRepositoryBase repository;

  PinSyncService({
    required this.storage,
    required this.networkChecker,
    required this.repository,
  });

  Future<List<PinData>> getAllPins() async {
    final cachedPins = await storage.getCachedPins();
    final localPins = await storage.getLocalPins();
    return [...cachedPins, ...localPins];
  }

  Future<PinData> addPin({
    required LatLng position,
    required bool isAuthenticated,
    String? mapId,
    String? memo,
  }) async {
    if (!isAuthenticated) {
      return _addLocalPin(position, mapId: mapId, memo: memo);
    }

    final isOnline = await networkChecker.isOnline;
    if (!isOnline) {
      return _addLocalPin(position, mapId: mapId, memo: memo);
    }

    try {
      final serverPin =
          await repository.addPin(position, mapId: mapId, memo: memo);
      if (serverPin != null) {
        final cachedPins = await storage.getCachedPins();
        await storage.setCachedPins([serverPin, ...cachedPins]);
        return serverPin;
      }
      return _addLocalPin(position, mapId: mapId, memo: memo);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to add pin to server: $e');
      }
      return _addLocalPin(position, mapId: mapId, memo: memo);
    }
  }

  Future<PinData> _addLocalPin(
    LatLng position, {
    String? mapId,
    String? memo,
  }) async {
    final localPin = PinData.local(position, mapId: mapId, memo: memo);
    final localPins = await storage.getLocalPins();
    await storage.setLocalPins([localPin, ...localPins]);
    return localPin;
  }

  Future<void> deletePin({
    required PinData pin,
    required bool isAuthenticated,
  }) async {
    final pendingUpdates = await storage.getPendingMemoUpdates();
    if (pendingUpdates.containsKey(pin.id)) {
      final newUpdates =
          Map<String, String?>.from(pendingUpdates)..remove(pin.id);
      await storage.setPendingMemoUpdates(newUpdates);
    }

    if (pin.isLocal) {
      final localPins = await storage.getLocalPins();
      await storage.setLocalPins(
        localPins.where((p) => p.id != pin.id).toList(),
      );
      return;
    }

    final isOnline = await networkChecker.isOnline && isAuthenticated;
    if (isOnline) {
      try {
        await repository.deletePin(pin.id);
        await _removeFromCache(pin.id);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Failed to delete pin from server: $e');
        }
        await _addToPendingDeletions(pin.id);
        await _removeFromCache(pin.id);
      }
    } else {
      await _addToPendingDeletions(pin.id);
      await _removeFromCache(pin.id);
    }
  }

  Future<void> _removeFromCache(String pinId) async {
    final cachedPins = await storage.getCachedPins();
    await storage.setCachedPins(
      cachedPins.where((p) => p.id != pinId).toList(),
    );
  }

  Future<void> _addToPendingDeletions(String pinId) async {
    final pendingDeletions = await storage.getPendingDeletions();
    await storage.setPendingDeletions([...pendingDeletions, pinId]);
  }

  Future<void> remapLocalMapIds(Map<String, String> idMapping) async {
    if (idMapping.isEmpty) return;

    final localPins = await storage.getLocalPins();
    final updated = localPins.map((pin) {
      if (pin.mapId != null && idMapping.containsKey(pin.mapId)) {
        return pin.copyWith(mapId: idMapping[pin.mapId]);
      }
      return pin;
    }).toList();
    await storage.setLocalPins(updated);
  }

  Future<void> syncWithServer() async {
    final isOnline = await networkChecker.isOnline;
    if (!isOnline) return;

    await _processPendingDeletions();
    await _processPendingMemoUpdates();
    await _uploadLocalPins();
    await _refreshCacheFromServer();
  }

  Future<void> _processPendingDeletions() async {
    final pendingDeletions = await storage.getPendingDeletions();
    if (pendingDeletions.isEmpty) return;

    final failedDeletions = <String>[];

    for (final pinId in pendingDeletions) {
      try {
        await repository.deletePin(pinId);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Failed to delete pin $pinId: $e');
        }
        failedDeletions.add(pinId);
      }
    }

    await storage.setPendingDeletions(failedDeletions);
  }

  Future<void> _processPendingMemoUpdates() async {
    final pendingUpdates = await storage.getPendingMemoUpdates();
    if (pendingUpdates.isEmpty) return;

    final remainingUpdates = Map<String, String?>.from(pendingUpdates);

    for (final entry in pendingUpdates.entries) {
      final pinId = entry.key;
      final memo = entry.value;
      try {
        await repository.updatePin(pinId, memo: memo);
        remainingUpdates.remove(pinId);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Failed to update memo for pin $pinId: $e');
        }
      }
    }

    await storage.setPendingMemoUpdates(remainingUpdates);
  }

  Future<void> _uploadLocalPins() async {
    final localPins = await storage.getLocalPins();
    if (localPins.isEmpty) return;

    try {
      await repository.uploadLocalPins(localPins);
      await storage.setLocalPins([]);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to upload local pins: $e');
      }
    }
  }

  Future<void> _refreshCacheFromServer() async {
    try {
      final serverPins = await repository.getPins();
      final pendingUpdates = await storage.getPendingMemoUpdates();
      if (pendingUpdates.isEmpty) {
        await storage.setCachedPins(serverPins);
      } else {
        final mergedPins = serverPins.map((pin) {
          if (pendingUpdates.containsKey(pin.id)) {
            return pin.copyWith(memo: pendingUpdates[pin.id]);
          }
          return pin;
        }).toList();
        await storage.setCachedPins(mergedPins);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to refresh cache from server: $e');
      }
    }
  }

  /// Update memo for a pin. If the pin is local, updates local storage.
  /// If the pin is a server pin and the user is authenticated and online,
  /// updates the server and cached storage. If offline or the server call fails,
  /// updates cached storage and queues the update to be sent to the server later.
  Future<void> updatePinMemo({
    required String pinId,
    required String? memo,
    required bool isAuthenticated,
  }) async {
    final localPins = await storage.getLocalPins();
    final localIndex = localPins.indexWhere((p) => p.id == pinId);
    if (localIndex != -1) {
      final updatedLocal = List<PinData>.from(localPins);
      updatedLocal[localIndex] = updatedLocal[localIndex].copyWith(memo: memo);
      await storage.setLocalPins(updatedLocal);
      return;
    }

    final isOnline = await networkChecker.isOnline;
    if (isAuthenticated && isOnline) {
      try {
        final serverPin = await repository.updatePin(pinId, memo: memo);
        final cachedPins = await storage.getCachedPins();
        final cachedIndex = cachedPins.indexWhere((p) => p.id == pinId);
        if (cachedIndex != -1) {
          final updatedCached = List<PinData>.from(cachedPins);
          updatedCached[cachedIndex] =
              serverPin ?? updatedCached[cachedIndex].copyWith(memo: memo);
          await storage.setCachedPins(updatedCached);
        }
        final pendingUpdates = await storage.getPendingMemoUpdates();
        if (pendingUpdates.containsKey(pinId)) {
          final newUpdates =
              Map<String, String?>.from(pendingUpdates)..remove(pinId);
          await storage.setPendingMemoUpdates(newUpdates);
        }
        return;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Failed to update pin memo on server: $e');
        }
      }
    }

    final cachedPins = await storage.getCachedPins();
    final cachedIndex = cachedPins.indexWhere((p) => p.id == pinId);
    if (cachedIndex != -1) {
      final updatedCached = List<PinData>.from(cachedPins);
      updatedCached[cachedIndex] =
          updatedCached[cachedIndex].copyWith(memo: memo);
      await storage.setCachedPins(updatedCached);
    }
    final pendingUpdates = await storage.getPendingMemoUpdates();
    final newUpdates = Map<String, String?>.from(pendingUpdates)..[pinId] = memo;
    await storage.setPendingMemoUpdates(newUpdates);
  }

  Future<void> clearIfUserChanged(String? currentUserId) async {
    final lastUserId = await storage.getLastUserId();

    if (lastUserId != null && lastUserId != currentUserId) {
      await storage.clearAll();
    }

    await storage.setLastUserId(currentUserId);
  }
}
