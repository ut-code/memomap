import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:memomap/features/map/data/drawing_repository.dart';
import 'package:memomap/features/map/models/drawing_path.dart';
import 'package:memomap/features/map/providers/drawing_provider.dart';

void main() {
  group('DrawingState', () {
    final testPath1 = DrawingPath(
      points: [LatLng(35.0, 139.0), LatLng(35.1, 139.1)],
      color: const Color(0xFFFF0000),
      strokeWidth: 3.0,
    );
    final testPath2 = DrawingPath(
      points: [LatLng(36.0, 140.0), LatLng(36.1, 140.1)],
      color: const Color(0xFF00FF00),
      strokeWidth: 3.0,
    );
    final testPath3 = DrawingPath(
      points: [LatLng(37.0, 141.0), LatLng(37.1, 141.1)],
      color: const Color(0xFF0000FF),
      strokeWidth: 3.0,
    );

    DrawingData createTestDrawing(String id, DrawingPath path) {
      return DrawingData(
        id: id,
        userId: 'user-123',
        mapId: null,
        path: path,
        createdAt: DateTime.utc(2024, 1, 15),
      );
    }

    group('isEraserOperationActive', () {
      test('returns false when eraserTempPaths is null', () {
        final drawing1 = createTestDrawing('drawing-1', testPath1);

        final state = DrawingState(
          drawingDataList: [drawing1],
          selectedColor: const Color(0xFFFF0000),
          strokeWidth: 3.0,
          isDrawingMode: true,
        );

        expect(state.isEraserOperationActive, false);
      });

      test('returns true when eraserTempPaths is not null', () {
        final drawing1 = createTestDrawing('drawing-1', testPath1);

        final state = DrawingState(
          drawingDataList: [drawing1],
          selectedColor: const Color(0xFFFF0000),
          strokeWidth: 3.0,
          isDrawingMode: true,
          isEraserMode: true,
          eraserOriginalDrawings: [drawing1],
          eraserTempPaths: [testPath1],
        );

        expect(state.isEraserOperationActive, true);
      });
    });

    group('paths getter', () {
      test('returns eraserTempPaths when eraser operation is active', () {
        final drawing1 = createTestDrawing('drawing-1', testPath1);
        final drawing2 = createTestDrawing('drawing-2', testPath2);

        final state = DrawingState(
          drawingDataList: [drawing1, drawing2],
          selectedColor: const Color(0xFFFF0000),
          strokeWidth: 3.0,
          isDrawingMode: true,
          isEraserMode: true,
          eraserOriginalDrawings: [drawing1, drawing2],
          eraserTempPaths: [testPath1], // Only path1 remains after erasing
        );

        expect(state.paths.length, 1);
        expect(identical(state.paths[0], testPath1), true);
      });

      test('returns drawingDataList paths when eraser operation is not active', () {
        final drawing1 = createTestDrawing('drawing-1', testPath1);
        final drawing2 = createTestDrawing('drawing-2', testPath2);

        final state = DrawingState(
          drawingDataList: [drawing1, drawing2],
          selectedColor: const Color(0xFFFF0000),
          strokeWidth: 3.0,
          isDrawingMode: true,
        );

        expect(state.paths.length, 2);
      });
    });

    group('undoStack', () {
      test('canUndo returns false when undoStack is empty', () {
        final state = DrawingState(
          drawingDataList: [],
          selectedColor: const Color(0xFFFF0000),
          strokeWidth: 3.0,
          isDrawingMode: true,
        );

        expect(state.canUndo, false);
      });

      test('canUndo returns true when undoStack has items', () {
        final drawing1 = createTestDrawing('drawing-1', testPath1);

        final state = DrawingState(
          drawingDataList: [],
          selectedColor: const Color(0xFFFF0000),
          strokeWidth: 3.0,
          isDrawingMode: true,
          undoStack: [
            [drawing1]
          ],
        );

        expect(state.canUndo, true);
      });

      test('pushUndo adds current drawingDataList to stack', () {
        final drawing1 = createTestDrawing('drawing-1', testPath1);
        final drawing2 = createTestDrawing('drawing-2', testPath2);

        final state = DrawingState(
          drawingDataList: [drawing1, drawing2],
          selectedColor: const Color(0xFFFF0000),
          strokeWidth: 3.0,
          isDrawingMode: true,
        );

        final newState = state.pushUndo();

        expect(newState.undoStack.length, 1);
        expect(newState.undoStack[0].length, 2);
        expect(newState.undoStack[0][0].id, 'drawing-1');
      });

      test('popUndo restores previous drawingDataList', () {
        final drawing1 = createTestDrawing('drawing-1', testPath1);
        final drawing2 = createTestDrawing('drawing-2', testPath2);
        final drawing3 = createTestDrawing('drawing-3', testPath3);

        // State after eraser: only drawing3 remains, but undo stack has original
        final state = DrawingState(
          drawingDataList: [drawing3],
          selectedColor: const Color(0xFFFF0000),
          strokeWidth: 3.0,
          isDrawingMode: true,
          undoStack: [
            [drawing1, drawing2]
          ],
        );

        final (newState, restoredDrawings) = state.popUndo();

        expect(newState.undoStack.length, 0);
        expect(restoredDrawings!.length, 2);
        expect(restoredDrawings[0].id, 'drawing-1');
        expect(restoredDrawings[1].id, 'drawing-2');
      });

      test('popUndo returns null when stack is empty', () {
        final state = DrawingState(
          drawingDataList: [],
          selectedColor: const Color(0xFFFF0000),
          strokeWidth: 3.0,
          isDrawingMode: true,
        );

        final (newState, restoredDrawings) = state.popUndo();

        expect(newState.undoStack.length, 0);
        expect(restoredDrawings, null);
      });

      test('multiple pushUndo and popUndo work in LIFO order', () {
        final drawing1 = createTestDrawing('drawing-1', testPath1);
        final drawing2 = createTestDrawing('drawing-2', testPath2);
        final drawing3 = createTestDrawing('drawing-3', testPath3);

        // Start with drawing1
        var state = DrawingState(
          drawingDataList: [drawing1],
          selectedColor: const Color(0xFFFF0000),
          strokeWidth: 3.0,
          isDrawingMode: true,
        );

        // Push (save drawing1), then change to drawing1+drawing2
        state = state.pushUndo().copyWith(drawingDataList: [drawing1, drawing2]);

        // Push (save drawing1+drawing2), then change to drawing3 only
        state = state.pushUndo().copyWith(drawingDataList: [drawing3]);

        expect(state.undoStack.length, 2);
        expect(state.drawingDataList.length, 1);

        // Pop: should get drawing1+drawing2
        var result = state.popUndo();
        state = result.$1.copyWith(drawingDataList: result.$2);
        expect(state.drawingDataList.length, 2);
        expect(state.drawingDataList[0].id, 'drawing-1');

        // Pop: should get drawing1
        result = state.popUndo();
        state = result.$1.copyWith(drawingDataList: result.$2);
        expect(state.drawingDataList.length, 1);
        expect(state.drawingDataList[0].id, 'drawing-1');

        // Pop: stack empty, returns null
        result = state.popUndo();
        expect(result.$2, null);
      });
    });

    group('redoStack', () {
      test('canRedo returns false when redoStack is empty', () {
        final state = DrawingState(
          drawingDataList: [],
          selectedColor: const Color(0xFFFF0000),
          strokeWidth: 3.0,
          isDrawingMode: true,
        );

        expect(state.canRedo, false);
      });

      test('canRedo returns true when redoStack has items', () {
        final drawing1 = createTestDrawing('drawing-1', testPath1);

        final state = DrawingState(
          drawingDataList: [],
          selectedColor: const Color(0xFFFF0000),
          strokeWidth: 3.0,
          isDrawingMode: true,
          redoStack: [
            [drawing1]
          ],
        );

        expect(state.canRedo, true);
      });

      test('pushRedo adds current drawingDataList to redo stack', () {
        final drawing1 = createTestDrawing('drawing-1', testPath1);

        final state = DrawingState(
          drawingDataList: [drawing1],
          selectedColor: const Color(0xFFFF0000),
          strokeWidth: 3.0,
          isDrawingMode: true,
        );

        final newState = state.pushRedo();

        expect(newState.redoStack.length, 1);
        expect(newState.redoStack[0].length, 1);
        expect(newState.redoStack[0][0].id, 'drawing-1');
      });

      test('popRedo restores previous drawingDataList', () {
        final drawing1 = createTestDrawing('drawing-1', testPath1);
        final drawing2 = createTestDrawing('drawing-2', testPath2);

        final state = DrawingState(
          drawingDataList: [drawing1],
          selectedColor: const Color(0xFFFF0000),
          strokeWidth: 3.0,
          isDrawingMode: true,
          redoStack: [
            [drawing1, drawing2]
          ],
        );

        final (newState, restoredDrawings) = state.popRedo();

        expect(newState.redoStack.length, 0);
        expect(restoredDrawings!.length, 2);
        expect(restoredDrawings[0].id, 'drawing-1');
        expect(restoredDrawings[1].id, 'drawing-2');
      });

      test('popRedo returns null when stack is empty', () {
        final state = DrawingState(
          drawingDataList: [],
          selectedColor: const Color(0xFFFF0000),
          strokeWidth: 3.0,
          isDrawingMode: true,
        );

        final (newState, restoredDrawings) = state.popRedo();

        expect(newState.redoStack.length, 0);
        expect(restoredDrawings, null);
      });

      test('clearRedoStack clears the redo stack', () {
        final drawing1 = createTestDrawing('drawing-1', testPath1);

        final state = DrawingState(
          drawingDataList: [],
          selectedColor: const Color(0xFFFF0000),
          strokeWidth: 3.0,
          isDrawingMode: true,
          redoStack: [
            [drawing1]
          ],
        );

        final newState = state.clearRedoStack();

        expect(newState.redoStack.length, 0);
      });

      test('undo and redo work together', () {
        final drawing1 = createTestDrawing('drawing-1', testPath1);
        final drawing2 = createTestDrawing('drawing-2', testPath2);

        // Start: [drawing1, drawing2]
        var state = DrawingState(
          drawingDataList: [drawing1, drawing2],
          selectedColor: const Color(0xFFFF0000),
          strokeWidth: 3.0,
          isDrawingMode: true,
        );

        // Add drawing3: push to undo, change state
        state = state.pushUndo().copyWith(drawingDataList: [drawing1, drawing2, createTestDrawing('drawing-3', testPath3)]);
        expect(state.drawingDataList.length, 3);
        expect(state.undoStack.length, 1);

        // Undo: push current to redo, pop from undo
        final (afterPop, restored) = state.popUndo();
        state = afterPop.pushRedo().copyWith(drawingDataList: restored);
        expect(state.drawingDataList.length, 2);
        expect(state.undoStack.length, 0);
        expect(state.redoStack.length, 1);

        // Redo: push current to undo, pop from redo
        final (afterRedoPop, redoRestored) = state.popRedo();
        state = afterRedoPop.pushUndo().copyWith(drawingDataList: redoRestored);
        expect(state.drawingDataList.length, 3);
        expect(state.undoStack.length, 1);
        expect(state.redoStack.length, 0);
      });
    });
  });
}
