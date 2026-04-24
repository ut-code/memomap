import 'dart:convert';

import 'package:memomap/features/map/data/pin_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class LocalPinStorageBase {
  Future<List<PinData>> getCachedPins();
  Future<void> setCachedPins(List<PinData> pins);

  Future<List<PinData>> getLocalPins();
  Future<void> setLocalPins(List<PinData> pins);

  Future<List<String>> getPendingDeletions();
  Future<void> setPendingDeletions(List<String> ids);

  Future<Map<String, List<String>>> getPendingTagUpdates();
  Future<void> setPendingTagUpdates(Map<String, List<String>> updates);

  Future<String?> getLastUserId();
  Future<void> setLastUserId(String? userId);

  Future<void> clearAll();
}

class SharedPreferencesLocalPinStorage implements LocalPinStorageBase {
  static const _cachedPinsKey = 'memomap_cached_pins';
  static const _localPinsKey = 'memomap_local_pins';
  static const _pendingDeletionsKey = 'memomap_pending_deletions';
  static const _pendingTagUpdatesKey = 'memomap_pending_pin_tag_updates';
  static const _lastUserIdKey = 'memomap_last_user_id';

  final SharedPreferencesAsync _prefs;

  SharedPreferencesLocalPinStorage(this._prefs);

  @override
  Future<List<PinData>> getCachedPins() async {
    final jsonString = await _prefs.getString(_cachedPinsKey);
    if (jsonString == null) return [];
    return _decodePinList(jsonString);
  }

  @override
  Future<void> setCachedPins(List<PinData> pins) async {
    final jsonString = _encodePinList(pins);
    await _prefs.setString(_cachedPinsKey, jsonString);
  }

  @override
  Future<List<PinData>> getLocalPins() async {
    final jsonString = await _prefs.getString(_localPinsKey);
    if (jsonString == null) return [];
    return _decodePinList(jsonString);
  }

  @override
  Future<void> setLocalPins(List<PinData> pins) async {
    final jsonString = _encodePinList(pins);
    await _prefs.setString(_localPinsKey, jsonString);
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
  Future<Map<String, List<String>>> getPendingTagUpdates() async {
    final jsonString = await _prefs.getString(_pendingTagUpdatesKey);
    if (jsonString == null) return {};
    final map = jsonDecode(jsonString) as Map<String, dynamic>;
    return map.map(
      (key, value) => MapEntry(key, (value as List<dynamic>).cast<String>()),
    );
  }

  @override
  Future<void> setPendingTagUpdates(Map<String, List<String>> updates) async {
    await _prefs.setString(_pendingTagUpdatesKey, jsonEncode(updates));
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
      _prefs.remove(_cachedPinsKey),
      _prefs.remove(_localPinsKey),
      _prefs.remove(_pendingDeletionsKey),
      _prefs.remove(_pendingTagUpdatesKey),
    ]);
  }

  String _encodePinList(List<PinData> pins) {
    return jsonEncode(pins.map((p) => p.toJson()).toList());
  }

  List<PinData> _decodePinList(String jsonString) {
    final list = jsonDecode(jsonString) as List<dynamic>;
    return list
        .map((e) => PinData.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
