import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memomap/features/auth/providers/auth_provider.dart';
import 'package:memomap/features/map/data/drawing_repository.dart';
import 'package:memomap/features/map/data/local_drawing_storage.dart';
import 'package:memomap/features/map/models/drawing_path.dart';
import 'package:memomap/features/map/providers/pin_provider.dart';
import 'package:memomap/features/map/services/drawing_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:memomap/features/map/data/drawing_repository.dart'
    show DrawingData;

final localDrawingStorageProvider = Provider<LocalDrawingStorageBase>((ref) {
  final prefs = SharedPreferencesAsync();
  return SharedPreferencesLocalDrawingStorage(prefs);
});

final drawingRepositoryProvider =
    FutureProvider<DrawingRepository>((ref) async {
  return DrawingRepository.getInstance();
});

final drawingSyncServiceProvider =
    FutureProvider<DrawingSyncService>((ref) async {
  final storage = ref.watch(localDrawingStorageProvider);
  final networkChecker = ref.watch(networkCheckerProvider);
  final repository = await ref.watch(drawingRepositoryProvider.future);

  return DrawingSyncService(
    storage: storage,
    networkChecker: networkChecker,
    repository: repository,
  );
});

class DrawingState {
  final List<DrawingData> drawingDataList;
  final Color selectedColor;
  final double strokeWidth;
  final bool isDrawingMode;
  final bool isEraserMode;

  /// Temporary paths during eraser operation (null when not erasing)
  final List<DrawingPath>? eraserTempPaths;

  /// Original drawings saved at eraser operation start (for persistence)
  final List<DrawingData>? eraserOriginalDrawings;

  /// Stack of previous drawing states for undo functionality
  final List<List<DrawingData>> undoStack;

  /// Stack of undone states for redo functionality
  final List<List<DrawingData>> redoStack;

  DrawingState({
    required this.drawingDataList,
    required this.selectedColor,
    required this.strokeWidth,
    required this.isDrawingMode,
    this.isEraserMode = false,
    this.eraserTempPaths,
    this.eraserOriginalDrawings,
    this.undoStack = const [],
    this.redoStack = const [],
  });

  /// Returns true if eraser operation is currently in progress
  bool get isEraserOperationActive => eraserTempPaths != null;

  /// Returns eraser temp paths if in eraser operation, otherwise actual paths
  List<DrawingPath> get paths =>
      eraserTempPaths ?? drawingDataList.map((d) => d.path).toList();

  /// Returns true if there are items in the undo stack
  bool get canUndo => undoStack.isNotEmpty;

  /// Returns true if there are items in the redo stack
  bool get canRedo => redoStack.isNotEmpty;

  /// Push current drawingDataList to undo stack (call before modifying)
  DrawingState pushUndo() {
    return copyWith(
      undoStack: [...undoStack, drawingDataList],
    );
  }

  /// Pop from undo stack and return (newState, restoredDrawings)
  /// Returns (newState, null) if stack is empty
  (DrawingState, List<DrawingData>?) popUndo() {
    if (undoStack.isEmpty) {
      return (this, null);
    }
    final newStack = List<List<DrawingData>>.from(undoStack);
    final restored = newStack.removeLast();
    return (copyWith(undoStack: newStack), restored);
  }

  /// Push current drawingDataList to redo stack (call before undo restores)
  DrawingState pushRedo() {
    return copyWith(
      redoStack: [...redoStack, drawingDataList],
    );
  }

  /// Pop from redo stack and return (newState, restoredDrawings)
  /// Returns (newState, null) if stack is empty
  (DrawingState, List<DrawingData>?) popRedo() {
    if (redoStack.isEmpty) {
      return (this, null);
    }
    final newStack = List<List<DrawingData>>.from(redoStack);
    final restored = newStack.removeLast();
    return (copyWith(redoStack: newStack), restored);
  }

  /// Clear the redo stack (call when new operation is performed)
  DrawingState clearRedoStack() {
    return copyWith(redoStack: []);
  }

  DrawingState copyWith({
    List<DrawingData>? drawingDataList,
    Color? selectedColor,
    double? strokeWidth,
    bool? isDrawingMode,
    bool? isEraserMode,
    List<DrawingPath>? Function()? eraserTempPaths,
    List<DrawingData>? Function()? eraserOriginalDrawings,
    List<List<DrawingData>>? undoStack,
    List<List<DrawingData>>? redoStack,
  }) {
    return DrawingState(
      drawingDataList: drawingDataList ?? this.drawingDataList,
      selectedColor: selectedColor ?? this.selectedColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      isDrawingMode: isDrawingMode ?? this.isDrawingMode,
      isEraserMode: isEraserMode ?? this.isEraserMode,
      eraserTempPaths:
          eraserTempPaths != null ? eraserTempPaths() : this.eraserTempPaths,
      eraserOriginalDrawings: eraserOriginalDrawings != null
          ? eraserOriginalDrawings()
          : this.eraserOriginalDrawings,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
    );
  }
}

/// Simple async lock to serialize operations
class _AsyncLock {
  Future<void>? _lastOperation;

  Future<T> synchronized<T>(Future<T> Function() operation) async {
    final previous = _lastOperation;
    final completer = Completer<void>();
    _lastOperation = completer.future;

    try {
      if (previous != null) {
        await previous;
      }
      return await operation();
    } finally {
      completer.complete();
    }
  }
}

final drawingProvider =
    AsyncNotifierProvider<DrawingNotifier, DrawingState>(() {
  return DrawingNotifier();
});

class DrawingNotifier extends AsyncNotifier<DrawingState> {
  final _lock = _AsyncLock();

  @override
  Future<DrawingState> build() async {
    ref.listen(sessionProvider, (prev, next) {
      final prevUserId = prev?.valueOrNull?.user.id;
      final nextUserId = next.valueOrNull?.user.id;
      if (prevUserId != nextUserId) {
        ref.invalidateSelf();
      }
    });

    final syncService = await ref.watch(drawingSyncServiceProvider.future);
    final session = ref.read(sessionProvider).valueOrNull;
    final currentUserId = session?.user.id;

    await syncService.clearIfUserChanged(currentUserId);

    final cachedDrawings = await syncService.getAllDrawings();
    final initialState = DrawingState(
      drawingDataList: cachedDrawings,
      selectedColor: Colors.red,
      strokeWidth: 3,
      isDrawingMode: false,
    );

    state = AsyncValue.data(initialState);

    if (currentUserId != null) {
      _syncInBackground(syncService);
    }

    return initialState;
  }

  Future<void> _syncInBackground(DrawingSyncService syncService) async {
    try {
      await syncService.syncWithServer();
      final freshDrawings = await syncService.getAllDrawings();
      final current = state.valueOrNull;
      // Skip update if eraser operation is in progress
      if (current != null && current.eraserTempPaths == null) {
        state = AsyncValue.data(
          current.copyWith(drawingDataList: freshDrawings),
        );
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Background sync failed: $e\n$st');
      }
    }
  }

  void toggleDrawingMode() {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(
        current.copyWith(isDrawingMode: !current.isDrawingMode),
      );
    }
  }

  void setDrawingMode(bool value) {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(current.copyWith(isDrawingMode: value));
    }
  }

  void setEraserMode(bool value) {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(current.copyWith(isEraserMode: value));
    }
  }

  Future<void> addPath(DrawingPath path) async {
    return _lock.synchronized(() async {
      final current = state.valueOrNull;
      if (current == null) return;

      final isAuthenticated = ref.read(isAuthenticatedProvider);

      final withUndo = current.pushUndo().clearRedoStack();
      final optimisticDrawing = DrawingData.local(path);
      state = AsyncValue.data(
        withUndo.copyWith(
          drawingDataList: [...withUndo.drawingDataList, optimisticDrawing],
        ),
      );

      try {
        final syncService = await ref.read(drawingSyncServiceProvider.future);
        final realDrawing = await syncService.addDrawing(
          path: path,
          isAuthenticated: isAuthenticated,
        );

        final updated = state.valueOrNull;
        if (updated != null) {
          state = AsyncValue.data(
            updated.copyWith(
              drawingDataList: updated.drawingDataList
                  .map((d) => d.id == optimisticDrawing.id ? realDrawing : d)
                  .toList(),
            ),
          );
        }
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('Failed to add drawing: $e\n$st');
        }
      }
    });
  }

  // ============ Eraser Operation Methods ============

  /// Call when eraser operation starts (on pan start)
  void startEraserOperation() {
    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncValue.data(
      current.copyWith(
        eraserOriginalDrawings: () => current.drawingDataList,
        eraserTempPaths: () => current.paths,
      ),
    );
  }

  /// Call during eraser operation to update display (on pan update)
  void updateEraserPaths(List<DrawingPath> paths) {
    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncValue.data(
      current.copyWith(eraserTempPaths: () => paths),
    );
  }

  /// Call when eraser operation ends (on pan end) - persists changes
  Future<void> finishEraserOperation() async {
    return _lock.synchronized(() async {
      final current = state.valueOrNull;
      if (current == null) return;

      final originalDrawings = current.eraserOriginalDrawings;
      final tempPaths = current.eraserTempPaths;

      // If no eraser operation was active, nothing to do
      if (originalDrawings == null || tempPaths == null) return;

      final withUndo = current.pushUndo().clearRedoStack();

      // Update drawingDataList with temp paths AND clear eraser state atomically
      // This prevents UI from showing old drawings during persistence
      final tempDrawingDataList =
          tempPaths.map((p) => DrawingData.local(p)).toList();
      state = AsyncValue.data(
        withUndo.copyWith(
          drawingDataList: tempDrawingDataList,
          eraserOriginalDrawings: () => null,
          eraserTempPaths: () => null,
        ),
      );

      // Persist changes in background
      try {
        final isAuthenticated = ref.read(isAuthenticatedProvider);
        final syncService = await ref.read(drawingSyncServiceProvider.future);

        final newDrawingDataList = await syncService.replaceDrawings(
          oldDrawings: originalDrawings,
          newPaths: tempPaths,
          isAuthenticated: isAuthenticated,
        );

        final updated = state.valueOrNull;
        if (updated != null) {
          state = AsyncValue.data(
            updated.copyWith(drawingDataList: newDrawingDataList),
          );
        }
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('Failed to persist eraser changes: $e\n$st');
        }
        // On error, tempDrawingDataList is already set, so no action needed
      }
    });
  }

  Future<void> removePathAt(int index) async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (index < 0 || index >= current.drawingDataList.length) return;

    final drawing = current.drawingDataList[index];
    final isAuthenticated = ref.read(isAuthenticatedProvider);

    final newList = List<DrawingData>.from(current.drawingDataList);
    newList.removeAt(index);
    state = AsyncValue.data(current.copyWith(drawingDataList: newList));

    try {
      final syncService = await ref.read(drawingSyncServiceProvider.future);
      await syncService.deleteDrawing(
        drawing: drawing,
        isAuthenticated: isAuthenticated,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Failed to delete drawing: $e\n$st');
      }
    }
  }

  Future<void> undo() async {
    return _lock.synchronized(() async {
      final current = state.valueOrNull;
      if (current == null) return;
      // Skip undo during eraser operation to prevent inconsistency
      if (current.isEraserOperationActive) return;
      if (!current.canUndo) return;

      // Push current to redo stack, then pop from undo stack
      final withRedo = current.pushRedo();
      final (newState, restoredDrawings) = withRedo.popUndo();
      if (restoredDrawings == null) return;

      // Update UI immediately
      state = AsyncValue.data(
        newState.copyWith(drawingDataList: restoredDrawings),
      );

      // Persist the restored state
      try {
        final isAuthenticated = ref.read(isAuthenticatedProvider);
        final syncService = await ref.read(drawingSyncServiceProvider.future);

        final persistedDrawings = await syncService.replaceDrawings(
          oldDrawings: current.drawingDataList,
          newDrawings: restoredDrawings,
          isAuthenticated: isAuthenticated,
        );

        final updated = state.valueOrNull;
        if (updated != null) {
          state = AsyncValue.data(
            updated.copyWith(drawingDataList: persistedDrawings),
          );
        }
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('Failed to persist undo: $e\n$st');
        }
      }
    });
  }

  Future<void> redo() async {
    return _lock.synchronized(() async {
      final current = state.valueOrNull;
      if (current == null) return;
      // Skip redo during eraser operation to prevent inconsistency
      if (current.isEraserOperationActive) return;
      if (!current.canRedo) return;

      // Push current to undo stack, then pop from redo stack
      final withUndo = current.pushUndo();
      final (newState, restoredDrawings) = withUndo.popRedo();
      if (restoredDrawings == null) return;

      // Update UI immediately
      state = AsyncValue.data(
        newState.copyWith(drawingDataList: restoredDrawings),
      );

      // Persist the restored state
      try {
        final isAuthenticated = ref.read(isAuthenticatedProvider);
        final syncService = await ref.read(drawingSyncServiceProvider.future);

        final persistedDrawings = await syncService.replaceDrawings(
          oldDrawings: current.drawingDataList,
          newDrawings: restoredDrawings,
          isAuthenticated: isAuthenticated,
        );

        final updated = state.valueOrNull;
        if (updated != null) {
          state = AsyncValue.data(
            updated.copyWith(drawingDataList: persistedDrawings),
          );
        }
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('Failed to persist redo: $e\n$st');
        }
      }
    });
  }

  void selectColor(Color color) {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(
        current.copyWith(selectedColor: color, isEraserMode: false),
      );
    }
  }

  void changeStrokeWidth(double width) {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(current.copyWith(strokeWidth: width));
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}
