import 'package:flutter/foundation.dart';
import 'package:memomap/features/map/data/drawing_repository.dart';
import 'package:memomap/features/map/data/drawing_repository_base.dart';
import 'package:memomap/features/map/data/local_drawing_storage.dart';
import 'package:memomap/features/map/data/network_checker.dart';
import 'package:memomap/features/map/models/drawing_path.dart';

class DrawingSyncService {
  final LocalDrawingStorageBase storage;
  final NetworkCheckerBase networkChecker;
  final DrawingRepositoryBase repository;

  DrawingSyncService({
    required this.storage,
    required this.networkChecker,
    required this.repository,
  });

  Future<List<DrawingData>> getAllDrawings() async {
    final cachedDrawings = await storage.getCachedDrawings();
    final localDrawings = await storage.getLocalDrawings();
    return [...cachedDrawings, ...localDrawings];
  }

  Future<DrawingData> addDrawing({
    required DrawingPath path,
    required bool isAuthenticated,
  }) async {
    if (!isAuthenticated) {
      return _addLocalDrawing(path);
    }

    final isOnline = await networkChecker.isOnline;
    if (!isOnline) {
      return _addLocalDrawing(path);
    }

    try {
      final serverDrawing = await repository.addDrawing(path);
      if (serverDrawing != null) {
        final cachedDrawings = await storage.getCachedDrawings();
        await storage.setCachedDrawings([serverDrawing, ...cachedDrawings]);
        return serverDrawing;
      }
      return _addLocalDrawing(path);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to add drawing to server: $e');
      }
      return _addLocalDrawing(path);
    }
  }

  Future<DrawingData> _addLocalDrawing(DrawingPath path) async {
    final localDrawing = DrawingData.local(path);
    final localDrawings = await storage.getLocalDrawings();
    await storage.setLocalDrawings([localDrawing, ...localDrawings]);
    return localDrawing;
  }

  Future<void> deleteDrawing({
    required DrawingData drawing,
    required bool isAuthenticated,
  }) async {
    if (drawing.isLocal) {
      final localDrawings = await storage.getLocalDrawings();
      await storage.setLocalDrawings(
        localDrawings.where((d) => d.id != drawing.id).toList(),
      );
      return;
    }

    final isOnline = await networkChecker.isOnline && isAuthenticated;
    if (isOnline) {
      try {
        await repository.deleteDrawing(drawing.id);
        await _removeFromCache(drawing.id);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Failed to delete drawing from server: $e');
        }
        await _addToPendingDeletions(drawing.id);
        await _removeFromCache(drawing.id);
      }
    } else {
      await _addToPendingDeletions(drawing.id);
      await _removeFromCache(drawing.id);
    }
  }

  Future<void> _removeFromCache(String drawingId) async {
    final cachedDrawings = await storage.getCachedDrawings();
    await storage.setCachedDrawings(
      cachedDrawings.where((d) => d.id != drawingId).toList(),
    );
  }

  Future<void> _addToPendingDeletions(String drawingId) async {
    final pendingDeletions = await storage.getPendingDeletions();
    await storage.setPendingDeletions([...pendingDeletions, drawingId]);
  }

  /// Replaces old drawings with new drawings/paths, handling deletions and additions.
  ///
  /// When [newDrawings] is provided, uses ID-based comparison (for undo/redo).
  /// When [newPaths] is provided, uses object identity (for eraser).
  Future<List<DrawingData>> replaceDrawings({
    required List<DrawingData> oldDrawings,
    List<DrawingPath>? newPaths,
    List<DrawingData>? newDrawings,
    required bool isAuthenticated,
  }) async {
    assert(newPaths != null || newDrawings != null);

    final result = <DrawingData>[];
    final processedOldIds = <String>{};

    if (newDrawings != null) {
      final oldById = {for (final d in oldDrawings) d.id: d};

      for (final newDrawing in newDrawings) {
        if (oldById.containsKey(newDrawing.id)) {
          result.add(oldById[newDrawing.id]!);
          processedOldIds.add(newDrawing.id);
        } else {
          final added = await addDrawing(
            path: newDrawing.path,
            isAuthenticated: isAuthenticated,
          );
          result.add(added);
        }
      }
    } else {
      for (final newPath in newPaths!) {
        DrawingData? existingData;
        for (final old in oldDrawings) {
          if (identical(old.path, newPath)) {
            existingData = old;
            break;
          }
        }

        if (existingData != null) {
          result.add(existingData);
          processedOldIds.add(existingData.id);
        } else {
          final newDrawing = await addDrawing(
            path: newPath,
            isAuthenticated: isAuthenticated,
          );
          result.add(newDrawing);
        }
      }
    }

    for (final oldDrawing in oldDrawings) {
      if (!processedOldIds.contains(oldDrawing.id)) {
        await deleteDrawing(
          drawing: oldDrawing,
          isAuthenticated: isAuthenticated,
        );
      }
    }

    return result;
  }

  Future<void> syncWithServer() async {
    final isOnline = await networkChecker.isOnline;
    if (!isOnline) return;

    await _processPendingDeletions();
    await _uploadLocalDrawings();
    await _refreshCacheFromServer();
  }

  Future<void> _processPendingDeletions() async {
    final pendingDeletions = await storage.getPendingDeletions();
    if (pendingDeletions.isEmpty) return;

    final failedDeletions = <String>[];

    for (final drawingId in pendingDeletions) {
      try {
        await repository.deleteDrawing(drawingId);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Failed to delete drawing $drawingId: $e');
        }
        failedDeletions.add(drawingId);
      }
    }

    await storage.setPendingDeletions(failedDeletions);
  }

  Future<void> _uploadLocalDrawings() async {
    final localDrawings = await storage.getLocalDrawings();
    if (localDrawings.isEmpty) return;

    try {
      await repository.uploadLocalDrawings(localDrawings);
      await storage.setLocalDrawings([]);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to upload local drawings: $e');
      }
    }
  }

  Future<void> _refreshCacheFromServer() async {
    try {
      final serverDrawings = await repository.getDrawings();
      await storage.setCachedDrawings(serverDrawings);
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
