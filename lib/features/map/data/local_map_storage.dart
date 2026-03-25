import 'dart:convert';

import 'package:memomap/features/map/data/map_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class LocalMapStorageBase {
  Future<List<MapData>> getCachedMaps();
  Future<void> setCachedMaps(List<MapData> maps);

  Future<List<MapData>> getLocalMaps();
  Future<void> setLocalMaps(List<MapData> maps);

  Future<List<String>> getPendingDeletions();
  Future<void> setPendingDeletions(List<String> ids);

  Future<String?> getCurrentMapId();
  Future<void> setCurrentMapId(String? mapId);

  Future<String?> getLastUserId();
  Future<void> setLastUserId(String? userId);

  Future<void> clearAll();
}

class SharedPreferencesLocalMapStorage implements LocalMapStorageBase {
  static const _cachedMapsKey = 'memomap_cached_maps';
  static const _localMapsKey = 'memomap_local_maps';
  static const _pendingDeletionsKey = 'memomap_map_pending_deletions';
  static const _currentMapIdKey = 'memomap_current_map_id';
  static const _lastUserIdKey = 'memomap_map_last_user_id';

  final SharedPreferencesAsync _prefs;

  SharedPreferencesLocalMapStorage(this._prefs);

  @override
  Future<List<MapData>> getCachedMaps() async {
    final jsonString = await _prefs.getString(_cachedMapsKey);
    if (jsonString == null) return [];
    return _decodeMapList(jsonString);
  }

  @override
  Future<void> setCachedMaps(List<MapData> maps) async {
    final jsonString = _encodeMapList(maps);
    await _prefs.setString(_cachedMapsKey, jsonString);
  }

  @override
  Future<List<MapData>> getLocalMaps() async {
    final jsonString = await _prefs.getString(_localMapsKey);
    if (jsonString == null) return [];
    return _decodeMapList(jsonString);
  }

  @override
  Future<void> setLocalMaps(List<MapData> maps) async {
    final jsonString = _encodeMapList(maps);
    await _prefs.setString(_localMapsKey, jsonString);
  }

  @override
  Future<List<String>> getPendingDeletions() async {
    final jsonString = await _prefs.getString(_pendingDeletionsKey);
    if (jsonString == null) return [];
    final list = jsonDecode(jsonString) as List<dynamic>;
    return list.cast<String>();
  }

  @override
  Future<void> setPendingDeletions(List<String> ids) async {
    final jsonString = jsonEncode(ids);
    await _prefs.setString(_pendingDeletionsKey, jsonString);
  }

  @override
  Future<String?> getCurrentMapId() async {
    return _prefs.getString(_currentMapIdKey);
  }

  @override
  Future<void> setCurrentMapId(String? mapId) async {
    if (mapId == null) {
      await _prefs.remove(_currentMapIdKey);
    } else {
      await _prefs.setString(_currentMapIdKey, mapId);
    }
  }

  @override
  Future<String?> getLastUserId() async {
    return _prefs.getString(_lastUserIdKey);
  }

  @override
  Future<void> setLastUserId(String? userId) async {
    if (userId == null) {
      await _prefs.remove(_lastUserIdKey);
    } else {
      await _prefs.setString(_lastUserIdKey, userId);
    }
  }

  @override
  Future<void> clearAll() async {
    await Future.wait([
      _prefs.remove(_cachedMapsKey),
      _prefs.remove(_localMapsKey),
      _prefs.remove(_pendingDeletionsKey),
      _prefs.remove(_currentMapIdKey),
    ]);
  }

  String _encodeMapList(List<MapData> maps) {
    return jsonEncode(maps.map((m) => m.toJson()).toList());
  }

  List<MapData> _decodeMapList(String jsonString) {
    final list = jsonDecode(jsonString) as List<dynamic>;
    return list
        .map((e) => MapData.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
