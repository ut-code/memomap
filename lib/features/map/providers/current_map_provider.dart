import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memomap/features/auth/providers/auth_provider.dart';
import 'package:memomap/features/map/providers/drawing_provider.dart'
    show drawingProvider;
import 'package:memomap/features/map/providers/map_provider.dart';
import 'package:memomap/features/map/providers/pin_provider.dart'
    show pinsProvider;

final currentMapIdProvider = StateNotifierProvider<CurrentMapIdNotifier, String?>((ref) {
  return CurrentMapIdNotifier(ref);
});

class CurrentMapIdNotifier extends StateNotifier<String?> {
  final Ref _ref;
  bool _isCreatingDefault = false;
  bool _initialLoadComplete = false;

  CurrentMapIdNotifier(this._ref) : super(null) {
    _loadCurrentMapId();
    _listenToMapsChanges();
    _listenToMapIdMapping();
    _listenToSessionChanges();
  }

  String? get _currentUserId =>
      _ref.read(sessionProvider).valueOrNull?.user.id;

  void _listenToSessionChanges() {
    _ref.listen(sessionProvider, (prev, next) {
      final prevUserId = prev?.valueOrNull?.user.id;
      final nextUserId = next.valueOrNull?.user.id;
      if (prevUserId == nextUserId) return;

      // Guest → authed transition: keep the in-memory guest map id so the
      // mapIdMapping listener can remap it once the guest local map is
      // uploaded. Falling through to _loadCurrentMapId here would
      // trigger _createDefaultMap (since the new user has no saved map yet),
      // which creates a fresh server map and orphans the guest activity.
      // We still restore a previously-saved map id when the user has one.
      if (prevUserId == null && nextUserId != null) {
        _restoreSavedMapForUser(nextUserId);
        return;
      }

      _loadCurrentMapId();
    });
  }

  Future<void> _restoreSavedMapForUser(String userId) async {
    final syncService = await _ref.read(mapSyncServiceProvider.future);
    final savedMapId = await syncService.getCurrentMapId(userId);
    if (kDebugMode) {
      debugPrint(
          '[CurrentMapId] _restoreSavedMapForUser($userId): savedMapId=$savedMapId');
    }
    if (savedMapId != null && mounted) {
      state = savedMapId;
    }
    // If no saved map for this user, intentionally keep the current state
    // (the guest map id) so mapIdMappingProvider can remap it to the
    // newly-uploaded server map id.
  }

  void _listenToMapsChanges() {
    _ref.listen<AsyncValue<List<MapData>>>(mapsProvider, (prev, next) {
      if (!_initialLoadComplete) return;
      if (_isCreatingDefault) return;

      final maps = next.valueOrNull;
      if (maps == null) return;

      final currentId = state;

      if (currentId == null) {
        if (maps.isEmpty) {
          _createDefaultMap();
        } else {
          _selectFirstMap(maps);
        }
        return;
      }

      final mapExists = maps.any((m) => m.id == currentId);
      if (mapExists) return;

      // Before falling back, check whether the current id is a local id
      // that was just uploaded — prefer the remap over picking an
      // unrelated map. This guards against the listener firing order race
      // between this and _listenToMapIdMapping.
      final pendingMapping = _ref.read(mapIdMappingProvider);
      final remapped = pendingMapping[currentId];
      if (remapped != null && maps.any((m) => m.id == remapped)) {
        setCurrentMapId(remapped);
        return;
      }

      if (maps.isNotEmpty) {
        _selectFirstMap(maps);
      } else {
        _createDefaultMap();
      }
    });
  }

  /// When local maps are uploaded, remap currentMapId to the new server ID.
  void _listenToMapIdMapping() {
    _ref.listen<Map<String, String>>(mapIdMappingProvider, (prev, next) {
      if (next.isNotEmpty && state != null && next.containsKey(state)) {
        setCurrentMapId(next[state]!);
      }
    });
  }

  Future<void> _selectFirstMap(List<MapData> maps) async {
    if (!mounted || maps.isEmpty) return;
    state = maps.first.id;
    final syncService = await _ref.read(mapSyncServiceProvider.future);
    await syncService.setCurrentMapId(_currentUserId, maps.first.id);
  }

  Future<void> _loadCurrentMapId() async {
    try {
      // Wait for sessionProvider to settle so we know whether to read the
      // per-user saved id or the guest one. Reading prematurely (during
      // AsyncLoading) yields userId=null, makes savedMapId look absent,
      // and triggers _createDefaultMap — that local default then leaks
      // into mapsProvider.syncWithServer after session resolves and
      // duplicates the user's "Default Map" on every cold start.
      String? userId;
      try {
        final session = await _ref.read(sessionProvider.future);
        userId = session?.user.id;
      } catch (_) {
        userId = null;
      }
      if (!mounted) return;

      final syncService = await _ref.read(mapSyncServiceProvider.future);
      final savedMapId = await syncService.getCurrentMapId(userId);

      if (kDebugMode) {
        debugPrint(
            '[CurrentMapId] _loadCurrentMapId(user=$userId): savedMapId=$savedMapId');
      }

      if (savedMapId != null && mounted) {
        state = savedMapId;
      } else {
        if (kDebugMode) {
          debugPrint('[CurrentMapId] savedMapId is null, creating default map');
        }
        await _createDefaultMap();
      }
    } finally {
      _initialLoadComplete = true;
    }
  }

  Future<void> _createDefaultMap() async {
    if (_isCreatingDefault) return;
    _isCreatingDefault = true;

    try {
      final mapsNotifier = _ref.read(mapsProvider.notifier);
      final defaultMap = await mapsNotifier.createMap(
        name: 'Default Map',
        description: 'First map',
      );
      if (defaultMap != null && mounted) {
        state = defaultMap.id;
        final syncService = await _ref.read(mapSyncServiceProvider.future);
        await syncService.setCurrentMapId(_currentUserId, defaultMap.id);

        // Post-creation check: if other maps already exist on the server
        // (e.g., cold start on a new device with an existing account) and
        // our newly-created Default Map is empty, delete it and switch
        // to one of the existing maps. Without this, the user accumulates
        // an extra "Default Map" every time they log in on a new device.
        // Non-empty defaults are preserved (rename-on-conflict in sync
        // handles name collisions for those).
        _scheduleEmptyDefaultMapCleanup(defaultMap.id, defaultMap.isLocal);
      }
    } finally {
      _isCreatingDefault = false;
    }
  }

  void _scheduleEmptyDefaultMapCleanup(String createdMapId, bool wasLocal) {
    Future.microtask(() async {
      if (!mounted) return;
      try {
        // Wait for mapsProvider to fully settle (sync + mapping publish).
        // `.future` would resolve at maps' mid-build cached publish —
        // before mapping is set — so we use `notifier.syncDone` instead.
        await _ref.read(mapsProvider.notifier).syncDone;
        if (!mounted) return;

        // The freshly-created map's id may have been remapped by sync
        // (when it was created locally and later uploaded).
        var ourId = createdMapId;
        if (wasLocal) {
          final mapping = _ref.read(mapIdMappingProvider);
          ourId = mapping[createdMapId] ?? createdMapId;
        }

        final maps = _ref.read(mapsProvider).valueOrNull ?? const <MapData>[];
        final ours = maps.where((m) => m.id == ourId).firstOrNull;
        final others = maps.where((m) => m.id != ourId).toList();
        if (ours == null || others.isEmpty) return;

        // Wait for pins/drawings to settle so we read post-remap state.
        // Same reason as maps above: `.future` resolves too early.
        try {
          await _ref.read(pinsProvider.notifier).syncDone;
          await _ref.read(drawingProvider.notifier).syncDone;
        } catch (_) {
          // If either fails, be conservative and skip cleanup — we'd
          // rather keep a redundant empty map than delete one that
          // actually has content we couldn't see.
          return;
        }
        if (!mounted) return;

        final pins = _ref.read(pinsProvider).valueOrNull ?? const [];
        final drawingState = _ref.read(drawingProvider).valueOrNull;
        final drawings = drawingState?.drawingDataList ?? const [];
        final hasContent = pins.any((p) => p.mapId == ourId) ||
            drawings.any((d) => d.mapId == ourId);
        if (hasContent) return;

        if (kDebugMode) {
          debugPrint(
              '[CurrentMapId] cleanup: deleting empty default map $ourId, switching to existing');
        }

        await _ref.read(mapsProvider.notifier).deleteMap(ours);
        if (!mounted) return;

        final replacement = others.firstWhere(
          (m) => m.name == 'Default Map',
          orElse: () => others.first,
        );
        state = replacement.id;
        final syncService = await _ref.read(mapSyncServiceProvider.future);
        await syncService.setCurrentMapId(_currentUserId, replacement.id);
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('[CurrentMapId] empty-default cleanup failed: $e\n$st');
        }
      }
    });
  }

  Future<void> setCurrentMapId(String? mapId) async {
    state = mapId;
    final syncService = await _ref.read(mapSyncServiceProvider.future);
    await syncService.setCurrentMapId(_currentUserId, mapId);
  }

  Future<void> ensureValidMapSelected() async {
    final maps = _ref.read(mapsProvider).valueOrNull ?? [];

    if (maps.isEmpty) {
      if (mounted) {
        state = null;
        final syncService = await _ref.read(mapSyncServiceProvider.future);
        await syncService.setCurrentMapId(_currentUserId, null);
        await _createDefaultMap();
      }
      return;
    }

    final currentId = state;
    final mapExists = maps.any((m) => m.id == currentId);

    if (!mapExists && mounted) {
      state = maps.first.id;
      final syncService = await _ref.read(mapSyncServiceProvider.future);
      await syncService.setCurrentMapId(_currentUserId, maps.first.id);
    }
  }
}

final currentMapProvider = Provider<MapData?>((ref) {
  final currentMapId = ref.watch(currentMapIdProvider);
  final mapsAsync = ref.watch(mapsProvider);

  if (currentMapId == null) return null;

  return mapsAsync.whenOrNull(
    data: (maps) => maps.where((m) => m.id == currentMapId).firstOrNull,
  );
});
