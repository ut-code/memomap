import 'package:flutter_test/flutter_test.dart';
import 'package:memomap/features/map/data/tag_repository.dart';
import 'package:memomap/features/map/services/tag_sync_service.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

TagData _serverTag(String id, {String name = 'Tag', int color = 0xFFFF0000}) {
  return TagData(
    id: id,
    userId: 'user-1',
    name: name,
    color: color,
    createdAt: DateTime.utc(2024, 1, 15),
    isLocal: false,
  );
}

TagData _localTag(String id, {String name = 'Local', int color = 0xFF00FF00}) {
  return TagData(
    id: id,
    userId: null,
    name: name,
    color: color,
    createdAt: DateTime.utc(2024, 1, 16),
    isLocal: true,
  );
}

void main() {
  late MockLocalTagStorage mockStorage;
  late MockNetworkChecker mockNetworkChecker;
  late MockTagRepository mockRepository;
  late TagSyncService syncService;

  setUpAll(() {
    registerFallbackValue(<TagData>[]);
    registerFallbackValue(<String>[]);
  });

  setUp(() {
    mockStorage = MockLocalTagStorage();
    mockNetworkChecker = MockNetworkChecker();
    mockRepository = MockTagRepository();

    syncService = TagSyncService(
      storage: mockStorage,
      networkChecker: mockNetworkChecker,
      repository: mockRepository,
    );
  });

  group('TagSyncService', () {
    group('getAllTags', () {
      test('returns cached + local tags', () async {
        when(() => mockStorage.getCachedTags())
            .thenAnswer((_) async => [_serverTag('s1')]);
        when(() => mockStorage.getLocalTags())
            .thenAnswer((_) async => [_localTag('l1')]);

        final tags = await syncService.getAllTags();

        expect(tags.length, 2);
        expect(tags[0].id, 's1');
        expect(tags[1].id, 'l1');
      });

      test('returns empty list when both sources empty', () async {
        when(() => mockStorage.getCachedTags()).thenAnswer((_) async => []);
        when(() => mockStorage.getLocalTags()).thenAnswer((_) async => []);

        final tags = await syncService.getAllTags();
        expect(tags, isEmpty);
      });
    });

    group('createTag', () {
      test('creates on server and inserts into cache when online + auth',
          () async {
        final serverTag = _serverTag('srv-1', name: 'Work', color: 0xFF123456);

        when(() => mockNetworkChecker.isOnline).thenAnswer((_) async => true);
        when(() => mockRepository.createTag(name: 'Work', color: 0xFF123456))
            .thenAnswer((_) async => serverTag);
        when(() => mockStorage.getCachedTags()).thenAnswer((_) async => []);
        when(() => mockStorage.setCachedTags(any())).thenAnswer((_) async {});

        final result = await syncService.createTag(
          name: 'Work',
          color: 0xFF123456,
          isAuthenticated: true,
        );

        expect(result.id, 'srv-1');
        expect(result.isLocal, false);
        verify(() => mockRepository.createTag(name: 'Work', color: 0xFF123456))
            .called(1);
        verify(() => mockStorage.setCachedTags([serverTag])).called(1);
      });

      test('creates locally when offline', () async {
        when(() => mockNetworkChecker.isOnline).thenAnswer((_) async => false);
        when(() => mockStorage.getLocalTags()).thenAnswer((_) async => []);
        when(() => mockStorage.setLocalTags(any())).thenAnswer((_) async {});

        final result = await syncService.createTag(
          name: 'Offline',
          color: 0xFFABCDEF,
          isAuthenticated: true,
        );

        expect(result.isLocal, true);
        expect(result.name, 'Offline');
        expect(result.color, 0xFFABCDEF);
        verifyNever(() => mockRepository.createTag(
            name: any(named: 'name'), color: any(named: 'color')));

        final captured =
            verify(() => mockStorage.setLocalTags(captureAny())).captured;
        final savedList = captured.last as List<TagData>;
        expect(savedList.length, 1);
        expect(savedList.first.id, result.id);
      });

      test('creates locally when not authenticated', () async {
        when(() => mockNetworkChecker.isOnline).thenAnswer((_) async => true);
        when(() => mockStorage.getLocalTags()).thenAnswer((_) async => []);
        when(() => mockStorage.setLocalTags(any())).thenAnswer((_) async {});

        final result = await syncService.createTag(
          name: 'Unauth',
          color: 0xFF111111,
          isAuthenticated: false,
        );

        expect(result.isLocal, true);
        verifyNever(() => mockRepository.createTag(
            name: any(named: 'name'), color: any(named: 'color')));
      });

      test('rethrows on server error', () async {
        when(() => mockNetworkChecker.isOnline).thenAnswer((_) async => true);
        when(() => mockRepository.createTag(
              name: any(named: 'name'),
              color: any(named: 'color'),
            )).thenThrow(Exception('boom'));

        expect(
          () => syncService.createTag(
            name: 'X',
            color: 0xFF000000,
            isAuthenticated: true,
          ),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('updateTag', () {
      test('updates server tag on server and replaces in cache', () async {
        final originalTag = _serverTag('s1', name: 'Old', color: 0xFFFF0000);
        final updatedTag = _serverTag('s1', name: 'New', color: 0xFF00FF00);

        when(() => mockNetworkChecker.isOnline).thenAnswer((_) async => true);
        when(() => mockRepository.updateTag(
              's1',
              name: 'New',
              color: 0xFF00FF00,
            )).thenAnswer((_) async => updatedTag);
        when(() => mockStorage.getCachedTags())
            .thenAnswer((_) async => [originalTag]);
        when(() => mockStorage.setCachedTags(any())).thenAnswer((_) async {});

        final result = await syncService.updateTag(
          tag: originalTag,
          name: 'New',
          color: 0xFF00FF00,
          isAuthenticated: true,
        );

        expect(result?.name, 'New');
        expect(result?.color, 0xFF00FF00);

        final captured =
            verify(() => mockStorage.setCachedTags(captureAny())).captured;
        final savedList = captured.last as List<TagData>;
        expect(savedList.single.name, 'New');
      });

      test('updates local tag in local storage without server call', () async {
        final localTag = _localTag('l1', name: 'LocalOld');

        when(() => mockNetworkChecker.isOnline).thenAnswer((_) async => true);
        when(() => mockStorage.getLocalTags())
            .thenAnswer((_) async => [localTag]);
        when(() => mockStorage.setLocalTags(any())).thenAnswer((_) async {});

        final result = await syncService.updateTag(
          tag: localTag,
          name: 'LocalNew',
          isAuthenticated: true,
        );

        expect(result?.name, 'LocalNew');
        expect(result?.isLocal, true);
        verifyNever(() => mockRepository.updateTag(
              any(),
              name: any(named: 'name'),
              color: any(named: 'color'),
            ));

        final captured =
            verify(() => mockStorage.setLocalTags(captureAny())).captured;
        final savedList = captured.last as List<TagData>;
        expect(savedList.single.name, 'LocalNew');
      });

      test('returns null for server tag when offline', () async {
        final serverTag = _serverTag('s1');

        when(() => mockNetworkChecker.isOnline).thenAnswer((_) async => false);

        final result = await syncService.updateTag(
          tag: serverTag,
          name: 'X',
          isAuthenticated: true,
        );

        expect(result, null);
        verifyNever(() => mockRepository.updateTag(
              any(),
              name: any(named: 'name'),
              color: any(named: 'color'),
            ));
      });

      test('rethrows on server error for server tag', () async {
        final serverTag = _serverTag('s1');

        when(() => mockNetworkChecker.isOnline).thenAnswer((_) async => true);
        when(() => mockRepository.updateTag(
              any(),
              name: any(named: 'name'),
              color: any(named: 'color'),
            )).thenThrow(Exception('boom'));

        expect(
          () => syncService.updateTag(
            tag: serverTag,
            name: 'X',
            isAuthenticated: true,
          ),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('deleteTag', () {
      test('deletes local tag from local storage without server call',
          () async {
        final localTag = _localTag('l1');
        final other = _localTag('l2');

        when(() => mockStorage.getLocalTags())
            .thenAnswer((_) async => [localTag, other]);
        when(() => mockStorage.setLocalTags(any())).thenAnswer((_) async {});

        await syncService.deleteTag(tag: localTag, isAuthenticated: false);

        verify(() => mockStorage.setLocalTags([other])).called(1);
        verifyNever(() => mockRepository.deleteTag(any()));
      });

      test('deletes server tag from server and cache when online + auth',
          () async {
        final serverTag = _serverTag('s1');
        final other = _serverTag('s2');

        when(() => mockNetworkChecker.isOnline).thenAnswer((_) async => true);
        when(() => mockRepository.deleteTag('s1')).thenAnswer((_) async {});
        when(() => mockStorage.getCachedTags())
            .thenAnswer((_) async => [serverTag, other]);
        when(() => mockStorage.setCachedTags(any())).thenAnswer((_) async {});

        await syncService.deleteTag(tag: serverTag, isAuthenticated: true);

        verify(() => mockRepository.deleteTag('s1')).called(1);
        verify(() => mockStorage.setCachedTags([other])).called(1);
      });

      test('queues deletion when offline for server tag', () async {
        final serverTag = _serverTag('s1');

        when(() => mockNetworkChecker.isOnline).thenAnswer((_) async => false);
        when(() => mockStorage.getPendingDeletions())
            .thenAnswer((_) async => []);
        when(() => mockStorage.setPendingDeletions(any()))
            .thenAnswer((_) async {});
        when(() => mockStorage.getCachedTags())
            .thenAnswer((_) async => [serverTag]);
        when(() => mockStorage.setCachedTags(any())).thenAnswer((_) async {});

        await syncService.deleteTag(tag: serverTag, isAuthenticated: true);

        verify(() => mockStorage.setPendingDeletions(['s1'])).called(1);
        verify(() => mockStorage.setCachedTags([])).called(1);
        verifyNever(() => mockRepository.deleteTag(any()));
      });

      test('queues deletion on server error for server tag', () async {
        final serverTag = _serverTag('s1');

        when(() => mockNetworkChecker.isOnline).thenAnswer((_) async => true);
        when(() => mockRepository.deleteTag('s1'))
            .thenThrow(Exception('boom'));
        when(() => mockStorage.getPendingDeletions())
            .thenAnswer((_) async => []);
        when(() => mockStorage.setPendingDeletions(any()))
            .thenAnswer((_) async {});
        when(() => mockStorage.getCachedTags())
            .thenAnswer((_) async => [serverTag]);
        when(() => mockStorage.setCachedTags(any())).thenAnswer((_) async {});

        await syncService.deleteTag(tag: serverTag, isAuthenticated: true);

        verify(() => mockStorage.setPendingDeletions(['s1'])).called(1);
        verify(() => mockStorage.setCachedTags([])).called(1);
      });
    });

    group('syncWithServer', () {
      test('returns empty mapping when offline', () async {
        when(() => mockNetworkChecker.isOnline).thenAnswer((_) async => false);

        final result = await syncService.syncWithServer();

        expect(result, isEmpty);
        verifyNever(() => mockRepository.getTags());
        verifyNever(() => mockRepository.uploadLocalTags(any()));
      });

      test('processes pending deletions and clears them on success', () async {
        when(() => mockNetworkChecker.isOnline).thenAnswer((_) async => true);
        when(() => mockStorage.getPendingDeletions())
            .thenAnswer((_) async => ['d1', 'd2']);
        when(() => mockRepository.deleteTag(any())).thenAnswer((_) async {});
        when(() => mockStorage.setPendingDeletions(any()))
            .thenAnswer((_) async {});
        when(() => mockStorage.getLocalTags()).thenAnswer((_) async => []);
        when(() => mockRepository.getTags()).thenAnswer((_) async => []);
        when(() => mockStorage.setCachedTags(any())).thenAnswer((_) async {});

        await syncService.syncWithServer();

        verify(() => mockRepository.deleteTag('d1')).called(1);
        verify(() => mockRepository.deleteTag('d2')).called(1);
        verify(() => mockStorage.setPendingDeletions([])).called(1);
      });

      test('keeps failed pending deletions in the queue', () async {
        when(() => mockNetworkChecker.isOnline).thenAnswer((_) async => true);
        when(() => mockStorage.getPendingDeletions())
            .thenAnswer((_) async => ['d1', 'd2']);
        when(() => mockRepository.deleteTag('d1')).thenAnswer((_) async {});
        when(() => mockRepository.deleteTag('d2'))
            .thenThrow(Exception('boom'));
        when(() => mockStorage.setPendingDeletions(any()))
            .thenAnswer((_) async {});
        when(() => mockStorage.getLocalTags()).thenAnswer((_) async => []);
        when(() => mockRepository.getTags()).thenAnswer((_) async => []);
        when(() => mockStorage.setCachedTags(any())).thenAnswer((_) async {});

        await syncService.syncWithServer();

        verify(() => mockStorage.setPendingDeletions(['d2'])).called(1);
      });

      test('uploads local tags and returns idMapping', () async {
        final localTags = [_localTag('l1'), _localTag('l2')];
        final mapping = {'l1': 's1', 'l2': 's2'};

        when(() => mockNetworkChecker.isOnline).thenAnswer((_) async => true);
        when(() => mockStorage.getPendingDeletions())
            .thenAnswer((_) async => []);
        when(() => mockStorage.getLocalTags())
            .thenAnswer((_) async => localTags);
        when(() => mockRepository.uploadLocalTags(localTags))
            .thenAnswer((_) async => mapping);
        when(() => mockStorage.setLocalTags(any())).thenAnswer((_) async {});
        when(() => mockRepository.getTags()).thenAnswer((_) async => []);
        when(() => mockStorage.setCachedTags(any())).thenAnswer((_) async {});

        final result = await syncService.syncWithServer();

        expect(result, mapping);
        verify(() => mockRepository.uploadLocalTags(localTags)).called(1);
        verify(() => mockStorage.setLocalTags([])).called(1);
      });

      test('skips upload when no local tags but refreshes cache', () async {
        final serverTags = [_serverTag('s1'), _serverTag('s2')];

        when(() => mockNetworkChecker.isOnline).thenAnswer((_) async => true);
        when(() => mockStorage.getPendingDeletions())
            .thenAnswer((_) async => []);
        when(() => mockStorage.getLocalTags()).thenAnswer((_) async => []);
        when(() => mockRepository.getTags())
            .thenAnswer((_) async => serverTags);
        when(() => mockStorage.setCachedTags(any())).thenAnswer((_) async {});

        final result = await syncService.syncWithServer();

        expect(result, isEmpty);
        verifyNever(() => mockRepository.uploadLocalTags(any()));
        verify(() => mockStorage.setCachedTags(serverTags)).called(1);
      });

      test('swallows refresh errors and still returns mapping', () async {
        final localTags = [_localTag('l1')];
        final mapping = {'l1': 's1'};

        when(() => mockNetworkChecker.isOnline).thenAnswer((_) async => true);
        when(() => mockStorage.getPendingDeletions())
            .thenAnswer((_) async => []);
        when(() => mockStorage.getLocalTags())
            .thenAnswer((_) async => localTags);
        when(() => mockRepository.uploadLocalTags(localTags))
            .thenAnswer((_) async => mapping);
        when(() => mockStorage.setLocalTags(any())).thenAnswer((_) async {});
        when(() => mockRepository.getTags()).thenThrow(Exception('boom'));

        final result = await syncService.syncWithServer();

        expect(result, mapping);
      });
    });

    group('clearIfUserChanged', () {
      test('clears local data when user signs out', () async {
        when(() => mockStorage.getLastUserId())
            .thenAnswer((_) async => 'user-1');
        when(() => mockStorage.clearAll()).thenAnswer((_) async {});
        when(() => mockStorage.setLastUserId(null)).thenAnswer((_) async {});

        await syncService.clearIfUserChanged(null);

        verify(() => mockStorage.clearAll()).called(1);
        verify(() => mockStorage.setLastUserId(null)).called(1);
      });

      test('clears local data when switching users', () async {
        when(() => mockStorage.getLastUserId())
            .thenAnswer((_) async => 'user-1');
        when(() => mockStorage.clearAll()).thenAnswer((_) async {});
        when(() => mockStorage.setLastUserId('user-2'))
            .thenAnswer((_) async {});

        await syncService.clearIfUserChanged('user-2');

        verify(() => mockStorage.clearAll()).called(1);
        verify(() => mockStorage.setLastUserId('user-2')).called(1);
      });

      test('does not clear when user stays the same', () async {
        when(() => mockStorage.getLastUserId())
            .thenAnswer((_) async => 'user-1');
        when(() => mockStorage.setLastUserId('user-1'))
            .thenAnswer((_) async {});

        await syncService.clearIfUserChanged('user-1');

        verifyNever(() => mockStorage.clearAll());
        verify(() => mockStorage.setLastUserId('user-1')).called(1);
      });

      test('does not clear on first sign-in', () async {
        when(() => mockStorage.getLastUserId()).thenAnswer((_) async => null);
        when(() => mockStorage.setLastUserId('user-1'))
            .thenAnswer((_) async {});

        await syncService.clearIfUserChanged('user-1');

        verifyNever(() => mockStorage.clearAll());
        verify(() => mockStorage.setLastUserId('user-1')).called(1);
      });

      test('does not clear when both are null', () async {
        when(() => mockStorage.getLastUserId()).thenAnswer((_) async => null);
        when(() => mockStorage.setLastUserId(null)).thenAnswer((_) async {});

        await syncService.clearIfUserChanged(null);

        verifyNever(() => mockStorage.clearAll());
        verify(() => mockStorage.setLastUserId(null)).called(1);
      });
    });
  });
}
