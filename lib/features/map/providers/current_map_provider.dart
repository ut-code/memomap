import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memomap/features/map/providers/map_provider.dart';

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
    await syncService.setCurrentMapId(maps.first.id);
  }

  Future<void> _loadCurrentMapId() async {
    try {
      final syncService = await _ref.read(mapSyncServiceProvider.future);
      final savedMapId = await syncService.getCurrentMapId();

      if (kDebugMode) {
        debugPrint('[CurrentMapId] _loadCurrentMapId: savedMapId=$savedMapId');
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
        await syncService.setCurrentMapId(defaultMap.id);
      }
    } finally {
      _isCreatingDefault = false;
    }
  }

  Future<void> setCurrentMapId(String? mapId) async {
    state = mapId;
    final syncService = await _ref.read(mapSyncServiceProvider.future);
    await syncService.setCurrentMapId(mapId);
  }

  Future<void> ensureValidMapSelected() async {
    final maps = _ref.read(mapsProvider).valueOrNull ?? [];

    if (maps.isEmpty) {
      if (mounted) {
        state = null;
        final syncService = await _ref.read(mapSyncServiceProvider.future);
        await syncService.setCurrentMapId(null);
        await _createDefaultMap();
      }
      return;
    }

    final currentId = state;
    final mapExists = maps.any((m) => m.id == currentId);

    if (!mapExists && mounted) {
      state = maps.first.id;
      final syncService = await _ref.read(mapSyncServiceProvider.future);
      await syncService.setCurrentMapId(maps.first.id);
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
