import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:memomap/features/map/data/pin_repository.dart';

void main() {
  group('PinData', () {
    group('toJson', () {
      test('should serialize a server pin correctly', () {
        final pin = PinData(
          id: 'test-id-123',
          userId: 'user-456',
          position: const LatLng(35.6762, 139.6503),
          createdAt: DateTime.utc(2024, 1, 15, 10, 30, 0),
          isLocal: false,
        );

        final json = pin.toJson();

        expect(json['id'], 'test-id-123');
        expect(json['userId'], 'user-456');
        expect(json['latitude'], 35.6762);
        expect(json['longitude'], 139.6503);
        expect(json['createdAt'], '2024-01-15T10:30:00.000Z');
        expect(json['isLocal'], false);
      });

      test('should serialize a local pin correctly', () {
        final pin = PinData(
          id: 'local-id-789',
          userId: null,
          position: const LatLng(-33.8688, 151.2093),
          createdAt: DateTime.utc(2024, 3, 20, 15, 45, 30),
          isLocal: true,
        );

        final json = pin.toJson();

        expect(json['id'], 'local-id-789');
        expect(json['userId'], null);
        expect(json['latitude'], -33.8688);
        expect(json['longitude'], 151.2093);
        expect(json['createdAt'], '2024-03-20T15:45:30.000Z');
        expect(json['isLocal'], true);
      });
    });

    group('fromJson', () {
      test('should deserialize a server pin correctly', () {
        final json = {
          'id': 'test-id-123',
          'userId': 'user-456',
          'latitude': 35.6762,
          'longitude': 139.6503,
          'createdAt': '2024-01-15T10:30:00.000Z',
          'isLocal': false,
        };

        final pin = PinData.fromJson(json);

        expect(pin.id, 'test-id-123');
        expect(pin.userId, 'user-456');
        expect(pin.position.latitude, 35.6762);
        expect(pin.position.longitude, 139.6503);
        expect(pin.createdAt, DateTime.utc(2024, 1, 15, 10, 30, 0));
        expect(pin.isLocal, false);
      });

      test('should deserialize a local pin correctly', () {
        final json = {
          'id': 'local-id-789',
          'userId': null,
          'latitude': -33.8688,
          'longitude': 151.2093,
          'createdAt': '2024-03-20T15:45:30.000Z',
          'isLocal': true,
        };

        final pin = PinData.fromJson(json);

        expect(pin.id, 'local-id-789');
        expect(pin.userId, null);
        expect(pin.position.latitude, -33.8688);
        expect(pin.position.longitude, 151.2093);
        expect(pin.createdAt, DateTime.utc(2024, 3, 20, 15, 45, 30));
        expect(pin.isLocal, true);
      });

      test('should handle missing isLocal field (defaults to false)', () {
        final json = {
          'id': 'test-id',
          'userId': 'user-id',
          'latitude': 0.0,
          'longitude': 0.0,
          'createdAt': '2024-01-01T00:00:00.000Z',
        };

        final pin = PinData.fromJson(json);

        expect(pin.isLocal, false);
      });

      test('should handle integer coordinates', () {
        final json = {
          'id': 'test-id',
          'userId': 'user-id',
          'latitude': 35,
          'longitude': 139,
          'createdAt': '2024-01-01T00:00:00.000Z',
          'isLocal': false,
        };

        final pin = PinData.fromJson(json);

        expect(pin.position.latitude, 35.0);
        expect(pin.position.longitude, 139.0);
      });
    });

    group('round-trip serialization', () {
      test('should preserve all data through serialization cycle', () {
        final original = PinData(
          id: 'round-trip-id',
          userId: 'round-trip-user',
          position: const LatLng(51.5074, -0.1278),
          createdAt: DateTime.utc(2024, 6, 15, 12, 0, 0),
          isLocal: false,
        );

        final json = original.toJson();
        final restored = PinData.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.userId, original.userId);
        expect(restored.position.latitude, original.position.latitude);
        expect(restored.position.longitude, original.position.longitude);
        expect(restored.createdAt, original.createdAt);
        expect(restored.isLocal, original.isLocal);
      });

      test('should preserve local pin data through serialization cycle', () {
        final original = PinData(
          id: 'local-round-trip-id',
          userId: null,
          position: const LatLng(40.7128, -74.006),
          createdAt: DateTime.utc(2024, 7, 20, 18, 30, 0),
          isLocal: true,
        );

        final json = original.toJson();
        final restored = PinData.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.userId, original.userId);
        expect(restored.position.latitude, original.position.latitude);
        expect(restored.position.longitude, original.position.longitude);
        expect(restored.createdAt, original.createdAt);
        expect(restored.isLocal, original.isLocal);
      });
    });
  });
}
