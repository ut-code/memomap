import 'package:memomap/features/map/data/local_pin_storage.dart';
import 'package:memomap/features/map/data/network_checker.dart';
import 'package:memomap/features/map/data/pin_repository_base.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalPinStorage extends Mock implements LocalPinStorageBase {}

class MockNetworkChecker extends Mock implements NetworkCheckerBase {}

class MockPinRepository extends Mock implements PinRepositoryBase {}
