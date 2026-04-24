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
  }) async {
    if (!isAuthenticated) {
      return _addLocalPin(position, mapId: mapId);
    }

    final isOnline = await networkChecker.isOnline;
    if (!isOnline) {
      return _addLocalPin(position, mapId: mapId);
    }

    try {
      final serverPin = await repository.addPin(position, mapId: mapId);
      if (serverPin != null) {
        final cachedPins = await storage.getCachedPins();
        await storage.setCachedPins([serverPin, ...cachedPins]);
        return serverPin;
      }
      return _addLocalPin(position, mapId: mapId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to add pin to server: $e');
      }
      return _addLocalPin(position, mapId: mapId);
    }
  }

  Future<PinData> _addLocalPin(LatLng position, {String? mapId}) async {
    final localPin = PinData.local(position, mapId: mapId);
    final localPins = await storage.getLocalPins();
    await storage.setLocalPins([localPin, ...localPins]);
    return localPin;
  }

  Future<void> deletePin({
    required PinData pin,
    required bool isAuthenticated,
  }) async {
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

  Future<PinData?> updatePinTags({
    required String pinId,
    required List<String> tagIds,
    required bool isAuthenticated,
  }) async {
    // Local (not-yet-uploaded) pin: update in local storage only.
    final localPins = await storage.getLocalPins();
    final localIdx = localPins.indexWhere((p) => p.id == pinId);
    if (localIdx >= 0) {
      final updated = localPins[localIdx].copyWith(tagIds: tagIds);
      final newList = [...localPins];
      newList[localIdx] = updated;
      await storage.setLocalPins(newList);
      return updated;
    }

    // Optimistic cache update.
    final cached = await storage.getCachedPins();
    final cacheIdx = cached.indexWhere((p) => p.id == pinId);
    PinData? optimistic;
    if (cacheIdx >= 0) {
      optimistic = cached[cacheIdx].copyWith(tagIds: tagIds);
      final newCache = [...cached];
      newCache[cacheIdx] = optimistic;
      await storage.setCachedPins(newCache);
    }

    final isOnline = await networkChecker.isOnline && isAuthenticated;
    if (!isOnline) {
      await _queuePendingTagUpdate(pinId, tagIds);
      return optimistic;
    }

    try {
      final updated = await repository.updatePinTags(pinId, tagIds);
      if (updated != null) {
        final refreshed = await storage.getCachedPins();
        final idx = refreshed.indexWhere((p) => p.id == pinId);
        if (idx >= 0) {
          final newCache = [...refreshed];
          newCache[idx] = updated;
          await storage.setCachedPins(newCache);
        }
        return updated;
      }
      return optimistic;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to update pin tags on server: $e');
      }
      await _queuePendingTagUpdate(pinId, tagIds);
      return optimistic;
    }
  }

  Future<void> _queuePendingTagUpdate(String pinId, List<String> tagIds) async {
    final pending = await storage.getPendingTagUpdates();
    pending[pinId] = tagIds;
    await storage.setPendingTagUpdates(pending);
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

  /// Remaps local tag IDs referenced in local pins and cached pins to new server tag IDs.
  Future<void> remapLocalTagIds(Map<String, String> tagIdMapping) async {
    if (tagIdMapping.isEmpty) return;

    List<String> remap(List<String> ids) =>
        ids.map((id) => tagIdMapping[id] ?? id).toList();

    final localPins = await storage.getLocalPins();
    await storage.setLocalPins(
      localPins.map((p) => p.copyWith(tagIds: remap(p.tagIds))).toList(),
    );

    final cached = await storage.getCachedPins();
    await storage.setCachedPins(
      cached.map((p) => p.copyWith(tagIds: remap(p.tagIds))).toList(),
    );

    // Remap pending tag updates as well.
    final pending = await storage.getPendingTagUpdates();
    if (pending.isNotEmpty) {
      final newPending = <String, List<String>>{};
      pending.forEach((pinId, ids) {
        newPending[pinId] = remap(ids);
      });
      await storage.setPendingTagUpdates(newPending);
    }
  }

  Future<void> syncWithServer() async {
    final isOnline = await networkChecker.isOnline;
    if (!isOnline) return;

    await _processPendingDeletions();
    await _uploadLocalPins();
    await _processPendingTagUpdates();
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

  Future<void> _uploadLocalPins() async {
    final localPins = await storage.getLocalPins();
    if (localPins.isEmpty) return;

    try {
      final uploaded = await repository.uploadLocalPins(localPins);

      // For local pins that had tagIds, queue them as pending updates
      // since the batch endpoint doesn't accept tag associations.
      if (uploaded.length == localPins.length) {
        final pending = await storage.getPendingTagUpdates();
        for (var i = 0; i < localPins.length; i++) {
          final localPin = localPins[i];
          if (localPin.tagIds.isNotEmpty) {
            pending[uploaded[i].id] = localPin.tagIds;
          }
        }
        if (pending.isNotEmpty) {
          await storage.setPendingTagUpdates(pending);
        }
      }

      await storage.setLocalPins([]);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to upload local pins: $e');
      }
    }
  }

  Future<void> _processPendingTagUpdates() async {
    final pending = await storage.getPendingTagUpdates();
    if (pending.isEmpty) return;

    final remaining = <String, List<String>>{};
    for (final entry in pending.entries) {
      try {
        await repository.updatePinTags(entry.key, entry.value);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Failed to update pin tags ${entry.key}: $e');
        }
        remaining[entry.key] = entry.value;
      }
    }
    await storage.setPendingTagUpdates(remaining);
  }

  Future<void> _refreshCacheFromServer() async {
    try {
      final serverPins = await repository.getPins();
      await storage.setCachedPins(serverPins);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to refresh cache from server: $e');
      }
    }
  }

  Future<void> clearIfUserChanged(String? currentUserId) async {
    final lastUserId = await storage.getLastUserId();

    if (lastUserId != null && lastUserId != currentUserId) {
      await storage.clearAll();
    }

    await storage.setLastUserId(currentUserId);
  }
}
