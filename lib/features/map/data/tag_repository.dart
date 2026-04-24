import 'package:flutter/foundation.dart';
import 'package:memomap/api/api_client.dart';
import 'package:memomap/api/models/api_tags_id_request_body.dart';
import 'package:memomap/api/models/api_tags_request_body.dart';
import 'package:memomap/api/models/get_api_tags_response.dart';
import 'package:memomap/api/models/post_api_tags_response.dart';
import 'package:memomap/api/models/put_api_tags_id_response.dart';
import 'package:memomap/config/backend_config.dart';
import 'package:memomap/features/auth/data/token_storage.dart';
import 'package:uuid/uuid.dart';

/// Converts an ARGB int (Flutter Color value) to "#RRGGBB".
String colorIntToHex(int color) {
  final r = (color >> 16) & 0xFF;
  final g = (color >> 8) & 0xFF;
  final b = color & 0xFF;
  return '#${r.toRadixString(16).padLeft(2, '0')}'
          '${g.toRadixString(16).padLeft(2, '0')}'
          '${b.toRadixString(16).padLeft(2, '0')}'
      .toUpperCase();
}

/// Parses "#RRGGBB" into an ARGB int with full alpha (0xFF).
int hexToColorInt(String hex) {
  var normalized = hex.replaceAll('#', '');
  if (normalized.length == 6) {
    normalized = 'FF$normalized';
  }
  return int.parse(normalized, radix: 16);
}

TagData _createTagData({
  required String id,
  required String userId,
  required String name,
  required String color,
  required String createdAt,
}) =>
    TagData(
      id: id,
      userId: userId,
      name: name,
      color: hexToColorInt(color),
      createdAt: DateTime.parse(createdAt),
    );

extension GetApiTagsResponseExt on GetApiTagsResponse {
  TagData toTagData() => _createTagData(
        id: id,
        userId: userId,
        name: name,
        color: color,
        createdAt: createdAt,
      );
}

extension PostApiTagsResponseExt on PostApiTagsResponse {
  TagData toTagData() => _createTagData(
        id: id,
        userId: userId,
        name: name,
        color: color,
        createdAt: createdAt,
      );
}

extension PutApiTagsIdResponseExt on PutApiTagsIdResponse {
  TagData toTagData() => _createTagData(
        id: id,
        userId: userId,
        name: name,
        color: color,
        createdAt: createdAt,
      );
}

class TagData {
  final String id;
  final String? userId;
  final String name;
  final int color; // ARGB int
  final DateTime createdAt;
  final bool isLocal;

  TagData({
    required this.id,
    required this.userId,
    required this.name,
    required this.color,
    required this.createdAt,
    this.isLocal = false,
  });

  factory TagData.local({required String name, required int color}) {
    return TagData(
      id: const Uuid().v4(),
      userId: null,
      name: name,
      color: color,
      createdAt: DateTime.now(),
      isLocal: true,
    );
  }

  factory TagData.fromJson(Map<String, dynamic> json) {
    return TagData(
      id: json['id'] as String,
      userId: json['userId'] as String?,
      name: json['name'] as String,
      color: json['color'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isLocal: json['isLocal'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'color': color,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'isLocal': isLocal,
    };
  }

  TagData copyWith({
    String? id,
    String? userId,
    String? name,
    int? color,
    DateTime? createdAt,
    bool? isLocal,
  }) {
    return TagData(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      isLocal: isLocal ?? this.isLocal,
    );
  }
}

abstract interface class TagRepositoryBase {
  Future<List<TagData>> getTags();
  Future<TagData?> createTag({required String name, required int color});
  Future<TagData?> updateTag(String id, {String? name, int? color});
  Future<void> deleteTag(String id);

  /// Uploads local tags to server. Returns a mapping of old local IDs to new server IDs.
  Future<Map<String, String>> uploadLocalTags(List<TagData> localTags);
}

class TagRepository implements TagRepositoryBase {
  TagRepository._internal(this._api);

  @visibleForTesting
  TagRepository.forTesting(this._api);

  final ApiClient _api;

  static TagRepository? _instance;

  static Future<TagRepository> getInstance() async {
    if (_instance != null) return _instance!;
    final api = await BackendConfig.createApiClient();
    _instance = TagRepository._internal(api);
    return _instance!;
  }

  Future<bool> _isAuthenticated() async {
    final token = await TokenStorage.getSessionId();
    return token != null;
  }

  @override
  Future<List<TagData>> getTags() async {
    if (!await _isAuthenticated()) return [];

    final response = await _api.tags.getApiTags();
    return response.map((r) => r.toTagData()).toList();
  }

  @override
  Future<TagData?> createTag({required String name, required int color}) async {
    if (!await _isAuthenticated()) return null;

    final response = await _api.tags.postApiTags(
      body: ApiTagsRequestBody(name: name, color: colorIntToHex(color)),
    );
    return response.toTagData();
  }

  @override
  Future<TagData?> updateTag(String id, {String? name, int? color}) async {
    if (!await _isAuthenticated()) return null;

    final response = await _api.tags.putApiTagsById(
      id: id,
      body: ApiTagsIdRequestBody(
        name: name,
        color: color != null ? colorIntToHex(color) : null,
      ),
    );
    return response.toTagData();
  }

  @override
  Future<void> deleteTag(String id) async {
    if (!await _isAuthenticated()) return;

    await _api.tags.deleteApiTagsById(id: id);
  }

  @override
  Future<Map<String, String>> uploadLocalTags(List<TagData> localTags) async {
    if (!await _isAuthenticated() || localTags.isEmpty) return {};

    final idMapping = <String, String>{};
    for (final tag in localTags) {
      final created = await createTag(name: tag.name, color: tag.color);
      if (created != null) {
        idMapping[tag.id] = created.id;
      }
    }
    return idMapping;
  }
}
