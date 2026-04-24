import 'package:memomap/api/api_client.dart';
import 'package:memomap/api/clients/tags_client.dart';
import 'package:memomap/features/map/data/drawing_repository_base.dart';
import 'package:memomap/features/map/data/local_drawing_storage.dart';
import 'package:memomap/features/map/data/local_map_storage.dart';
import 'package:memomap/features/map/data/local_pin_storage.dart';
import 'package:memomap/features/map/data/local_tag_storage.dart';
import 'package:memomap/features/map/data/map_repository.dart';
import 'package:memomap/features/map/data/network_checker.dart';
import 'package:memomap/features/map/data/pin_repository_base.dart';
import 'package:memomap/features/map/data/tag_repository.dart';
import 'package:memomap/features/map/services/tag_sync_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalPinStorage extends Mock implements LocalPinStorageBase {}

class MockNetworkChecker extends Mock implements NetworkCheckerBase {}

class MockPinRepository extends Mock implements PinRepositoryBase {}

class MockLocalDrawingStorage extends Mock implements LocalDrawingStorageBase {}

class MockDrawingRepository extends Mock implements DrawingRepositoryBase {}

class MockLocalMapStorage extends Mock implements LocalMapStorageBase {}

class MockMapRepository extends Mock implements MapRepositoryBase {}

class MockLocalTagStorage extends Mock implements LocalTagStorageBase {}

class MockTagRepository extends Mock implements TagRepositoryBase {}

class MockTagSyncService extends Mock implements TagSyncService {}

class MockApiClient extends Mock implements ApiClient {}

class MockTagsClient extends Mock implements TagsClient {}
