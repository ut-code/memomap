import 'package:flutter_test/flutter_test.dart';
import 'package:memomap/features/map/data/tag_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

TagData _tag(String id, {bool isLocal = false}) {
  return TagData(
    id: id,
    userId: isLocal ? null : 'user-1',
    name: 'Tag $id',
    color: 0xFFFF0000,
    createdAt: DateTime.utc(2024, 1, 15),
    isLocal: isLocal,
  );
}

void main() {
  group('LocalTagStorageBase mock usage', () {
    late MockLocalTagStorage mockStorage;

    setUp(() {
      mockStorage = MockLocalTagStorage();
    });

    group('cachedTags', () {
      test('should return empty list when no cached tags', () async {
        when(() => mockStorage.getCachedTags())
            .thenAnswer((_) async => []);

        final tags = await mockStorage.getCachedTags();
        expect(tags, isEmpty);
      });

      test('should store and retrieve cached tags', () async {
        final tags = [_tag('1'), _tag('2')];

        when(() => mockStorage.setCachedTags(tags))
            .thenAnswer((_) async {});
        when(() => mockStorage.getCachedTags())
            .thenAnswer((_) async => tags);

        await mockStorage.setCachedTags(tags);
        final retrieved = await mockStorage.getCachedTags();

        expect(retrieved.length, 2);
        verify(() => mockStorage.setCachedTags(tags)).called(1);
      });
    });

    group('localTags', () {
      test('should return empty list when no local tags', () async {
        when(() => mockStorage.getLocalTags())
            .thenAnswer((_) async => []);

        final tags = await mockStorage.getLocalTags();
        expect(tags, isEmpty);
      });

      test('should store and retrieve local tags', () async {
        final tags = [_tag('l1', isLocal: true)];

        when(() => mockStorage.setLocalTags(tags))
            .thenAnswer((_) async {});
        when(() => mockStorage.getLocalTags())
            .thenAnswer((_) async => tags);

        await mockStorage.setLocalTags(tags);
        final retrieved = await mockStorage.getLocalTags();

        expect(retrieved.single.isLocal, true);
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
        final ids = ['a', 'b', 'c'];

        when(() => mockStorage.setPendingDeletions(ids))
            .thenAnswer((_) async {});
        when(() => mockStorage.getPendingDeletions())
            .thenAnswer((_) async => ids);

        await mockStorage.setPendingDeletions(ids);
        final retrieved = await mockStorage.getPendingDeletions();

        expect(retrieved, ids);
      });
    });

    group('lastUserId', () {
      test('should return null by default', () async {
        when(() => mockStorage.getLastUserId()).thenAnswer((_) async => null);

        final id = await mockStorage.getLastUserId();
        expect(id, null);
      });

      test('should store and retrieve user id', () async {
        when(() => mockStorage.setLastUserId('user-1'))
            .thenAnswer((_) async {});
        when(() => mockStorage.getLastUserId())
            .thenAnswer((_) async => 'user-1');

        await mockStorage.setLastUserId('user-1');
        final id = await mockStorage.getLastUserId();
        expect(id, 'user-1');
      });
    });

    group('clearAll', () {
      test('should clear all stored data', () async {
        when(() => mockStorage.clearAll()).thenAnswer((_) async {});

        await mockStorage.clearAll();

        verify(() => mockStorage.clearAll()).called(1);
      });
    });
  });
}
