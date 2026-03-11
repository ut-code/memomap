import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:memomap/features/map/models/drawing_path.dart';
import 'package:memomap/features/map/providers/drawing_provider.dart';

class DrawingCanvas extends ConsumerStatefulWidget {
  final MapController mapController;
  const DrawingCanvas({super.key, required this.mapController});

  @override
  ConsumerState<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends ConsumerState<DrawingCanvas> {
  DrawingPath? _currentPath;
  Offset? _eraserPosition;

  void _handleEraser(Offset localPosition) {
    final drawingState = ref.read(drawingProvider).valueOrNull;
    if (drawingState == null) return;
    final drawingNotifier = ref.read(drawingProvider.notifier);

    final latLng = widget.mapController.camera.screenOffsetToLatLng(
      localPosition,
    );
    final distance = const Distance();

    final metersPerPixel =
        156543.03392 *
        math.cos(latLng.latitude * math.pi / 180) /
        math.pow(2, widget.mapController.camera.zoom);
    final eraserRadius = drawingState.strokeWidth * metersPerPixel * 2;

    List<DrawingPath> newPaths = [];
    bool changed = false;

    for (final path in drawingState.paths) {
      List<LatLng> currentSegment = [];
      bool pathModified = false;

      for (final point in path.points) {
        if (distance(latLng, point) < eraserRadius) {
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
          currentSegment.add(point);
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
        // Segment too short after modification, skip
      } else if (!pathModified) {
        newPaths.add(path);
      }
    }

    if (changed) {
      drawingNotifier.updateEraserPaths(newPaths);
    }
  }

  @override
  Widget build(BuildContext context) {
    final drawingStateAsync = ref.watch(drawingProvider);
    final drawingState = drawingStateAsync.valueOrNull;
    final drawingNotifier = ref.read(drawingProvider.notifier);

    final isDrawingMode = drawingState?.isDrawingMode ?? false;
    final isEraserMode = drawingState?.isEraserMode ?? false;
    final selectedColor = drawingState?.selectedColor ?? Colors.red;
    final strokeWidth = drawingState?.strokeWidth ?? 3.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) {
        if (!isDrawingMode) return;

        if (isEraserMode) {
          drawingNotifier.startEraserOperation();
          setState(() {
            _eraserPosition = details.localPosition;
          });
          _handleEraser(details.localPosition);
          return;
        }

        final latLng = widget.mapController.camera.screenOffsetToLatLng(
          details.localPosition,
        );
        setState(() {
          _currentPath = DrawingPath(
            points: [latLng],
            color: selectedColor,
            strokeWidth: strokeWidth,
          );
        });
      },
      onPanUpdate: (details) {
        if (!isDrawingMode) return;

        if (isEraserMode) {
          setState(() {
            _eraserPosition = details.localPosition;
          });
          _handleEraser(details.localPosition);
          return;
        }

        if (_currentPath == null) return;
        final latLng = widget.mapController.camera.screenOffsetToLatLng(
          details.localPosition,
        );
        setState(() {
          _currentPath = _currentPath!.copyWith(
            points: [..._currentPath!.points, latLng],
          );
        });
      },
      onPanEnd: (details) {
        if (isEraserMode) {
          drawingNotifier.finishEraserOperation();
          setState(() {
            _eraserPosition = null;
          });
          return;
        }

        if (_currentPath != null && _currentPath!.points.length > 1) {
          drawingNotifier.addPath(_currentPath!);
        }
        setState(() {
          _currentPath = null;
        });
      },
      child: Stack(
        children: [
          if (_currentPath != null)
            CustomPaint(
              size: Size.infinite,
              painter: _CurrentPathPainter(_currentPath!, widget.mapController),
            ),
          if (_eraserPosition != null)
            CustomPaint(
              size: Size.infinite,
              painter: _EraserPainter(
                _eraserPosition!,
                strokeWidth * 2,
              ),
            ),
        ],
      ),
    );
  }
}

class _CurrentPathPainter extends CustomPainter {
  final DrawingPath drawingPath;
  final MapController mapController;

  _CurrentPathPainter(this.drawingPath, this.mapController);

  @override
  void paint(Canvas canvas, Size size) {
    if (drawingPath.points.length < 2) return;

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = drawingPath.color
      ..strokeWidth = drawingPath.strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (var i = 0; i < drawingPath.points.length; i++) {
      final offset = mapController.camera.latLngToScreenOffset(
        drawingPath.points[i],
      );
      if (i == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CurrentPathPainter oldDelegate) => true;
}

class _EraserPainter extends CustomPainter {
  final Offset position;
  final double radius;

  _EraserPainter(this.position, this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(position, radius, paint);
  }

  @override
  bool shouldRepaint(_EraserPainter oldDelegate) =>
      oldDelegate.position != position || oldDelegate.radius != radius;
}
