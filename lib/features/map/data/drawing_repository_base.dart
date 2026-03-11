import 'package:memomap/features/map/data/drawing_repository.dart';
import 'package:memomap/features/map/models/drawing_path.dart';

abstract interface class DrawingRepositoryBase {
  Future<List<DrawingData>> getDrawings();
  Future<DrawingData?> addDrawing(DrawingPath path);
  Future<void> deleteDrawing(String id);
  Future<List<DrawingData>> uploadLocalDrawings(List<DrawingData> localDrawings);
}
