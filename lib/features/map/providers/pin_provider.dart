import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:memomap/features/auth/data/token_storage.dart';
import 'package:memomap/features/auth/providers/auth_provider.dart';
import 'package:memomap/features/map/data/pin_repository.dart';

export 'package:memomap/features/map/data/pin_repository.dart' show PinData;

final localPinsProvider = StateProvider<List<PinData>>((ref) => []);

final pinRepositoryProvider = FutureProvider<PinRepository>((ref) async {
  return PinRepository.getInstance();
});

final pinsProvider = AsyncNotifierProvider<PinsNotifier, List<PinData>>(() {
  return PinsNotifier();
});

class PinsNotifier extends AsyncNotifier<List<PinData>> {
  @override
  Future<List<PinData>> build() async {
    ref.listen(sessionProvider, (prev, next) {
      final prevUserId = prev?.valueOrNull?.user.id;
      final nextUserId = next.valueOrNull?.user.id;
      if (prevUserId != nextUserId) {
        ref.invalidateSelf();
      }
    });

    final token = await TokenStorage.getSessionId();
    final repository = await ref.watch(pinRepositoryProvider.future);
    final localPins = ref.read(localPinsProvider);

    if (token != null) {
      return _syncAndLoadPins(repository, localPins);
    }
    return localPins;
  }

  Future<List<PinData>> _syncAndLoadPins(
    PinRepository repository,
    List<PinData> localPins,
  ) async {
    if (localPins.isNotEmpty) {
      try {
        await repository.uploadLocalPins(localPins);
        ref.read(localPinsProvider.notifier).state = [];
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('Failed to sync local pins: $e\n$st');
        }
      }
    }

    return repository.getPins();
  }

  Future<void> addPin(LatLng position) async {
    final isAuthenticated = ref.read(isAuthenticatedProvider);
    final optimisticPin = PinData.local(position);
    final previous = state.value ?? [];

    if (isAuthenticated) {
      state = AsyncValue.data([optimisticPin, ...previous]);

      try {
        final repository = await ref.read(pinRepositoryProvider.future);
        final realPin = await repository.addPin(position);
        if (realPin != null) {
          state = AsyncValue.data(
            state.value!.map((p) => p.id == optimisticPin.id ? realPin : p).toList(),
          );
        }
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('Failed to add pin: $e\n$st');
        }
        state = AsyncValue.data(previous);
      }
    } else {
      ref.read(localPinsProvider.notifier).state = [
        optimisticPin,
        ...ref.read(localPinsProvider),
      ];
      state = AsyncValue.data([optimisticPin, ...previous]);
    }
  }

  Future<void> deletePin(String id) async {
    final pin = state.value?.where((p) => p.id == id).firstOrNull;
    if (pin == null) return;

    if (pin.isLocal) {
      ref.read(localPinsProvider.notifier).state =
          ref.read(localPinsProvider).where((p) => p.id != id).toList();
    } else {
      final repository = await ref.read(pinRepositoryProvider.future);
      await repository.deletePin(id);
    }

    state = AsyncValue.data(
      (state.value ?? []).where((p) => p.id != id).toList(),
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}
