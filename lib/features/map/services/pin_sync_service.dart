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
  }) async {
    if (!isAuthenticated) {
      return _addLocalPin(position);
    }

    final isOnline = await networkChecker.isOnline;
    if (!isOnline) {
      return _addLocalPin(position);
    }

    try {
      final serverPin = await repository.addPin(position);
      if (serverPin != null) {
        final cachedPins = await storage.getCachedPins();
        await storage.setCachedPins([serverPin, ...cachedPins]);
        return serverPin;
      }
      return _addLocalPin(position);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to add pin to server: $e');
      }
      return _addLocalPin(position);
    }
  }

  Future<PinData> _addLocalPin(LatLng position) async {
    final localPin = PinData.local(position);
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

  Future<void> syncWithServer() async {
    final isOnline = await networkChecker.isOnline;
    if (!isOnline) return;

    await _processPendingDeletions();
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
