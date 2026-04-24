import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memomap/features/auth/providers/auth_provider.dart';
import 'package:memomap/features/map/providers/pin_provider.dart';
import 'package:memomap/features/map/providers/tag_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

class _FakePinsNotifier extends AsyncNotifier<List<PinData>>
    implements PinsNotifier {
  final List<String> removedTagIds = [];

  @override
  Future<List<PinData>> build() async => [];

  @override
  void removeTagFromAllPins(String tagId) {
    removedTagIds.add(tagId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTagData extends Fake implements TagData {}

TagData _tag(String id, {String name = 'Tag', int color = 0xFFFF0000}) {
  return TagData(
    id: id,
    userId: 'u1',
    name: name,
    color: color,
    createdAt: DateTime.utc(2024, 1, 15),
    isLocal: false,
  );
}

ProviderContainer _makeContainer({
  required MockTagSyncService mockSyncService,
  bool isAuthenticated = false,
  _FakePinsNotifier? fakePins,
}) {
  return ProviderContainer(
    overrides: [
      sessionProvider.overrideWith((ref) async => null),
      isAuthenticatedProvider.overrideWithValue(isAuthenticated),
      tagSyncServiceProvider.overrideWith((ref) async => mockSyncService),
      pinsProvider.overrideWith(() => fakePins ?? _FakePinsNotifier()),
    ],
  );
}

void main() {
  late MockTagSyncService mockSyncService;

  setUpAll(() {
    registerFallbackValue(_FakeTagData());
    registerFallbackValue(<TagData>[]);
  });

  setUp(() {
    mockSyncService = MockTagSyncService();
    when(() => mockSyncService.clearIfUserChanged(any()))
        .thenAnswer((_) async {});
    when(() => mockSyncService.getAllTags()).thenAnswer((_) async => []);
    when(() => mockSyncService.syncWithServer())
        .thenAnswer((_) async => <String, String>{});
  });

  group('TagsNotifier', () {
    test('build() loads cached tags via syncService when unauthenticated',
        () async {
      final cached = [_tag('t1'), _tag('t2')];
      when(() => mockSyncService.getAllTags()).thenAnswer((_) async => cached);

      final container = _makeContainer(mockSyncService: mockSyncService);
      addTearDown(container.dispose);

      final tags = await container.read(tagsProvider.future);

      expect(tags.length, 2);
      expect(tags[0].id, 't1');
      verify(() => mockSyncService.clearIfUserChanged(null)).called(1);
      verifyNever(() => mockSyncService.syncWithServer());
    });

    test('build() triggers background sync when authenticated', () async {
      final cached = [_tag('t1')];
      final refreshed = [_tag('t1'), _tag('t2-server')];
      final mapping = {'local-1': 'server-1'};

      when(() => mockSyncService.getAllTags())
          .thenAnswer((_) async => cached);
      when(() => mockSyncService.syncWithServer())
          .thenAnswer((_) async => mapping);

      final container = _makeContainer(
        mockSyncService: mockSyncService,
        isAuthenticated: true,
      );
      addTearDown(container.dispose);

      await container.read(tagsProvider.future);

      // Return fresh data on the second getAllTags call after sync
      when(() => mockSyncService.getAllTags())
          .thenAnswer((_) async => refreshed);

      // Let the background sync microtasks complete.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(tagIdMappingProvider), mapping);
      verify(() => mockSyncService.syncWithServer()).called(1);
    });

    test('createTag appends the created tag to state', () async {
      final initial = [_tag('t1')];
      final created = _tag('t-new', name: 'New');

      when(() => mockSyncService.getAllTags())
          .thenAnswer((_) async => initial);
      when(() => mockSyncService.createTag(
            name: any(named: 'name'),
            color: any(named: 'color'),
            isAuthenticated: any(named: 'isAuthenticated'),
          )).thenAnswer((_) async => created);

      final container = _makeContainer(mockSyncService: mockSyncService);
      addTearDown(container.dispose);

      await container.read(tagsProvider.future);

      final result = await container.read(tagsProvider.notifier).createTag(
            name: 'New',
            color: 0xFFFF0000,
          );

      expect(result?.id, 't-new');
      final state = container.read(tagsProvider).value!;
      expect(state.length, 2);
      expect(state.first.id, 't-new');
    });

    test('createTag rethrows on sync service error', () async {
      when(() => mockSyncService.createTag(
            name: any(named: 'name'),
            color: any(named: 'color'),
            isAuthenticated: any(named: 'isAuthenticated'),
          )).thenThrow(Exception('boom'));

      final container = _makeContainer(mockSyncService: mockSyncService);
      addTearDown(container.dispose);

      await container.read(tagsProvider.future);

      expect(
        () => container
            .read(tagsProvider.notifier)
            .createTag(name: 'X', color: 0xFF000000),
        throwsA(isA<Exception>()),
      );
    });

    test('updateTag replaces the updated tag in state', () async {
      final original = _tag('t1', name: 'Old');
      final updated = _tag('t1', name: 'New');

      when(() => mockSyncService.getAllTags())
          .thenAnswer((_) async => [original]);
      when(() => mockSyncService.updateTag(
            tag: any(named: 'tag'),
            name: any(named: 'name'),
            color: any(named: 'color'),
            isAuthenticated: any(named: 'isAuthenticated'),
          )).thenAnswer((_) async => updated);

      final container = _makeContainer(mockSyncService: mockSyncService);
      addTearDown(container.dispose);

      await container.read(tagsProvider.future);

      final result = await container
          .read(tagsProvider.notifier)
          .updateTag(original, name: 'New');

      expect(result?.name, 'New');
      final state = container.read(tagsProvider).value!;
      expect(state.single.name, 'New');
    });

    test('updateTag does nothing when sync service returns null', () async {
      final original = _tag('t1', name: 'Old');

      when(() => mockSyncService.getAllTags())
          .thenAnswer((_) async => [original]);
      when(() => mockSyncService.updateTag(
            tag: any(named: 'tag'),
            name: any(named: 'name'),
            color: any(named: 'color'),
            isAuthenticated: any(named: 'isAuthenticated'),
          )).thenAnswer((_) async => null);

      final container = _makeContainer(mockSyncService: mockSyncService);
      addTearDown(container.dispose);

      await container.read(tagsProvider.future);

      final result = await container
          .read(tagsProvider.notifier)
          .updateTag(original, name: 'New');

      expect(result, null);
      final state = container.read(tagsProvider).value!;
      expect(state.single.name, 'Old');
    });

    test('deleteTag removes tag and calls removeTagFromAllPins', () async {
      final target = _tag('t1');
      final other = _tag('t2');

      when(() => mockSyncService.getAllTags())
          .thenAnswer((_) async => [target, other]);
      when(() => mockSyncService.deleteTag(
            tag: any(named: 'tag'),
            isAuthenticated: any(named: 'isAuthenticated'),
          )).thenAnswer((_) async {});

      final fakePins = _FakePinsNotifier();
      final container = _makeContainer(
        mockSyncService: mockSyncService,
        fakePins: fakePins,
      );
      addTearDown(container.dispose);

      await container.read(tagsProvider.future);
      // Ensure pinsProvider is initialized so the ref.read(...) inside
      // deleteTag returns our fake and not a lazily-constructed new one.
      await container.read(pinsProvider.future);

      await container.read(tagsProvider.notifier).deleteTag(target);

      final state = container.read(tagsProvider).value!;
      expect(state.length, 1);
      expect(state.single.id, 't2');

      final notifier = container.read(pinsProvider.notifier);
      expect((notifier as _FakePinsNotifier).removedTagIds, ['t1']);
    });

    test('deleteTag still cleans up pins state even when sync service throws',
        () async {
      final target = _tag('t1');

      when(() => mockSyncService.getAllTags())
          .thenAnswer((_) async => [target]);
      when(() => mockSyncService.deleteTag(
            tag: any(named: 'tag'),
            isAuthenticated: any(named: 'isAuthenticated'),
          )).thenThrow(Exception('boom'));

      final fakePins = _FakePinsNotifier();
      final container = _makeContainer(
        mockSyncService: mockSyncService,
        fakePins: fakePins,
      );
      addTearDown(container.dispose);

      await container.read(tagsProvider.future);
      await container.read(pinsProvider.future);

      await container.read(tagsProvider.notifier).deleteTag(target);

      // Optimistic removal remained.
      expect(container.read(tagsProvider).value, isEmpty);
      // removeTagFromAllPins still called.
      final notifier = container.read(pinsProvider.notifier);
      expect((notifier as _FakePinsNotifier).removedTagIds, ['t1']);
    });
  });
}
