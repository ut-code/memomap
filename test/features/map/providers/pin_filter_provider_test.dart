import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:memomap/features/map/providers/current_map_provider.dart';
import 'package:memomap/features/map/providers/pin_filter_provider.dart';
import 'package:memomap/features/map/providers/pin_provider.dart';

/// Minimal fake notifier for currentMapIdProvider to avoid loading
/// the real CurrentMapIdNotifier's map repository dependencies.
class _FakeCurrentMapIdNotifier extends StateNotifier<String?>
    implements CurrentMapIdNotifier {
  _FakeCurrentMapIdNotifier(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Minimal fake AsyncNotifier for pinsProvider that returns a preset state.
class _FakePinsNotifier extends AsyncNotifier<List<PinData>>
    implements PinsNotifier {
  _FakePinsNotifier(this._initial);

  final AsyncValue<List<PinData>> _initial;

  @override
  Future<List<PinData>> build() async {
    state = _initial;
    return _initial.valueOrNull ?? [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PinData _pin(String id, List<String> tagIds) {
  return PinData(
    id: id,
    userId: 'user-1',
    position: const LatLng(35.0, 139.0),
    createdAt: DateTime.utc(2024, 1, 1),
    isLocal: false,
    tagIds: tagIds,
  );
}

ProviderContainer _container({
  AsyncValue<List<PinData>> pinsState =
      const AsyncValue<List<PinData>>.data([]),
  String? mapId = 'map-1',
}) {
  return ProviderContainer(
    overrides: [
      currentMapIdProvider
          .overrideWith((ref) => _FakeCurrentMapIdNotifier(mapId)),
      pinsProvider.overrideWith(() => _FakePinsNotifier(pinsState)),
    ],
  );
}

void main() {
  group('PinFilterNotifier', () {
    test('initial state is empty selection and or mode', () {
      final container = _container();
      addTearDown(container.dispose);

      final state = container.read(pinFilterProvider);
      expect(state.selectedTagIds, isEmpty);
      expect(state.mode, TagFilterMode.or);
    });

    test('toggleTag adds tag when not present', () {
      final container = _container();
      addTearDown(container.dispose);

      container.read(pinFilterProvider.notifier).toggleTag('tag-1');

      expect(container.read(pinFilterProvider).selectedTagIds, {'tag-1'});
    });

    test('toggleTag removes tag when already present', () {
      final container = _container();
      addTearDown(container.dispose);

      final notifier = container.read(pinFilterProvider.notifier);
      notifier.toggleTag('tag-1');
      notifier.toggleTag('tag-1');

      expect(container.read(pinFilterProvider).selectedTagIds, isEmpty);
    });

    test('toggleTag with multiple tags builds correct set', () {
      final container = _container();
      addTearDown(container.dispose);

      final notifier = container.read(pinFilterProvider.notifier);
      notifier.toggleTag('a');
      notifier.toggleTag('b');
      notifier.toggleTag('c');
      notifier.toggleTag('b');

      expect(container.read(pinFilterProvider).selectedTagIds, {'a', 'c'});
    });

    test('setMode updates the filter mode', () {
      final container = _container();
      addTearDown(container.dispose);

      container.read(pinFilterProvider.notifier).setMode(TagFilterMode.and);

      expect(container.read(pinFilterProvider).mode, TagFilterMode.and);
    });

    test('clear resets to initial state', () {
      final container = _container();
      addTearDown(container.dispose);

      final notifier = container.read(pinFilterProvider.notifier);
      notifier.toggleTag('a');
      notifier.setMode(TagFilterMode.and);
      notifier.clear();

      final state = container.read(pinFilterProvider);
      expect(state.selectedTagIds, isEmpty);
      expect(state.mode, TagFilterMode.or);
    });

    test('auto-clears when currentMapIdProvider changes', () {
      final container = _container(mapId: 'map-1');
      addTearDown(container.dispose);

      final notifier = container.read(pinFilterProvider.notifier);
      notifier.toggleTag('a');
      notifier.setMode(TagFilterMode.and);

      // Trigger rebuild by changing currentMapIdProvider state.
      (container.read(currentMapIdProvider.notifier) as StateNotifier<String?>)
          .state = 'map-2';

      final state = container.read(pinFilterProvider);
      expect(state.selectedTagIds, isEmpty);
      expect(state.mode, TagFilterMode.or);
    });
  });

  group('filteredPinsProvider', () {
    final pinA = _pin('a', ['t1', 't2']);
    final pinB = _pin('b', ['t2', 't3']);
    final pinC = _pin('c', ['t3']);
    final pinD = _pin('d', const []);

    test('returns all pins when no filter selected', () {
      final container = _container(
        pinsState: AsyncValue.data([pinA, pinB, pinC, pinD]),
      );
      addTearDown(container.dispose);

      final filtered = container.read(filteredPinsProvider);
      expect(filtered.value?.length, 4);
    });

    test('or mode: returns pins matching any selected tag', () {
      final container = _container(
        pinsState: AsyncValue.data([pinA, pinB, pinC, pinD]),
      );
      addTearDown(container.dispose);

      container.read(pinFilterProvider.notifier).toggleTag('t1');
      container.read(pinFilterProvider.notifier).toggleTag('t3');

      final filtered = container.read(filteredPinsProvider).value!;
      expect(filtered.map((p) => p.id).toSet(), {'a', 'b', 'c'});
    });

    test('and mode: returns pins matching all selected tags', () {
      final container = _container(
        pinsState: AsyncValue.data([pinA, pinB, pinC, pinD]),
      );
      addTearDown(container.dispose);

      container.read(pinFilterProvider.notifier).setMode(TagFilterMode.and);
      container.read(pinFilterProvider.notifier).toggleTag('t2');
      container.read(pinFilterProvider.notifier).toggleTag('t3');

      final filtered = container.read(filteredPinsProvider).value!;
      expect(filtered.map((p) => p.id).toList(), ['b']);
    });

    test('pins without matching tags are excluded when filtering', () {
      final container = _container(
        pinsState: AsyncValue.data([pinA, pinD]),
      );
      addTearDown(container.dispose);

      container.read(pinFilterProvider.notifier).toggleTag('t1');

      final filtered = container.read(filteredPinsProvider).value!;
      expect(filtered.map((p) => p.id).toList(), ['a']);
    });

    test('loading state propagates', () {
      final container = _container(
        pinsState: const AsyncValue<List<PinData>>.loading(),
      );
      addTearDown(container.dispose);

      final filtered = container.read(filteredPinsProvider);
      expect(filtered.isLoading, true);
    });

    test('error state propagates', () {
      final container = _container(
        pinsState: AsyncValue<List<PinData>>.error(
          Exception('boom'),
          StackTrace.empty,
        ),
      );
      addTearDown(container.dispose);

      final filtered = container.read(filteredPinsProvider);
      expect(filtered.hasError, true);
    });
  });
}
