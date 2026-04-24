import 'package:latlong2/latlong.dart';
import 'package:memomap/api/api_client.dart';
import 'package:memomap/api/models/api_pins_batch_request_body.dart';
import 'package:memomap/api/models/api_pins_id_request_body.dart';
import 'package:memomap/api/models/api_pins_request_body.dart';
import 'package:memomap/api/models/get_api_pins_response.dart';
import 'package:memomap/api/models/patch_api_pins_id_response.dart';
import 'package:memomap/api/models/pins.dart';
import 'package:memomap/api/models/post_api_pins_batch_response.dart';
import 'package:memomap/api/models/post_api_pins_response.dart';
import 'package:memomap/config/backend_config.dart';
import 'package:memomap/features/auth/data/token_storage.dart';
import 'package:memomap/features/map/data/pin_repository_base.dart';
import 'package:uuid/uuid.dart';

PinData _createPinData({
  required String id,
  required String userId,
  required String? mapId,
  required num latitude,
  required num longitude,
  required String createdAt,
  required List<String> tagIds,
}) =>
    PinData(
      id: id,
      userId: userId,
      mapId: mapId,
      position: LatLng(latitude.toDouble(), longitude.toDouble()),
      createdAt: DateTime.parse(createdAt),
      tagIds: tagIds,
    );

extension GetApiPinsResponseExt on GetApiPinsResponse {
  PinData toPinData() => _createPinData(
        id: id,
        userId: userId,
        mapId: mapId,
        latitude: latitude,
        longitude: longitude,
        createdAt: createdAt,
        tagIds: List<String>.from(tagIds),
      );
}

extension PostApiPinsResponseExt on PostApiPinsResponse {
  PinData toPinData() => _createPinData(
        id: id,
        userId: userId,
        mapId: mapId,
        latitude: latitude,
        longitude: longitude,
        createdAt: createdAt,
        tagIds: List<String>.from(tagIds),
      );
}

extension PostApiPinsBatchResponseExt on PostApiPinsBatchResponse {
  PinData toPinData() => _createPinData(
        id: id,
        userId: userId,
        mapId: mapId,
        latitude: latitude,
        longitude: longitude,
        createdAt: createdAt,
        tagIds: List<String>.from(tagIds),
      );
}

extension PatchApiPinsIdResponseExt on PatchApiPinsIdResponse {
  PinData toPinData() => _createPinData(
        id: id,
        userId: userId,
        mapId: mapId,
        latitude: latitude,
        longitude: longitude,
        createdAt: createdAt,
        tagIds: List<String>.from(tagIds),
      );
}

class PinData {
  final String id;
  final String? userId;
  final String? mapId;
  final LatLng position;
  final DateTime createdAt;
  final bool isLocal;
  final List<String> tagIds;

  PinData({
    required this.id,
    required this.userId,
    this.mapId,
    required this.position,
    required this.createdAt,
    this.isLocal = false,
    this.tagIds = const [],
  });

  factory PinData.local(LatLng position, {String? mapId}) {
    return PinData(
      id: const Uuid().v4(),
      userId: null,
      mapId: mapId,
      position: position,
      createdAt: DateTime.now(),
      isLocal: true,
      tagIds: const [],
    );
  }

  factory PinData.fromJson(Map<String, dynamic> json) {
    return PinData(
      id: json['id'] as String,
      userId: json['userId'] as String?,
      mapId: json['mapId'] as String?,
      position: LatLng(
        (json['latitude'] as num).toDouble(),
        (json['longitude'] as num).toDouble(),
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      isLocal: json['isLocal'] as bool? ?? false,
      tagIds: (json['tagIds'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'mapId': mapId,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'isLocal': isLocal,
      'tagIds': tagIds,
    };
  }

  PinData copyWith({
    String? id,
    String? userId,
    String? mapId,
    LatLng? position,
    DateTime? createdAt,
    bool? isLocal,
    List<String>? tagIds,
  }) {
    return PinData(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      mapId: mapId ?? this.mapId,
      position: position ?? this.position,
      createdAt: createdAt ?? this.createdAt,
      isLocal: isLocal ?? this.isLocal,
      tagIds: tagIds ?? this.tagIds,
    );
  }
}

class PinRepository implements PinRepositoryBase {
  PinRepository._internal(this._api);

  final ApiClient _api;

  static PinRepository? _instance;

  static Future<PinRepository> getInstance() async {
    if (_instance != null) return _instance!;
    final api = await BackendConfig.createApiClient();
    _instance = PinRepository._internal(api);
    return _instance!;
  }

  Future<bool> _isAuthenticated() async {
    final token = await TokenStorage.getSessionId();
    return token != null;
  }

  @override
  Future<List<PinData>> getPins() async {
    if (!await _isAuthenticated()) return [];

    final response = await _api.pins.getApiPins();
    return response.map((r) => r.toPinData()).toList();
  }

  @override
  Future<PinData?> addPin(LatLng position, {String? mapId}) async {
    if (!await _isAuthenticated()) return null;

    final response = await _api.pins.postApiPins(
      body: ApiPinsRequestBody(
        latitude: position.latitude,
        longitude: position.longitude,
        mapId: mapId,
      ),
    );

    return response.toPinData();
  }

  @override
  Future<void> deletePin(String id) async {
    if (!await _isAuthenticated()) return;

    await _api.pins.deleteApiPinsById(id: id);
  }

  @override
  Future<List<PinData>> uploadLocalPins(List<PinData> localPins, {String? mapId}) async {
    if (!await _isAuthenticated() || localPins.isEmpty) return [];

    final response = await _api.pins.postApiPinsBatch(
      body: ApiPinsBatchRequestBody(
        pins: localPins
            .map((pin) => Pins(
                  latitude: pin.position.latitude,
                  longitude: pin.position.longitude,
                  mapId: pin.mapId ?? mapId,
                ))
            .toList(),
      ),
    );

    return response.map((r) => r.toPinData()).toList();
  }

  @override
  Future<PinData?> updatePinTags(String pinId, List<String> tagIds) async {
    if (!await _isAuthenticated()) return null;

    final response = await _api.pins.patchApiPinsById(
      id: pinId,
      body: ApiPinsIdRequestBody(tagIds: tagIds),
    );
    return response.toPinData();
  }
}
