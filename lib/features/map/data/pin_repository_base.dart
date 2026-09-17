import 'package:latlong2/latlong.dart';
import 'package:memomap/features/map/data/pin_repository.dart';

abstract interface class PinRepositoryBase {
  Future<List<PinData>> getPins();
  Future<PinData?> addPin(LatLng position, {String? mapId, String? memo});
  Future<PinData?> updatePin(
    String id, {
    LatLng? position,
    String? mapId,
    String? memo,
  });
  Future<void> deletePin(String id);
  Future<List<PinData>> uploadLocalPins(List<PinData> localPins, {String? mapId});
}
