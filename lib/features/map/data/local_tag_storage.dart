import 'dart:convert';

import 'package:memomap/features/map/data/tag_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class LocalTagStorageBase {
  Future<List<TagData>> getCachedTags();
  Future<void> setCachedTags(List<TagData> tags);

  Future<List<TagData>> getLocalTags();
  Future<void> setLocalTags(List<TagData> tags);

  Future<List<String>> getPendingDeletions();
  Future<void> setPendingDeletions(List<String> ids);

  Future<String?> getLastUserId();
  Future<void> setLastUserId(String? userId);

  Future<void> clearAll();
}

class SharedPreferencesLocalTagStorage implements LocalTagStorageBase {
  static const _cachedTagsKey = 'memomap_cached_tags';
  static const _localTagsKey = 'memomap_local_tags';
  static const _pendingDeletionsKey = 'memomap_pending_tag_deletions';
  static const _lastUserIdKey = 'memomap_tag_last_user_id';

  final SharedPreferencesAsync _prefs;

  SharedPreferencesLocalTagStorage(this._prefs);

  @override
  Future<List<TagData>> getCachedTags() async {
    final jsonString = await _prefs.getString(_cachedTagsKey);
    if (jsonString == null) return [];
    return _decodeTagList(jsonString);
  }

  @override
  Future<void> setCachedTags(List<TagData> tags) async {
    await _prefs.setString(_cachedTagsKey, _encodeTagList(tags));
  }

  @override
  Future<List<TagData>> getLocalTags() async {
    final jsonString = await _prefs.getString(_localTagsKey);
    if (jsonString == null) return [];
    return _decodeTagList(jsonString);
  }

  @override
  Future<void> setLocalTags(List<TagData> tags) async {
    await _prefs.setString(_localTagsKey, _encodeTagList(tags));
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
    await _prefs.setString(_pendingDeletionsKey, jsonEncode(ids));
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
      _prefs.remove(_cachedTagsKey),
      _prefs.remove(_localTagsKey),
      _prefs.remove(_pendingDeletionsKey),
    ]);
  }

  String _encodeTagList(List<TagData> tags) {
    return jsonEncode(tags.map((t) => t.toJson()).toList());
  }

  List<TagData> _decodeTagList(String jsonString) {
    final list = jsonDecode(jsonString) as List<dynamic>;
    return list
        .map((e) => TagData.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
