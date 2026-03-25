import 'package:flutter/foundation.dart';
import 'package:memomap/features/map/data/local_map_storage.dart';
import 'package:memomap/features/map/data/map_repository.dart';
import 'package:memomap/features/map/data/network_checker.dart';

class MapSyncService {
  final LocalMapStorageBase storage;
  final NetworkCheckerBase networkChecker;
  final MapRepositoryBase repository;

  MapSyncService({
    required this.storage,
    required this.networkChecker,
    required this.repository,
  });

  Future<void> clearIfUserChanged(String? currentUserId) async {
    final lastUserId = await storage.getLastUserId();

    if (kDebugMode) {
      debugPrint('[MapSync] clearIfUserChanged: lastUserId=$lastUserId, currentUserId=$currentUserId');
    }

    if (lastUserId != null && lastUserId != currentUserId) {
      if (kDebugMode) {
        debugPrint('[MapSync] User changed, clearing all data');
      }
      await storage.clearAll();
    }

    await storage.setLastUserId(currentUserId);
  }

  Future<List<MapData>> getAllMaps() async {
    final cachedMaps = await storage.getCachedMaps();
    final localMaps = await storage.getLocalMaps();

    return [...cachedMaps, ...localMaps];
  }

  Future<MapData> createMap({
    required String name,
    String? description,
    required bool isAuthenticated,
  }) async {
    final isOnline = await networkChecker.isOnline;

    if (isAuthenticated && isOnline) {
      final serverMap = await repository.createMap(
        name: name,
        description: description,
      );
      if (serverMap != null) {
        final cachedMaps = await storage.getCachedMaps();
        await storage.setCachedMaps([serverMap, ...cachedMaps]);
        return serverMap;
      }
    }

    final localMap = MapData.local(name: name, description: description);
    final localMaps = await storage.getLocalMaps();
    await storage.setLocalMaps([localMap, ...localMaps]);
    return localMap;
  }

  Future<MapData?> updateMap({
    required MapData map,
    String? name,
    String? description,
    required bool isAuthenticated,
  }) async {
    final isOnline = await networkChecker.isOnline;

    if (isAuthenticated && isOnline && !map.isLocal) {
      final serverMap = await repository.updateMap(
        map.id,
        name: name,
        description: description,
      );
      if (serverMap != null) {
        final cachedMaps = await storage.getCachedMaps();
        final updatedCachedMaps = cachedMaps
            .map((m) => m.id == serverMap.id ? serverMap : m)
            .toList();
        await storage.setCachedMaps(updatedCachedMaps);
        return serverMap;
      }
    }

    if (map.isLocal) {
      final localMaps = await storage.getLocalMaps();
      final updatedMap = map.copyWith(
        name: name ?? map.name,
        description: description ?? map.description,
      );
      final updatedLocalMaps = localMaps
          .map((m) => m.id == map.id ? updatedMap : m)
          .toList();
      await storage.setLocalMaps(updatedLocalMaps);
      return updatedMap;
    }

    return null;
  }

  Future<void> deleteMap({
    required MapData map,
    required bool isAuthenticated,
  }) async {
    if (map.isLocal) {
      final localMaps = await storage.getLocalMaps();
      await storage.setLocalMaps(
        localMaps.where((m) => m.id != map.id).toList(),
      );
      return;
    }

    final isOnline = await networkChecker.isOnline;

    if (isAuthenticated && isOnline) {
      await repository.deleteMap(map.id);
    } else {
      await _addToPendingDeletions(map.id);
    }

    final cachedMaps = await storage.getCachedMaps();
    await storage.setCachedMaps(
      cachedMaps.where((m) => m.id != map.id).toList(),
    );
  }

  Future<void> _addToPendingDeletions(String mapId) async {
    final pendingDeletions = await storage.getPendingDeletions();
    await storage.setPendingDeletions([...pendingDeletions, mapId]);
  }

  /// Syncs with server. Returns a mapping of old local map IDs to new server IDs.
  Future<Map<String, String>> syncWithServer() async {
    final isOnline = await networkChecker.isOnline;
    if (!isOnline) return {};

    await _processPendingDeletions();

    final localMaps = await storage.getLocalMaps();
    var idMapping = <String, String>{};

    if (localMaps.isNotEmpty) {
      idMapping = await repository.uploadLocalMaps(localMaps);
      if (idMapping.isNotEmpty) {
        await storage.setLocalMaps([]);
      }
    }

    final serverMaps = await repository.getMaps();
    await storage.setCachedMaps(serverMaps);

    return idMapping;
  }

  Future<void> _processPendingDeletions() async {
    final pendingDeletions = await storage.getPendingDeletions();
    if (pendingDeletions.isEmpty) return;

    final failedDeletions = <String>[];

    for (final mapId in pendingDeletions) {
      try {
        await repository.deleteMap(mapId);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Failed to delete map $mapId: $e');
        }
        failedDeletions.add(mapId);
      }
    }

    await storage.setPendingDeletions(failedDeletions);
  }

  Future<String?> getCurrentMapId() async {
    final mapId = await storage.getCurrentMapId();
    if (kDebugMode) {
      debugPrint('[MapSync] getCurrentMapId: $mapId');
    }
    return mapId;
  }

  Future<void> setCurrentMapId(String? mapId) async {
    if (kDebugMode) {
      debugPrint('[MapSync] setCurrentMapId: $mapId');
    }
    await storage.setCurrentMapId(mapId);
  }
}
