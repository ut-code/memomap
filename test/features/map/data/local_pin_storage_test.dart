import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:memomap/features/map/data/pin_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

void main() {
  group('LocalPinStorageBase mock usage', () {
    late MockLocalPinStorage mockStorage;

    setUp(() {
      mockStorage = MockLocalPinStorage();
    });

    group('cachedPins', () {
      test('should return empty list when no cached pins', () async {
        when(() => mockStorage.getCachedPins())
            .thenAnswer((_) async => []);

        final pins = await mockStorage.getCachedPins();
        expect(pins, isEmpty);
      });

      test('should store and retrieve cached pins', () async {
        final pins = [
          PinData(
            id: 'pin-1',
            userId: 'user-1',
            position: const LatLng(35.6762, 139.6503),
            createdAt: DateTime.utc(2024, 1, 15, 10, 30, 0),
            isLocal: false,
          ),
          PinData(
            id: 'pin-2',
            userId: 'user-1',
            position: const LatLng(35.6895, 139.6917),
            createdAt: DateTime.utc(2024, 1, 16, 12, 0, 0),
            isLocal: false,
          ),
        ];

        when(() => mockStorage.setCachedPins(pins))
            .thenAnswer((_) async {});
        when(() => mockStorage.getCachedPins())
            .thenAnswer((_) async => pins);

        await mockStorage.setCachedPins(pins);
        final retrieved = await mockStorage.getCachedPins();

        expect(retrieved.length, 2);
        expect(retrieved[0].id, 'pin-1');
        expect(retrieved[1].id, 'pin-2');
        verify(() => mockStorage.setCachedPins(pins)).called(1);
      });
    });

    group('localPins', () {
      test('should return empty list when no local pins', () async {
        when(() => mockStorage.getLocalPins())
            .thenAnswer((_) async => []);

        final pins = await mockStorage.getLocalPins();
        expect(pins, isEmpty);
      });

      test('should store and retrieve local pins', () async {
        final pins = [
          PinData(
            id: 'local-1',
            userId: null,
            position: const LatLng(40.7128, -74.006),
            createdAt: DateTime.utc(2024, 3, 1),
            isLocal: true,
          ),
        ];

        when(() => mockStorage.setLocalPins(pins))
            .thenAnswer((_) async {});
        when(() => mockStorage.getLocalPins())
            .thenAnswer((_) async => pins);

        await mockStorage.setLocalPins(pins);
        final retrieved = await mockStorage.getLocalPins();

        expect(retrieved.length, 1);
        expect(retrieved[0].id, 'local-1');
        expect(retrieved[0].isLocal, true);
      });
    });

    group('pendingDeletions', () {
      test('should return empty list when no pending deletions', () async {
        when(() => mockStorage.getPendingDeletions())
            .thenAnswer((_) async => []);

        final ids = await mockStorage.getPendingDeletions();
        expect(ids, isEmpty);
      });

      test('should store and retrieve pending deletions', () async {
        final ids = ['delete-1', 'delete-2', 'delete-3'];

        when(() => mockStorage.setPendingDeletions(ids))
            .thenAnswer((_) async {});
        when(() => mockStorage.getPendingDeletions())
            .thenAnswer((_) async => ids);

        await mockStorage.setPendingDeletions(ids);
        final retrieved = await mockStorage.getPendingDeletions();

        expect(retrieved, ids);
      });
    });

    group('pendingTagUpdates', () {
      test('should return empty map by default', () async {
        when(() => mockStorage.getPendingTagUpdates())
            .thenAnswer((_) async => <String, List<String>>{});

        final updates = await mockStorage.getPendingTagUpdates();
        expect(updates, isEmpty);
      });

      test('should store and retrieve pending tag updates', () async {
        final updates = {
          'pin-1': ['tag-a', 'tag-b'],
          'pin-2': ['tag-c'],
        };

        when(() => mockStorage.setPendingTagUpdates(updates))
            .thenAnswer((_) async {});
        when(() => mockStorage.getPendingTagUpdates())
            .thenAnswer((_) async => updates);

        await mockStorage.setPendingTagUpdates(updates);
        final retrieved = await mockStorage.getPendingTagUpdates();

        expect(retrieved, updates);
        verify(() => mockStorage.setPendingTagUpdates(updates)).called(1);
      });
    });

    group('clearAll', () {
      test('should clear all stored data', () async {
        when(() => mockStorage.clearAll())
            .thenAnswer((_) async {});

        await mockStorage.clearAll();

        verify(() => mockStorage.clearAll()).called(1);
      });
    });
  });
}
