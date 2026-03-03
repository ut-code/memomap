import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memomap/features/map/models/drawing_path.dart';

class DrawingState {
  final List<DrawingPath> paths;
  final Color selectedColor;
  final double strokeWidth;
  final bool isDrawingMode;
  final bool isEraserMode;

  DrawingState({
    required this.paths,
    required this.selectedColor,
    required this.strokeWidth,
    required this.isDrawingMode,
    this.isEraserMode = false,
  });

  DrawingState copyWith({
    List<DrawingPath>? paths,
    Color? selectedColor,
    double? strokeWidth,
    bool? isDrawingMode,
    bool? isEraserMode,
  }) {
    return DrawingState(
      paths: paths ?? this.paths,
      selectedColor: selectedColor ?? this.selectedColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      isDrawingMode: isDrawingMode ?? this.isDrawingMode,
      isEraserMode: isEraserMode ?? this.isEraserMode,
    );
  }
}

class DrawingNotifier extends Notifier<DrawingState> {
  @override
  DrawingState build() {
    return DrawingState(
      paths: [],
      selectedColor: Colors.red,
      strokeWidth: 3,
      isDrawingMode: false,
    );
  }

  void toggleDrawingMode() {
    state = state.copyWith(isDrawingMode: !state.isDrawingMode);
  }

  void setDrawingMode(bool value) {
    state = state.copyWith(isDrawingMode: value);
  }

  void setEraserMode(bool value) {
    state = state.copyWith(isEraserMode: value);
  }

  void addPath(DrawingPath path) {
    state = state.copyWith(paths: [...state.paths, path]);
  }

  void setPaths(List<DrawingPath> paths) {
    state = state.copyWith(paths: paths);
  }

  void removePathAt(int index) {
    final newPaths = List<DrawingPath>.from(state.paths);
    newPaths.removeAt(index);
    state = state.copyWith(paths: newPaths);
  }

  void undo() {
    if (state.paths.isNotEmpty) {
      state = state.copyWith(
        paths: state.paths.sublist(0, state.paths.length - 1),
      );
    }
  }

  void selectColor(Color color) {
    state = state.copyWith(selectedColor: color, isEraserMode: false);
  }

  void changeStrokeWidth(double width) {
    state = state.copyWith(strokeWidth: width);
  }
}

final drawingProvider = NotifierProvider<DrawingNotifier, DrawingState>(() {
  return DrawingNotifier();
});
