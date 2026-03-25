import 'dart:convert';

import 'package:memomap/features/map/data/drawing_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class LocalDrawingStorageBase {
  Future<List<DrawingData>> getCachedDrawings();
  Future<void> setCachedDrawings(List<DrawingData> drawings);

  Future<List<DrawingData>> getLocalDrawings();
  Future<void> setLocalDrawings(List<DrawingData> drawings);

  Future<List<String>> getPendingDeletions();
  Future<void> setPendingDeletions(List<String> ids);

  Future<String?> getLastUserId();
  Future<void> setLastUserId(String? userId);

  Future<void> clearAll();
}

class SharedPreferencesLocalDrawingStorage implements LocalDrawingStorageBase {
  static const _cachedDrawingsKey = 'memomap_cached_drawings';
  static const _localDrawingsKey = 'memomap_local_drawings';
  static const _pendingDeletionsKey = 'memomap_drawing_pending_deletions';
  static const _lastUserIdKey = 'memomap_drawing_last_user_id';

  final SharedPreferencesAsync _prefs;

  SharedPreferencesLocalDrawingStorage(this._prefs);

  @override
  Future<List<DrawingData>> getCachedDrawings() async {
    final jsonString = await _prefs.getString(_cachedDrawingsKey);
    if (jsonString == null) return [];
    return _decodeDrawingList(jsonString);
  }

  @override
  Future<void> setCachedDrawings(List<DrawingData> drawings) async {
    final jsonString = _encodeDrawingList(drawings);
    await _prefs.setString(_cachedDrawingsKey, jsonString);
  }

  @override
  Future<List<DrawingData>> getLocalDrawings() async {
    final jsonString = await _prefs.getString(_localDrawingsKey);
    if (jsonString == null) return [];
    return _decodeDrawingList(jsonString);
  }

  @override
  Future<void> setLocalDrawings(List<DrawingData> drawings) async {
    final jsonString = _encodeDrawingList(drawings);
    await _prefs.setString(_localDrawingsKey, jsonString);
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
      _prefs.remove(_cachedDrawingsKey),
      _prefs.remove(_localDrawingsKey),
      _prefs.remove(_pendingDeletionsKey),
    ]);
  }

  String _encodeDrawingList(List<DrawingData> drawings) {
    return jsonEncode(drawings.map((d) => d.toJson()).toList());
  }

  List<DrawingData> _decodeDrawingList(String jsonString) {
    final list = jsonDecode(jsonString) as List<dynamic>;
    return list
        .map((e) => DrawingData.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
