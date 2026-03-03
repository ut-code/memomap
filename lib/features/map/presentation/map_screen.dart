import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:memomap/features/auth/providers/auth_provider.dart';
import 'package:memomap/features/map/providers/pin_provider.dart';
import 'package:memomap/features/map/providers/drawing_provider.dart';
import 'package:memomap/features/map/presentation/widgets/drawing_canvas.dart';
import 'package:memomap/features/map/presentation/widgets/controls.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  late final MapController _mapController;
  bool _isDimmed = false; // ピン選択時に背景を暗くする
  PinData? _activePin; // 選択されたピン

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  List<Marker> _buildMarkers(List<PinData> pins) {
    return pins.map((pin) {
      final isActive = _activePin?.id == pin.id;
      return Marker(
        point: pin.position,
        width: 60,
        height: 60,
        alignment: Alignment.topCenter,
        child: Opacity(
          opacity: isActive ? 0.0 : 1.0,
          child: _AnimatedMarker(
            key: ValueKey(pin.id),
            pin: pin,
            ref: ref,
            onFloatingChanged: (isFloating) {
              setState(() {
                _isDimmed = isFloating;
                _activePin = isFloating ? pin : null;
              });
            },
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final user = ref.watch(currentUserProvider);
    final pinsAsync = ref.watch(pinsProvider);
    final drawingState = ref.watch(drawingProvider);

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
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: const LatLng(35.6895, 139.6917),
                        initialZoom: 9.2,
                        interactionOptions: InteractionOptions(
                          flags: drawingState.isDrawingMode
                              ? InteractiveFlag.none
                              : InteractiveFlag.all &
                                    ~InteractiveFlag.doubleTapZoom,
                        ),
                        onTap: (tapPosition, latlng) {
                          if (!drawingState.isDrawingMode) {
                            ref.read(pinsProvider.notifier).addPin(latlng);
                          }
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName:
                              'dev.fleaflet.flutter_map.example',
                        ),
                        PolylineLayer(
                          polylines: drawingState.paths
                              .map(
                                (path) => Polyline(
                                  points: path.points,
                                  color: path.color,
                                  strokeWidth: path.strokeWidth,
                                ),
                              )
                              .toList(),
                        ),
                        MarkerLayer(
                          markers: pinsAsync.when(
                            data: _buildMarkers,
                            loading: () => [],
                            error: (_, _) => [],
                          ),
                        ),
                        RichAttributionWidget(
                          alignment: AttributionAlignment.bottomLeft,
                          attributions: [
                            TextSourceAttribution(
                              'OpenStreetMap contributors',
                              onTap: () => launchUrl(
                                Uri.parse(
                                  'https://openstreetmap.org/copyright',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IgnorePointer(
                      ignoring: !drawingState.isDrawingMode,
                      child: DrawingCanvas(mapController: _mapController),
                    ),
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FloatingActionButton(
                            heroTag: 'zoom_in',
                            onPressed: () => _mapController.move(
                              _mapController.camera.center,
                              _mapController.camera.zoom + 1,
                            ),
                            tooltip: 'Zoom in',
                            child: const Icon(Icons.add),
                          ),
                          const SizedBox(height: 8),
                          FloatingActionButton(
                            heroTag: 'zoom_out',
                            onPressed: () => _mapController.move(
                              _mapController.camera.center,
                              _mapController.camera.zoom - 1,
                            ),
                            tooltip: 'Zoom out',
                            child: const Icon(Icons.remove),
                          ),
                        ],
                      ),
                    ),
                  ],
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
              child: Container(color: Colors.black.withValues(alpha: 0.4)),
            ),
          ),
          // ピン選択時に浮き上がるピン
          if (_isDimmed && _activePin != null)
            Builder(
              builder: (context) {
                final pos = _mapController.camera.latLngToScreenOffset(
                  _activePin!.position,
                );
                return Positioned(
                  left: pos.dx - 30,
                  top: pos.dy - 60,
                  width: 60,
                  height: 60,
                  child: const _PinIcon(isFloating: true),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _AnimatedMarker extends StatefulWidget {
  final PinData pin;
  final WidgetRef ref;
  final void Function(bool) onFloatingChanged;

  const _AnimatedMarker({
    super.key,
    required this.pin,
    required this.ref,
    required this.onFloatingChanged,
  });

  @override
  State<_AnimatedMarker> createState() => _AnimatedMarkerState();
}

class _AnimatedMarkerState extends State<_AnimatedMarker> {
  bool _isFloating = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (details) async {
        setState(() {
          _isFloating = true;
        });
        widget.onFloatingChanged(true);

        final selected = await showMenu<String>(
          context: context,
          position: RelativeRect.fromLTRB(
            details.globalPosition.dx,
            details.globalPosition.dy,
            details.globalPosition.dx,
            details.globalPosition.dy,
          ),
          items: const [
            PopupMenuItem(
              value: "delete",
              child: Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );

        if (mounted) {
          setState(() {
            _isFloating = false;
          });
          widget.onFloatingChanged(false);
        }

        if (selected == "delete") {
          widget.ref.read(pinsProvider.notifier).deletePin(widget.pin.id);
        }
      },
      child: _PinIcon(isFloating: _isFloating),
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
      child: Icon(Icons.location_on, color: Colors.red, size: 40),
    );
  }
}
