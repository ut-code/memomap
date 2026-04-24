import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memomap/features/map/providers/current_map_provider.dart';
import 'package:memomap/features/map/providers/pin_provider.dart';

enum TagFilterMode { or, and }

class PinFilterState {
  final Set<String> selectedTagIds;
  final TagFilterMode mode;

  const PinFilterState({
    this.selectedTagIds = const {},
    this.mode = TagFilterMode.or,
  });

  PinFilterState copyWith({
    Set<String>? selectedTagIds,
    TagFilterMode? mode,
  }) {
    return PinFilterState(
      selectedTagIds: selectedTagIds ?? this.selectedTagIds,
      mode: mode ?? this.mode,
    );
  }
}

class PinFilterNotifier extends Notifier<PinFilterState> {
  @override
  PinFilterState build() {
    // Auto-clear when current map changes
    ref.listen(currentMapIdProvider, (prev, next) {
      if (prev != next) {
        state = const PinFilterState();
      }
    });
    return const PinFilterState();
  }

  void toggleTag(String tagId) {
    final newSet = Set<String>.from(state.selectedTagIds);
    if (newSet.contains(tagId)) {
      newSet.remove(tagId);
    } else {
      newSet.add(tagId);
    }
    state = state.copyWith(selectedTagIds: newSet);
  }

  void setMode(TagFilterMode mode) {
    state = state.copyWith(mode: mode);
  }

  void clear() {
    state = const PinFilterState();
  }
}

final pinFilterProvider =
    NotifierProvider<PinFilterNotifier, PinFilterState>(PinFilterNotifier.new);

final filteredPinsProvider = Provider<AsyncValue<List<PinData>>>((ref) {
  final pinsAsync = ref.watch(pinsProvider);
  final filter = ref.watch(pinFilterProvider);
  return pinsAsync.whenData((pins) {
    if (filter.selectedTagIds.isEmpty) return pins;
    return pins.where((p) {
      final tags = p.tagIds.toSet();
      if (filter.mode == TagFilterMode.and) {
        return filter.selectedTagIds.every(tags.contains);
      }
      return filter.selectedTagIds.any(tags.contains);
    }).toList();
  });
});
