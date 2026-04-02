import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:memomap/features/auth/providers/auth_provider.dart';
import 'package:memomap/features/map/providers/current_map_provider.dart';
import 'package:memomap/features/map/providers/map_provider.dart';
import 'package:memomap/features/map/providers/pin_provider.dart';
import 'package:memomap/features/map/providers/drawing_provider.dart';
import 'package:memomap/features/map/providers/map_bounds_provider.dart';
import 'package:memomap/features/map/models/drawing_path.dart';
import 'package:memomap/features/map/presentation/widgets/controls.dart';
import 'package:memomap/features/map/presentation/widgets/pin_list.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:async';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? pointAnnotationManager;
  bool _isDimmed = false;
  PinData? _activePin;
  Offset? _activePinScreenPos;
  Uint8List? _pinImageData;
  List<LatLng> _currentLatLngs = [];
  Offset? _eraserPosition;
  final Map<String, PinData> _annotationToPin = {};
  double _pinListExtent = 0.2;
  double _mapViewportHeight = 0;
  final Map<String, PointAnnotation> _pinToAnnotation = {};

  double? _cachedZoom;
  Timer? _boundsUpdateTimer;

  @override
  void initState() {
    super.initState();
    _loadPinImage();
    MapboxMapsOptions.setLanguage("ja");

    // 定期的に地図の表示範囲を更新
    _boundsUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateMapBounds();
    });
  }

  Future<void> _loadPinImage() async {
    final ByteData bytes = await rootBundle.load('assets/pin.png');
    _pinImageData = bytes.buffer.asUint8List();
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    pointAnnotationManager = await mapboxMap.annotations
        .createPointAnnotationManager();

    pointAnnotationManager?.longPressEvents(
      onLongPress: (annotation) {
        _handlePinLongPress(annotation);
      },
    );

    await mapboxMap.logo.updateSettings(
      LogoSettings(position: OrnamentPosition.TOP_LEFT),
    );
    await mapboxMap.attribution.updateSettings(
      AttributionSettings(position: OrnamentPosition.TOP_LEFT),
    );

    _updatePins();
    _updateMapBounds();

    setState(() {});
  }

  void _onPinListExtentChanged(double extent) {
    if ((_pinListExtent - extent).abs() < 0.001) return;
    setState(() {
      _pinListExtent = extent;
    });
  }

  Future<void> _updateMapBounds() async {
    if (_mapboxMap == null || !mounted) return;

    // 画面サイズを取得
    final screenSize = MediaQuery.of(context).size;

    // 画面中心と左上のピクセル座標を緯度経度に変換
    final center = await _mapboxMap!.coordinateForPixel(
      ScreenCoordinate(x: screenSize.width / 2, y: screenSize.height / 2),
    );
    final topLeft = await _mapboxMap!.coordinateForPixel(
      ScreenCoordinate(x: 0, y: 0),
    );

    // 中心から左上までの距離を計算（外接円の半径）
    final centerLat = center.coordinates.lat;
    final centerLng = center.coordinates.lng;
    final topLeftLat = topLeft.coordinates.lat;
    final topLeftLng = topLeft.coordinates.lng;

    final latDiff = centerLat - topLeftLat;
    final lngDiff = centerLng - topLeftLng;
    final radius = math.sqrt(latDiff * latDiff + lngDiff * lngDiff).toDouble();

    final bounds = MapBounds(
      center: LatLng(centerLat.toDouble(), centerLng.toDouble()),
      radius: radius,
    );

    ref.read(mapBoundsProvider.notifier).state = bounds;
  }

  Future<void> _updatePins({bool fullRebuild = false}) async {
    if (pointAnnotationManager == null || _pinImageData == null) return;

    final pins = ref.read(pinsProvider).value ?? [];

    if (fullRebuild) {
      await pointAnnotationManager!.deleteAll();
      _annotationToPin.clear();
      _pinToAnnotation.clear();

      for (final pin in pins) {
        await _createPinAnnotation(pin);
      }
      return;
    }

    final newPinIds = pins.map((p) => p.id).toSet();
    final oldPinIds = _pinToAnnotation.keys.toSet();

    final toRemove = oldPinIds.difference(newPinIds);
    for (final pinId in toRemove) {
      final annotation = _pinToAnnotation.remove(pinId);
      if (annotation != null) {
        _annotationToPin.remove(annotation.id);
        await pointAnnotationManager!.delete(annotation);
      }
    }

    final toAdd = pins.where((p) => !oldPinIds.contains(p.id));
    for (final pin in toAdd) {
      await _createPinAnnotation(pin);
    }
  }

  Future<void> _createPinAnnotation(PinData pin) async {
    final annotation = await pointAnnotationManager!.create(
      PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(pin.position.longitude, pin.position.latitude),
        ),
        image: _pinImageData,
        iconSize: 0.5,
        iconAnchor: IconAnchor.BOTTOM,
      ),
    );
    _annotationToPin[annotation.id] = pin;
    _pinToAnnotation[pin.id] = annotation;
  }

  Future<void> _handlePinLongPress(PointAnnotation annotation) async {
    final pin = _annotationToPin[annotation.id];
    if (pin == null || _mapboxMap == null) return;

    final screenPos = await _mapboxMap!.pixelForCoordinate(
      Point(
        coordinates: Position(pin.position.longitude, pin.position.latitude),
      ),
    );

    setState(() {
      _isDimmed = true;
      _activePin = pin;
      _activePinScreenPos = Offset(
        screenPos.x.toDouble(),
        screenPos.y.toDouble(),
      );
    });

    if (!mounted) return;

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        _activePinScreenPos!.dx,
        _activePinScreenPos!.dy,
        _activePinScreenPos!.dx,
        _activePinScreenPos!.dy,
      ),
      items: [
        PopupMenuItem(
          value: "delete",
          child: Text(
            "Delete",
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    );

    if (mounted) {
      setState(() {
        _isDimmed = false;
        _activePin = null;
        _activePinScreenPos = null;
      });
    }

    if (selected == "delete") {
      ref.read(pinsProvider.notifier).deletePin(pin.id);
    }
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData data) async {
    final style = _mapboxMap?.style;
    if (style == null) return;

    await style.addSource(GeoJsonSource(id: "existing_paths_source"));
    await style.addLayer(
      LineLayer(
        id: "existing_paths_layer",
        sourceId: "existing_paths_source",
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
        lineOpacity: 1.0,
      ),
    );
    await style.setStyleLayerProperty("existing_paths_layer", "line-color", [
      "get",
      "color",
    ]);
    await style.setStyleLayerProperty("existing_paths_layer", "line-width", [
      "get",
      "width",
    ]);
    await style.setStyleLayerProperty(
      "existing_paths_layer",
      "line-opacity",
      1.0,
    );

    await style.addSource(GeoJsonSource(id: "current_path_source"));
    await style.addLayer(
      LineLayer(
        id: "current_path_layer",
        sourceId: "current_path_source",
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
        lineOpacity: 1.0,
      ),
    );

    _updateLines();
  }

  String _colorToRgb(Color color) {
    return 'rgba(${(color.r * 255.0).round().clamp(0, 255)}, ${(color.g * 255.0).round().clamp(0, 255)}, ${(color.b * 255.0).round().clamp(0, 255)}, ${color.a.toStringAsFixed(2)})';
  }

  Future<void> _updateLines() async {
    final style = _mapboxMap?.style;
    if (style == null) return;

    final drawingState = ref.read(drawingProvider).valueOrNull;
    if (drawingState == null) return;

    final features = drawingState.paths.asMap().entries.map((entry) {
      final index = entry.key;
      final path = entry.value;
      return Feature(
        id: "path_$index",
        geometry: LineString(
          coordinates: path.points
              .map((p) => Position(p.longitude, p.latitude))
              .toList(),
        ),
        properties: {
          "color": _colorToRgb(path.color),
          "width": path.strokeWidth,
        },
      );
    }).toList();

    try {
      final collection = FeatureCollection(features: features);
      await style.setStyleSourceProperty(
        "existing_paths_source",
        "data",
        jsonEncode(collection.toJson()),
      );
    } catch (e) {
      debugPrint("Error updating existing_paths_source: $e");
    }
  }

  Future<void> _updateCurrentPath() async {
    final style = _mapboxMap?.style;
    if (style == null) return;

    final drawingState = ref.read(drawingProvider).valueOrNull;
    if (drawingState == null) return;

    final features = _currentLatLngs.isEmpty
        ? <Feature>[]
        : [
            Feature(
              id: "current_path",
              geometry: LineString(
                coordinates: _currentLatLngs
                    .map((p) => Position(p.longitude, p.latitude))
                    .toList(),
              ),
            ),
          ];

    try {
      final collection = FeatureCollection(features: features);
      await style.setStyleSourceProperty(
        "current_path_source",
        "data",
        jsonEncode(collection.toJson()),
      );

      if (_currentLatLngs.isNotEmpty) {
        await style.setStyleLayerProperty(
          "current_path_layer",
          "line-color",
          _colorToRgb(drawingState.selectedColor),
        );
        await style.setStyleLayerProperty(
          "current_path_layer",
          "line-width",
          drawingState.strokeWidth,
        );
        await style.setStyleLayerProperty(
          "current_path_layer",
          "line-opacity",
          1.0,
        );
      }
    } catch (e) {
      debugPrint("Error updating current_path_source: $e");
    }
  }

  void _onMapTap(MapContentGestureContext context) {
    final drawingState = ref.read(drawingProvider).valueOrNull;
    if (drawingState == null || drawingState.isDrawingMode) return;
    final latLng = LatLng(
      context.point.coordinates.lat.toDouble(),
      context.point.coordinates.lng.toDouble(),
    );
    ref.read(pinsProvider.notifier).addPin(latLng);
  }

  Future<void> _convertToLatLng(Offset offset) async {
    if (_mapboxMap == null) return;
    final point = await _mapboxMap!.coordinateForPixel(
      ScreenCoordinate(x: offset.dx, y: offset.dy),
    );
    if (mounted) {
      setState(() {
        _currentLatLngs.add(
          LatLng(
            point.coordinates.lat.toDouble(),
            point.coordinates.lng.toDouble(),
          ),
        );
      });
    }
  }

  Future<void> _handleEraser(Offset localPosition) async {
    if (_mapboxMap == null) return;
    final drawingState = ref.read(drawingProvider).valueOrNull;
    if (drawingState == null) return;
    final drawingNotifier = ref.read(drawingProvider.notifier);

    final point = await _mapboxMap!.coordinateForPixel(
      ScreenCoordinate(x: localPosition.dx, y: localPosition.dy),
    );
    final latLng = LatLng(
      point.coordinates.lat.toDouble(),
      point.coordinates.lng.toDouble(),
    );

    final zoom = _cachedZoom ?? (await _mapboxMap!.getCameraState()).zoom;

    final distance = const Distance();

    final metersPerPixel =
        78271.51696 *
        math.cos(latLng.latitude * math.pi / 180) /
        math.pow(2, zoom);
    final eraserRadius = (drawingState.strokeWidth * 2) * metersPerPixel;

    List<DrawingPath> newPaths = [];
    bool changed = false;

    for (final path in drawingState.paths) {
      List<LatLng> currentSegment = [];
      bool pathModified = false;

      for (final p in path.points) {
        if (distance(latLng, p) < eraserRadius) {
          if (currentSegment.length > 1) {
            newPaths.add(
              DrawingPath(
                points: List.from(currentSegment),
                color: path.color,
                strokeWidth: path.strokeWidth,
              ),
            );
          }
          currentSegment = [];
          pathModified = true;
          changed = true;
        } else {
          currentSegment.add(p);
        }
      }

      if (currentSegment.length > 1) {
        newPaths.add(
          DrawingPath(
            points: currentSegment,
            color: path.color,
            strokeWidth: path.strokeWidth,
          ),
        );
      } else if (!pathModified) {
        newPaths.add(path);
      }
    }

    if (changed) {
      drawingNotifier.updateEraserPaths(newPaths);
    }
  }

  Future<void> _onPanStart(DragStartDetails details) async {
    final drawingState = ref.read(drawingProvider).valueOrNull;
    if (drawingState == null) return;

    if (drawingState.isEraserMode) {
      ref.read(drawingProvider.notifier).startEraserOperation();
      final cameraState = await _mapboxMap?.getCameraState();
      _cachedZoom = cameraState?.zoom;
      setState(() {
        _eraserPosition = details.localPosition;
      });
      await _handleEraser(details.localPosition);
      return;
    }

    _currentLatLngs = [];
    await _convertToLatLng(details.localPosition);
    await _updateCurrentPath();
  }

  Future<void> _onPanUpdate(DragUpdateDetails details) async {
    final drawingState = ref.read(drawingProvider).valueOrNull;
    if (drawingState == null) return;

    if (drawingState.isEraserMode) {
      setState(() {
        _eraserPosition = details.localPosition;
      });
      await _handleEraser(details.localPosition);
      return;
    }

    await _convertToLatLng(details.localPosition);
    await _updateCurrentPath();
  }

  Future<void> _onPanEnd(DragEndDetails details) async {
    final drawingState = ref.read(drawingProvider).valueOrNull;
    if (drawingState == null) return;

    if (drawingState.isEraserMode) {
      ref.read(drawingProvider.notifier).finishEraserOperation();
      _cachedZoom = null;
      setState(() {
        _eraserPosition = null;
      });
      return;
    }

    if (_currentLatLngs.length > 1) {
      ref
          .read(drawingProvider.notifier)
          .addPath(
            DrawingPath(
              points: List.from(_currentLatLngs),
              color: drawingState.selectedColor,
              strokeWidth: drawingState.strokeWidth,
            ),
          );
    }

    _currentLatLngs = [];
    await _updateCurrentPath();
    setState(() {});
  }

  @override
  void dispose() {
    _boundsUpdateTimer?.cancel();
    _annotationToPin.clear();
    _pinToAnnotation.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final user = ref.watch(currentUserProvider);

    final colorScheme = Theme.of(context).colorScheme;
    final currentMapId = ref.watch(currentMapIdProvider);
    final currentMap = ref.watch(currentMapProvider);
    final mapsAsync = ref.watch(mapsProvider);
    final drawingStateAsync = ref.watch(drawingProvider);
    final drawingState = drawingStateAsync.valueOrNull;
    final isDrawingMode = drawingState?.isDrawingMode ?? false;
    final strokeWidth = drawingState?.strokeWidth ?? 3.0;

    ref.listen(drawingProvider.select((s) => s.valueOrNull?.paths), (
      previous,
      next,
    ) {
      _updateLines();
    });

    ref.listen(currentMapIdProvider, (previous, next) {
      if (previous != next) {
        _updatePins(fullRebuild: true);
        _updateLines();
      }
    });

    ref.listen(pinsProvider, (previous, next) {
      _updatePins();
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        centerTitle: false,
        title: GestureDetector(
          onTap: () => context.push('/maps'),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currentMap?.name ??
                    (currentMapId != null ? 'Loading...' : 'Memomap'),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
        ),
        actions: [
          if (isAuthenticated && user != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  user.email,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          IconButton(
            icon: Icon(isAuthenticated ? Icons.person : Icons.login),
            onPressed: () =>
                context.push(isAuthenticated ? '/profile' : '/login'),
            tooltip: isAuthenticated ? 'Profile' : 'Login',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if ((_mapViewportHeight - constraints.maxHeight).abs() >
                        0.5) {
                      _mapViewportHeight = constraints.maxHeight;
                    }

                    return Stack(
                      children: [
                        MapWidget(
                          cameraOptions: CameraOptions(
                            center: Point(
                              coordinates: Position(139.767, 35.681),
                            ),
                            zoom: 12,
                            bearing: 0,
                            pitch: 0,
                          ),
                          onMapCreated: _onMapCreated,
                          onStyleLoadedListener: _onStyleLoaded,
                          onTapListener: _onMapTap,
                          gestureRecognizers: isDrawingMode ? {} : null,
                        ),
                        if (_mapboxMap != null)
                          IgnorePointer(
                            ignoring: !isDrawingMode,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanStart: _onPanStart,
                              onPanUpdate: _onPanUpdate,
                              onPanEnd: _onPanEnd,
                              child: Stack(
                                children: [
                                  Container(color: Colors.transparent),
                                  if (_eraserPosition != null)
                                    Positioned(
                                      left:
                                          _eraserPosition!.dx - strokeWidth * 2,
                                      top:
                                          _eraserPosition!.dy - strokeWidth * 2,
                                      child: Container(
                                        width: strokeWidth * 4,
                                        height: strokeWidth * 4,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.5),
                                            width: 1.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        PinList(onSheetSizeChanged: _onPinListExtentChanged),
                        Positioned(
                          right: 16,
                          bottom: (_mapViewportHeight * _pinListExtent) + 8,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FloatingActionButton(
                                heroTag: 'zoom_in',
                                onPressed: () async {
                                  final camera = await _mapboxMap
                                      ?.getCameraState();
                                  if (camera != null) {
                                    _mapboxMap?.setCamera(
                                      CameraOptions(zoom: camera.zoom + 1),
                                    );
                                  }
                                },
                                tooltip: 'Zoom in',
                                child: const Icon(Icons.add),
                              ),
                              const SizedBox(height: 8),
                              FloatingActionButton(
                                heroTag: 'zoom_out',
                                onPressed: () async {
                                  final camera = await _mapboxMap
                                      ?.getCameraState();
                                  if (camera != null) {
                                    _mapboxMap?.setCamera(
                                      CameraOptions(zoom: camera.zoom - 1),
                                    );
                                  }
                                },
                                tooltip: 'Zoom out',
                                child: const Icon(Icons.remove),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const Controls(),
            ],
          ),
          if (currentMap == null &&
              currentMapId == null &&
              !mapsAsync.isLoading)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.amber),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'No map selected. Create or select a map to add pins and drawings.',
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/maps'),
                        child: const Text('Open Maps'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          IgnorePointer(
            ignoring: !_isDimmed,
            child: AnimatedOpacity(
              opacity: _isDimmed ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(color: colorScheme.scrim.withValues(alpha: 0.4)),
            ),
          ),
          if (_isDimmed && _activePin != null && _activePinScreenPos != null)
            Positioned(
              left: _activePinScreenPos!.dx - 18,
              top: _activePinScreenPos!.dy - 36,
              width: 36,
              height: 36,
              child: const _PinIcon(),
            ),
        ],
      ),
    );
  }
}

class _PinIcon extends StatelessWidget {
  const _PinIcon();

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 1.2,
      alignment: Alignment.bottomCenter,
      child: Image.asset('assets/pin.png', fit: BoxFit.contain),
    );
  }
}
