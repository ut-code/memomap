import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memomap/api/models/api_tags_id_request_body.dart';
import 'package:memomap/api/models/api_tags_request_body.dart';
import 'package:memomap/api/models/get_api_tags_response.dart';
import 'package:memomap/api/models/post_api_tags_response.dart';
import 'package:memomap/api/models/put_api_tags_id_response.dart';
import 'package:memomap/features/map/data/tag_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

class _FakeApiTagsRequestBody extends Fake implements ApiTagsRequestBody {}

class _FakeApiTagsIdRequestBody extends Fake implements ApiTagsIdRequestBody {}

void main() {
  late MockApiClient mockApiClient;
  late MockTagsClient mockTagsClient;
  late TagRepository repository;

  setUpAll(() {
    registerFallbackValue(_FakeApiTagsRequestBody());
    registerFallbackValue(_FakeApiTagsIdRequestBody());
  });

  setUp(() {
    mockApiClient = MockApiClient();
    mockTagsClient = MockTagsClient();
    when(() => mockApiClient.tags).thenReturn(mockTagsClient);
    repository = TagRepository.forTesting(mockApiClient);
    // Default to authenticated
    FlutterSecureStorage.setMockInitialValues({'session_id': 'fake-session'});
  });

  group('TagRepository (authenticated)', () {
    group('getTags', () {
      test('returns tags converted from the server response', () async {
        when(() => mockTagsClient.getApiTags()).thenAnswer(
          (_) async => const [
            GetApiTagsResponse(
              id: 't1',
              userId: 'u1',
              name: 'Work',
              color: '#FF0000',
              createdAt: '2024-01-15T10:30:00.000Z',
            ),
            GetApiTagsResponse(
              id: 't2',
              userId: 'u1',
              name: 'Play',
              color: '#42A5F5',
              createdAt: '2024-01-16T12:00:00.000Z',
            ),
          ],
        );

        final tags = await repository.getTags();

        expect(tags.length, 2);
        expect(tags[0].id, 't1');
        expect(tags[0].name, 'Work');
        expect(tags[0].color, 0xFFFF0000);
        expect(tags[1].color, 0xFF42A5F5);
      });
    });

    group('createTag', () {
      test('posts hex-encoded color and returns parsed TagData', () async {
        when(() => mockTagsClient.postApiTags(body: any(named: 'body')))
            .thenAnswer(
          (_) async => const PostApiTagsResponse(
            id: 'new-1',
            userId: 'u1',
            name: 'Work',
            color: '#123456',
            createdAt: '2024-01-15T10:30:00.000Z',
          ),
        );

        final tag = await repository.createTag(
          name: 'Work',
          color: 0xFF123456,
        );

        expect(tag?.id, 'new-1');
        expect(tag?.name, 'Work');
        expect(tag?.color, 0xFF123456);

        final captured = verify(
          () => mockTagsClient.postApiTags(body: captureAny(named: 'body')),
        ).captured;
        final body = captured.single as ApiTagsRequestBody;
        expect(body.name, 'Work');
        expect(body.color, '#123456');
      });
    });

    group('updateTag', () {
      test('sends only name when color is null', () async {
        when(() => mockTagsClient.putApiTagsById(
              id: any(named: 'id'),
              body: any(named: 'body'),
            )).thenAnswer(
          (_) async => const PutApiTagsIdResponse(
            id: 't1',
            userId: 'u1',
            name: 'Renamed',
            color: '#FF0000',
            createdAt: '2024-01-15T10:30:00.000Z',
          ),
        );

        final updated = await repository.updateTag('t1', name: 'Renamed');
        expect(updated?.name, 'Renamed');

        final captured = verify(() => mockTagsClient.putApiTagsById(
              id: 't1',
              body: captureAny(named: 'body'),
            )).captured;
        final body = captured.single as ApiTagsIdRequestBody;
        expect(body.name, 'Renamed');
        expect(body.color, null);
      });

      test('sends only color when name is null', () async {
        when(() => mockTagsClient.putApiTagsById(
              id: any(named: 'id'),
              body: any(named: 'body'),
            )).thenAnswer(
          (_) async => const PutApiTagsIdResponse(
            id: 't1',
            userId: 'u1',
            name: 'Work',
            color: '#00FF00',
            createdAt: '2024-01-15T10:30:00.000Z',
          ),
        );

        final updated = await repository.updateTag('t1', color: 0xFF00FF00);
        expect(updated?.color, 0xFF00FF00);

        final captured = verify(() => mockTagsClient.putApiTagsById(
              id: 't1',
              body: captureAny(named: 'body'),
            )).captured;
        final body = captured.single as ApiTagsIdRequestBody;
        expect(body.name, null);
        expect(body.color, '#00FF00');
      });
    });

    group('deleteTag', () {
      test('calls deleteApiTagsById on the API client', () async {
        when(() => mockTagsClient.deleteApiTagsById(id: any(named: 'id')))
            .thenAnswer((_) async {});

        await repository.deleteTag('t1');

        verify(() => mockTagsClient.deleteApiTagsById(id: 't1')).called(1);
      });
    });

    group('uploadLocalTags', () {
      test('creates each tag and returns an id mapping', () async {
        final local1 = TagData.local(name: 'A', color: 0xFFFF0000);
        final local2 = TagData.local(name: 'B', color: 0xFF00FF00);

        when(() => mockTagsClient.postApiTags(body: any(named: 'body')))
            .thenAnswer((invocation) async {
          final body =
              invocation.namedArguments[const Symbol('body')] as ApiTagsRequestBody;
          return PostApiTagsResponse(
            id: 'srv-${body.name}',
            userId: 'u1',
            name: body.name,
            color: body.color,
            createdAt: '2024-01-15T10:30:00.000Z',
          );
        });

        final mapping = await repository.uploadLocalTags([local1, local2]);

        expect(mapping[local1.id], 'srv-A');
        expect(mapping[local2.id], 'srv-B');
        verify(() => mockTagsClient.postApiTags(body: any(named: 'body')))
            .called(2);
      });

      test('returns empty mapping when list is empty', () async {
        final mapping = await repository.uploadLocalTags([]);
        expect(mapping, isEmpty);
        verifyNever(() => mockTagsClient.postApiTags(body: any(named: 'body')));
      });
    });
  });

  group('TagRepository (unauthenticated)', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('getTags returns empty list without calling API', () async {
      final tags = await repository.getTags();
      expect(tags, isEmpty);
      verifyNever(() => mockTagsClient.getApiTags());
    });

    test('createTag returns null without calling API', () async {
      final tag =
          await repository.createTag(name: 'X', color: 0xFFFFFFFF);
      expect(tag, null);
      verifyNever(() => mockTagsClient.postApiTags(body: any(named: 'body')));
    });

    test('deleteTag does nothing', () async {
      await repository.deleteTag('t1');
      verifyNever(
          () => mockTagsClient.deleteApiTagsById(id: any(named: 'id')));
    });

    test('uploadLocalTags returns empty mapping', () async {
      final local = TagData.local(name: 'A', color: 0xFFFF0000);
      final mapping = await repository.uploadLocalTags([local]);
      expect(mapping, isEmpty);
      verifyNever(() => mockTagsClient.postApiTags(body: any(named: 'body')));
    });
  });
}
