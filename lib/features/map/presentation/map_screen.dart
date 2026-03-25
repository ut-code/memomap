import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:memomap/features/auth/providers/auth_provider.dart';
import 'package:memomap/features/map/providers/pin_provider.dart';
import 'package:memomap/features/map/providers/drawing_provider.dart';
import 'package:memomap/features/map/models/drawing_path.dart';
import 'package:memomap/features/map/presentation/widgets/controls.dart';
import 'package:memomap/features/map/presentation/widgets/pin_list.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:convert';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? pointAnnotationManager;
  bool _isDimmed = false; // ピン選択時に背景を暗くする
  PinData? _activePin; // 選択されたピン
  Offset? _activePinScreenPos; // 選択されたピンのスクリーン座標
  Uint8List? _pinImageData;
  List<LatLng> _currentLatLngs = [];
  Offset? _eraserPosition;
  final Map<String, PinData> _annotationToPin = {};
  double _pinListExtent = 0.2;
  double _mapViewportHeight = 0;

  @override
  void initState() {
    super.initState();
    _loadPinImage();
  }

  Future<void> _loadPinImage() async {
    final ByteData bytes = await rootBundle.load('assets/pin.png');
    _pinImageData = bytes.buffer.asUint8List();
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
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

    setState(() {}); // _mapboxMapが設定されたことを通知
  }

  void _onPinListExtentChanged(double extent) {
    if ((_pinListExtent - extent).abs() < 0.001) return;
    setState(() {
      _pinListExtent = extent;
    });
  }

  Future<void> _updatePins() async {
    if (pointAnnotationManager == null || _pinImageData == null) return;
    await pointAnnotationManager!.deleteAll();
    _annotationToPin.clear();

    final pins = ref.read(pinsProvider).value ?? [];
    for (PinData pin in pins) {
      final annotation = await pointAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(
              pin.position.longitude,
              pin.position.latitude,
            ),
          ),
          image: _pinImageData,
          iconSize: 0.5,
          iconAnchor: IconAnchor.BOTTOM,
        ),
      );
      _annotationToPin[annotation.id] = pin;
    }
  }

  void _handlePinLongPress(PointAnnotation annotation) async {
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

  void _onStyleLoaded(StyleLoadedEventData data) async {
    final style = _mapboxMap?.style;
    if (style == null) return;

    // 既存のパス用ソースとレイヤー
    await style.addSource(GeoJsonSource(id: "existing_paths_source"));
    await style.addLayer(
      LineLayer(
        id: "existing_paths_layer",
        sourceId: "existing_paths_source",
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
      ),
    );
    // データ駆動型スタイリングの設定
    await style.setStyleLayerProperty("existing_paths_layer", "line-color", [
      "get",
      "color",
    ]);
    await style.setStyleLayerProperty("existing_paths_layer", "line-width", [
      "get",
      "width",
    ]);

    // 現在描画中のパス用ソースとレイヤー
    await style.addSource(GeoJsonSource(id: "current_path_source"));
    await style.addLayer(
      LineLayer(
        id: "current_path_layer",
        sourceId: "current_path_source",
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
      ),
    );

    _updateLines();
  }

  String _colorToRgb(Color color) {
    return 'rgb(${(color.r * 255.0).round().clamp(0, 255)}, ${(color.g * 255.0).round().clamp(0, 255)}, ${(color.b * 255.0).round().clamp(0, 255)})';
  }

  Future<void> _updateLines() async {
    final style = _mapboxMap?.style;
    if (style == null) return;

    final drawingState = ref.read(drawingProvider);
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

    final drawingState = ref.read(drawingProvider);
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
      }
    } catch (e) {
      debugPrint("Error updating current_path_source: $e");
    }
  }

  void _onMapTap(MapContentGestureContext context) {
    if (ref.read(drawingProvider).isDrawingMode) return;
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
    final drawingState = ref.read(drawingProvider);
    final drawingNotifier = ref.read(drawingProvider.notifier);

    final point = await _mapboxMap!.coordinateForPixel(
      ScreenCoordinate(x: localPosition.dx, y: localPosition.dy),
    );
    final latLng = LatLng(
      point.coordinates.lat.toDouble(),
      point.coordinates.lng.toDouble(),
    );

    final cameraState = await _mapboxMap!.getCameraState();
    final zoom = cameraState.zoom;

    final distance = const Distance();

    // 消しゴムの半径（メートル換算）。
    // Mapboxは512pxタイルを使用するため、ズーム0での1ピクセルあたりのメートル数は約78271.5
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
      } else if (pathModified && currentSegment.length <= 1) {
      } else if (!pathModified) {
        newPaths.add(path);
      }
    }

    if (changed) {
      drawingNotifier.setPaths(newPaths);
    }
  }

  void _onPanStart(DragStartDetails details) async {
    final drawingState = ref.read(drawingProvider);
    if (drawingState.isEraserMode) {
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

  void _onPanUpdate(DragUpdateDetails details) async {
    final drawingState = ref.read(drawingProvider);
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

  void _onPanEnd(DragEndDetails details) async {
    final drawingState = ref.read(drawingProvider);
    if (drawingState.isEraserMode) {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final user = ref.watch(currentUserProvider);
    final drawingState = ref.watch(drawingProvider);
    final colorScheme = Theme.of(context).colorScheme;

    ref.listen(drawingProvider.select((s) => s.paths), (previous, next) {
      _updateLines();
    });

    ref.listen(pinsProvider, (previous, next) {
      _updatePins();
    });

    MapboxMapsOptions.setLanguage("ja");

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Memomap'),
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
                          gestureRecognizers: drawingState.isDrawingMode
                              ? {}
                              : null,
                        ),
                        if (_mapboxMap != null)
                          IgnorePointer(
                            ignoring: !drawingState.isDrawingMode,
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
                                          _eraserPosition!.dx -
                                          drawingState.strokeWidth * 2,
                                      top:
                                          _eraserPosition!.dy -
                                          drawingState.strokeWidth * 2,
                                      child: Container(
                                        width: drawingState.strokeWidth * 4,
                                        height: drawingState.strokeWidth * 4,
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
          // ピン選択時に背景を暗くするウィジェット
          IgnorePointer(
            ignoring: !_isDimmed,
            child: AnimatedOpacity(
              opacity: _isDimmed ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(color: colorScheme.scrim.withValues(alpha: 0.4)),
            ),
          ),
          // ピン選択時に浮き上がるピン
          if (_isDimmed && _activePin != null && _activePinScreenPos != null)
            Positioned(
              left: _activePinScreenPos!.dx - 18,
              top: _activePinScreenPos!.dy - 36,
              width: 36,
              height: 36,
              child: const _PinIcon(isFloating: true),
            ),
        ],
      ),
    );
  }
}

class _PinIcon extends StatelessWidget {
  final bool isFloating;

  const _PinIcon({required this.isFloating});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.bottomCenter,
      transform: Matrix4.diagonal3Values(
        isFloating ? 1.2 : 1.0,
        isFloating ? 1.2 : 1.0,
        1.0,
      ),
      transformAlignment: Alignment.bottomCenter,
      child: Image.asset('assets/pin.png', fit: BoxFit.contain),
    );
  }
}
