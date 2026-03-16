import 'package:latlong2/latlong.dart';
import 'package:memomap/api/api_client.dart';
import 'package:memomap/api/models/api_pins_batch_request_body.dart';
import 'package:memomap/api/models/api_pins_request_body.dart';
import 'package:memomap/api/models/get_api_pins_response.dart';
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
  required num latitude,
  required num longitude,
  required String createdAt,
}) =>
    PinData(
      id: id,
      userId: userId,
      position: LatLng(latitude.toDouble(), longitude.toDouble()),
      createdAt: DateTime.parse(createdAt),
    );

extension GetApiPinsResponseExt on GetApiPinsResponse {
  PinData toPinData() => _createPinData(
        id: id,
        userId: userId,
        latitude: latitude,
        longitude: longitude,
        createdAt: createdAt,
      );
}

extension PostApiPinsResponseExt on PostApiPinsResponse {
  PinData toPinData() => _createPinData(
        id: id,
        userId: userId,
        latitude: latitude,
        longitude: longitude,
        createdAt: createdAt,
      );
}

extension PostApiPinsBatchResponseExt on PostApiPinsBatchResponse {
  PinData toPinData() => _createPinData(
        id: id,
        userId: userId,
        latitude: latitude,
        longitude: longitude,
        createdAt: createdAt,
      );
}

class PinData {
  final String id;
  final String? userId;
  final LatLng position;
  final DateTime createdAt;
  final bool isLocal;
  final String? memo;

  PinData({
    required this.id,
    required this.userId,
    required this.position,
    required this.createdAt,
    this.isLocal = false,
    this.memo,
  });

  factory PinData.local(LatLng position) {
    return PinData(
      id: const Uuid().v4(),
      userId: null,
      position: position,
      createdAt: DateTime.now(),
      isLocal: true,
    );
  }

  factory PinData.fromJson(Map<String, dynamic> json) {
    return PinData(
      id: json['id'] as String,
      userId: json['userId'] as String?,
      position: LatLng(
        (json['latitude'] as num).toDouble(),
        (json['longitude'] as num).toDouble(),
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      isLocal: json['isLocal'] as bool? ?? false,
      memo: json['memo'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'isLocal': isLocal,
      'memo': memo,
    };
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
  Future<PinData?> addPin(LatLng position) async {
    if (!await _isAuthenticated()) return null;

    final response = await _api.pins.postApiPins(
      body: ApiPinsRequestBody(
        latitude: position.latitude,
        longitude: position.longitude,
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
  Future<List<PinData>> uploadLocalPins(List<PinData> localPins) async {
    if (!await _isAuthenticated() || localPins.isEmpty) return [];

    final response = await _api.pins.postApiPinsBatch(
      body: ApiPinsBatchRequestBody(
        pins: localPins
            .map((pin) => Pins(
                  latitude: pin.position.latitude,
                  longitude: pin.position.longitude,
                ))
            .toList(),
      ),
    );

    return response.map((r) => r.toPinData()).toList();
  }
}
