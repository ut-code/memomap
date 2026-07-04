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

  /// Reads the saved current map id for [userId]. Guest sessions pass null.
  /// Stored per-user so logout → re-login restores the same selection.
  Future<String?> getCurrentMapId(String? userId);
  Future<void> setCurrentMapId(String? userId, String? mapId);

  Future<String?> getLastUserId();
  Future<void> setLastUserId(String? userId);

  Future<void> clearAll();
}

class SharedPreferencesLocalMapStorage implements LocalMapStorageBase {
  static const _cachedMapsKey = 'memomap_cached_maps';
  static const _localMapsKey = 'memomap_local_maps';
  static const _pendingDeletionsKey = 'memomap_map_pending_deletions';
  static const _currentMapIdGuestKey = 'memomap_current_map_id';
  static String _currentMapIdKeyFor(String? userId) =>
      userId == null ? _currentMapIdGuestKey : 'memomap_current_map_id_$userId';
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
  Future<String?> getCurrentMapId(String? userId) async {
    return _prefs.getString(_currentMapIdKeyFor(userId));
  }

  @override
  Future<void> setCurrentMapId(String? userId, String? mapId) async {
    final key = _currentMapIdKeyFor(userId);
    if (mapId == null) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, mapId);
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
    // Per-user current map id keys are preserved so logout → re-login
    // restores the same selection. Guest selection is also kept.
    await Future.wait([
      _prefs.remove(_cachedMapsKey),
      _prefs.remove(_localMapsKey),
      _prefs.remove(_pendingDeletionsKey),
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
