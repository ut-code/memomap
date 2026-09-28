import 'package:flutter/foundation.dart';
import 'package:memomap/features/map/data/local_tag_storage.dart';
import 'package:memomap/features/map/data/network_checker.dart';
import 'package:memomap/features/map/data/tag_repository.dart';

class TagSyncService {
  final LocalTagStorageBase storage;
  final NetworkCheckerBase networkChecker;
  final TagRepositoryBase repository;

  TagSyncService({
    required this.storage,
    required this.networkChecker,
    required this.repository,
  });

  Future<void> clearIfUserChanged(String? currentUserId) async {
    final lastUserId = await storage.getLastUserId();
    if (lastUserId != null && lastUserId != currentUserId) {
      await storage.clearAll();
    }
    await storage.setLastUserId(currentUserId);
  }

  Future<List<TagData>> getAllTags([String? mapId]) async {
    final cached = await storage.getCachedTags();
    final local = await storage.getLocalTags();
    if (mapId == null) return [...cached, ...local];
    return [
      ...cached.where((tag) => tag.mapId == mapId),
      ...local.where((tag) => tag.mapId == mapId),
    ];
  }

  Future<TagData> createTag({
    String? mapId,
    required String name,
    required int color,
    required bool isAuthenticated,
  }) async {
    final isOnline = await networkChecker.isOnline;

    if (isAuthenticated && isOnline) {
      try {
        final serverTag = mapId == null
            ? await repository.createTag(name: name, color: color)
            : await repository.createTag(
                mapId: mapId,
                name: name,
                color: color,
              );
        if (serverTag != null) {
          final cached = await storage.getCachedTags();
          await storage.setCachedTags([serverTag, ...cached]);
          return serverTag;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Failed to create tag on server: $e');
        }
        rethrow;
      }
    }

    final localTag = TagData.local(mapId: mapId, name: name, color: color);
    final local = await storage.getLocalTags();
    await storage.setLocalTags([localTag, ...local]);
    return localTag;
  }

  Future<TagData?> updateTag({
    required TagData tag,
    String? name,
    int? color,
    required bool isAuthenticated,
  }) async {
    final isOnline = await networkChecker.isOnline;

    if (isAuthenticated && isOnline && !tag.isLocal) {
      try {
        final serverTag = await repository.updateTag(
          tag.id,
          name: name,
          color: color,
        );
        if (serverTag != null) {
          final cached = await storage.getCachedTags();
          await storage.setCachedTags(
            cached.map((t) => t.id == serverTag.id ? serverTag : t).toList(),
          );
          return serverTag;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Failed to update tag on server: $e');
        }
        rethrow;
      }
    }

    if (tag.isLocal) {
      final local = await storage.getLocalTags();
      final updated = tag.copyWith(
        name: name ?? tag.name,
        color: color ?? tag.color,
      );
      await storage.setLocalTags(
        local.map((t) => t.id == tag.id ? updated : t).toList(),
      );
      return updated;
    }

    return null;
  }

  Future<void> deleteTag({
    required TagData tag,
    required bool isAuthenticated,
  }) async {
    if (tag.isLocal) {
      final local = await storage.getLocalTags();
      await storage.setLocalTags(local.where((t) => t.id != tag.id).toList());
      return;
    }

    final isOnline = await networkChecker.isOnline;
    if (isAuthenticated && isOnline) {
      try {
        await repository.deleteTag(tag.id);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Failed to delete tag on server: $e');
        }
        await _addToPendingDeletions(tag.id);
      }
    } else {
      await _addToPendingDeletions(tag.id);
    }

    final cached = await storage.getCachedTags();
    await storage.setCachedTags(cached.where((t) => t.id != tag.id).toList());
  }

  Future<void> _addToPendingDeletions(String tagId) async {
    final pending = await storage.getPendingDeletions();
    await storage.setPendingDeletions([...pending, tagId]);
  }

  /// Syncs with server. Returns a mapping of old local tag IDs to new server IDs.
  Future<Map<String, String>> syncWithServer([String? mapId]) async {
    final isOnline = await networkChecker.isOnline;
    if (!isOnline) return {};

    await _processPendingDeletions();

    final allLocalTags = await storage.getLocalTags();
    final localTags = mapId == null
        ? allLocalTags
        : allLocalTags.where((tag) => tag.mapId == mapId).toList();
    var idMapping = <String, String>{};
    if (localTags.isNotEmpty) {
      idMapping = await repository.uploadLocalTags(localTags);
      final remaining = localTags
          .where((t) => !idMapping.containsKey(t.id))
          .toList();
      if (remaining.length != localTags.length) {
        final uploadedIds = idMapping.keys.toSet();
        await storage.setLocalTags(
          allLocalTags.where((tag) => !uploadedIds.contains(tag.id)).toList(),
        );
      }
    }

    try {
      final serverTags = mapId == null
          ? await repository.getTags()
          : await repository.getTags(mapId: mapId);
      if (mapId == null) {
        await storage.setCachedTags(serverTags);
      } else {
        final cached = await storage.getCachedTags();
        final kept = cached.where((tag) => tag.mapId != mapId).toList();
        await storage.setCachedTags([...serverTags, ...kept]);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to refresh tags from server: $e');
      }
    }

    return idMapping;
  }

  Future<void> _processPendingDeletions() async {
    final pending = await storage.getPendingDeletions();
    if (pending.isEmpty) return;

    final failed = <String>[];
    for (final id in pending) {
      try {
        await repository.deleteTag(id);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Failed to delete tag $id: $e');
        }
        failed.add(id);
      }
    }
    await storage.setPendingDeletions(failed);
  }
}
