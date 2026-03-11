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
      return Marker(
        point: pin.position,
        width: 60,
        height: 60,
        alignment: Alignment.topCenter,
        child: const Icon(Icons.location_pin, size: 60, color: Colors.red),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final user = ref.watch(currentUserProvider);
    final pinsAsync = ref.watch(pinsProvider);
    final drawingStateAsync = ref.watch(drawingProvider);
    final drawingState = drawingStateAsync.valueOrNull;
    final isDrawingMode = drawingState?.isDrawingMode ?? false;
    final paths = drawingState?.paths ?? [];

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
      body: Column(
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
                      flags: isDrawingMode
                          ? InteractiveFlag.none
                          : InteractiveFlag.all &
                                ~InteractiveFlag.doubleTapZoom,
                    ),
                    onTap: (tapPosition, latlng) {
                      if (!isDrawingMode) {
                        ref.read(pinsProvider.notifier).addPin(latlng);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'dev.fleaflet.flutter_map.example',
                    ),
                    PolylineLayer(
                      polylines: paths
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
                            Uri.parse('https://openstreetmap.org/copyright'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IgnorePointer(
                  ignoring: !isDrawingMode,
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
    );
  }
}
