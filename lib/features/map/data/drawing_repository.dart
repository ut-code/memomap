import 'dart:ui';

import 'package:latlong2/latlong.dart';
import 'package:memomap/api/api_client.dart';
import 'package:memomap/api/models/api_drawings_batch_request_body.dart';
import 'package:memomap/api/models/api_drawings_request_body.dart';
import 'package:memomap/api/models/drawings.dart';
import 'package:memomap/api/models/get_api_drawings_response.dart';
import 'package:memomap/api/models/points3.dart';
import 'package:memomap/api/models/points5.dart';
import 'package:memomap/api/models/post_api_drawings_batch_response.dart';
import 'package:memomap/api/models/post_api_drawings_response.dart';
import 'package:memomap/config/backend_config.dart';
import 'package:memomap/features/auth/data/token_storage.dart';
import 'package:memomap/features/map/data/drawing_repository_base.dart';
import 'package:memomap/features/map/models/drawing_path.dart';
import 'package:uuid/uuid.dart';

DrawingPath _pointsToDrawingPath({
  required List<LatLng> points,
  required String colorStr,
  required num strokeWidth,
}) {
  final colorValue = int.parse(colorStr);
  return DrawingPath(
    points: points,
    color: Color(colorValue),
    strokeWidth: strokeWidth.toDouble(),
  );
}

DrawingData _createDrawingData({
  required String id,
  required String userId,
  required String? mapId,
  required DrawingPath path,
  required String createdAt,
}) =>
    DrawingData(
      id: id,
      userId: userId,
      mapId: mapId,
      path: path,
      createdAt: DateTime.parse(createdAt),
    );

extension GetApiDrawingsResponseExt on GetApiDrawingsResponse {
  DrawingData toDrawingData() => _createDrawingData(
        id: id,
        userId: userId,
        mapId: mapId,
        path: _pointsToDrawingPath(
          points: points.map((p) => LatLng(p.lat.toDouble(), p.lng.toDouble())).toList(),
          colorStr: color,
          strokeWidth: strokeWidth,
        ),
        createdAt: createdAt,
      );
}

extension PostApiDrawingsResponseExt on PostApiDrawingsResponse {
  DrawingData toDrawingData() => _createDrawingData(
        id: id,
        userId: userId,
        mapId: mapId,
        path: _pointsToDrawingPath(
          points: points.map((p) => LatLng(p.lat.toDouble(), p.lng.toDouble())).toList(),
          colorStr: color,
          strokeWidth: strokeWidth,
        ),
        createdAt: createdAt,
      );
}

extension PostApiDrawingsBatchResponseExt on PostApiDrawingsBatchResponse {
  DrawingData toDrawingData() => _createDrawingData(
        id: id,
        userId: userId,
        mapId: mapId,
        path: _pointsToDrawingPath(
          points: points.map((p) => LatLng(p.lat.toDouble(), p.lng.toDouble())).toList(),
          colorStr: color,
          strokeWidth: strokeWidth,
        ),
        createdAt: createdAt,
      );
}

class DrawingData {
  final String id;
  final String? userId;
  final String? mapId;
  final DrawingPath path;
  final DateTime createdAt;
  final bool isLocal;

  DrawingData({
    required this.id,
    required this.userId,
    required this.mapId,
    required this.path,
    required this.createdAt,
    this.isLocal = false,
  });

  factory DrawingData.local(DrawingPath path) {
    return DrawingData(
      id: const Uuid().v4(),
      userId: null,
      mapId: null,
      path: path,
      createdAt: DateTime.now(),
      isLocal: true,
    );
  }

  factory DrawingData.fromJson(Map<String, dynamic> json) {
    return DrawingData(
      id: json['id'] as String,
      userId: json['userId'] as String?,
      mapId: json['mapId'] as String?,
      path: DrawingPath.fromJson(json['path'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
      isLocal: json['isLocal'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'mapId': mapId,
      'path': path.toJson(),
      'createdAt': createdAt.toUtc().toIso8601String(),
      'isLocal': isLocal,
    };
  }
}

class DrawingRepository implements DrawingRepositoryBase {
  DrawingRepository._internal(this._api);

  final ApiClient _api;

  static DrawingRepository? _instance;

  static Future<DrawingRepository> getInstance() async {
    if (_instance != null) return _instance!;
    final api = await BackendConfig.createApiClient();
    _instance = DrawingRepository._internal(api);
    return _instance!;
  }

  Future<bool> _isAuthenticated() async {
    final token = await TokenStorage.getSessionId();
    return token != null;
  }

  @override
  Future<List<DrawingData>> getDrawings() async {
    if (!await _isAuthenticated()) return [];

    final response = await _api.drawings.getApiDrawings();
    return response.map((r) => r.toDrawingData()).toList();
  }

  @override
  Future<DrawingData?> addDrawing(DrawingPath path) async {
    if (!await _isAuthenticated()) return null;

    final response = await _api.drawings.postApiDrawings(
      body: ApiDrawingsRequestBody(
        points: path.points
            .map((p) => Points3(lat: p.latitude, lng: p.longitude))
            .toList(),
        color: path.color.toARGB32().toString(),
        strokeWidth: path.strokeWidth,
      ),
    );

    return response.toDrawingData();
  }

  @override
  Future<void> deleteDrawing(String id) async {
    if (!await _isAuthenticated()) return;

    await _api.drawings.deleteApiDrawingsById(id: id);
  }

  @override
  Future<List<DrawingData>> uploadLocalDrawings(
    List<DrawingData> localDrawings,
  ) async {
    if (!await _isAuthenticated() || localDrawings.isEmpty) return [];

    final response = await _api.drawings.postApiDrawingsBatch(
      body: ApiDrawingsBatchRequestBody(
        drawings: localDrawings
            .map((drawing) => Drawings(
                  points: drawing.path.points
                      .map((p) => Points5(lat: p.latitude, lng: p.longitude))
                      .toList(),
                  color: drawing.path.color.toARGB32().toString(),
                  strokeWidth: drawing.path.strokeWidth,
                ))
            .toList(),
      ),
    );

    return response.map((r) => r.toDrawingData()).toList();
  }
}
