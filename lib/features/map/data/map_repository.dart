import 'package:memomap/api/api_client.dart';
import 'package:memomap/api/models/api_maps_id_request_body.dart';
import 'package:memomap/api/models/api_maps_request_body.dart';
import 'package:memomap/api/models/get_api_maps_response.dart';
import 'package:memomap/api/models/post_api_maps_response.dart';
import 'package:memomap/api/models/put_api_maps_id_response.dart';
import 'package:memomap/config/backend_config.dart';
import 'package:memomap/features/auth/data/token_storage.dart';
import 'package:uuid/uuid.dart';

MapData _createMapData({
  required String id,
  required String userId,
  required String name,
  required String? description,
  required String createdAt,
}) =>
    MapData(
      id: id,
      userId: userId,
      name: name,
      description: description,
      createdAt: DateTime.parse(createdAt),
    );

extension GetApiMapsResponseExt on GetApiMapsResponse {
  MapData toMapData() => _createMapData(
        id: id,
        userId: userId,
        name: name,
        description: description,
        createdAt: createdAt,
      );
}

extension PostApiMapsResponseExt on PostApiMapsResponse {
  MapData toMapData() => _createMapData(
        id: id,
        userId: userId,
        name: name,
        description: description,
        createdAt: createdAt,
      );
}

extension PutApiMapsIdResponseExt on PutApiMapsIdResponse {
  MapData toMapData() => _createMapData(
        id: id,
        userId: userId,
        name: name,
        description: description,
        createdAt: createdAt,
      );
}

class MapData {
  final String id;
  final String? userId;
  final String name;
  final String? description;
  final DateTime createdAt;
  final bool isLocal;

  MapData({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.createdAt,
    this.isLocal = false,
  });

  factory MapData.local({required String name, String? description}) {
    return MapData(
      id: const Uuid().v4(),
      userId: null,
      name: name,
      description: description,
      createdAt: DateTime.now(),
      isLocal: true,
    );
  }

  factory MapData.fromJson(Map<String, dynamic> json) {
    return MapData(
      id: json['id'] as String,
      userId: json['userId'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isLocal: json['isLocal'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'description': description,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'isLocal': isLocal,
    };
  }

  MapData copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    DateTime? createdAt,
    bool? isLocal,
  }) {
    return MapData(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      isLocal: isLocal ?? this.isLocal,
    );
  }
}

abstract interface class MapRepositoryBase {
  Future<List<MapData>> getMaps();
  Future<MapData?> createMap({required String name, String? description});
  Future<MapData?> updateMap(String id, {String? name, String? description});
  Future<void> deleteMap(String id);

  /// Uploads local maps to server. Returns a mapping of old local IDs to new server IDs.
  Future<Map<String, String>> uploadLocalMaps(List<MapData> localMaps);
}

class MapRepository implements MapRepositoryBase {
  MapRepository._internal(this._api);

  final ApiClient _api;

  static MapRepository? _instance;

  static Future<MapRepository> getInstance() async {
    if (_instance != null) return _instance!;
    final api = await BackendConfig.createApiClient();
    _instance = MapRepository._internal(api);
    return _instance!;
  }

  Future<bool> _isAuthenticated() async {
    final token = await TokenStorage.getSessionId();
    return token != null;
  }

  @override
  Future<List<MapData>> getMaps() async {
    if (!await _isAuthenticated()) return [];

    final response = await _api.maps.getApiMaps();
    return response.map((r) => r.toMapData()).toList();
  }

  @override
  Future<MapData?> createMap({required String name, String? description}) async {
    if (!await _isAuthenticated()) return null;

    final response = await _api.maps.postApiMaps(
      body: ApiMapsRequestBody(
        name: name,
        description: description,
      ),
    );

    return response.toMapData();
  }

  @override
  Future<MapData?> updateMap(String id, {String? name, String? description}) async {
    if (!await _isAuthenticated()) return null;

    final response = await _api.maps.putApiMapsById(
      id: id,
      body: ApiMapsIdRequestBody(
        name: name,
        description: description,
      ),
    );

    return response.toMapData();
  }

  @override
  Future<void> deleteMap(String id) async {
    if (!await _isAuthenticated()) return;

    await _api.maps.deleteApiMapsById(id: id);
  }

  @override
  Future<Map<String, String>> uploadLocalMaps(List<MapData> localMaps) async {
    if (!await _isAuthenticated() || localMaps.isEmpty) return {};

    final idMapping = <String, String>{};
    for (final map in localMaps) {
      final created = await createMap(
        name: map.name,
        description: map.description,
      );
      if (created != null) {
        idMapping[map.id] = created.id;
      }
    }
    return idMapping;
  }
}
