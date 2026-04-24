import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memomap/features/auth/providers/auth_provider.dart';
import 'package:memomap/features/map/data/local_tag_storage.dart';
import 'package:memomap/features/map/data/tag_repository.dart';
import 'package:memomap/features/map/providers/pin_provider.dart'
    show networkCheckerProvider, pinsProvider;
import 'package:memomap/features/map/services/tag_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:memomap/features/map/data/tag_repository.dart' show TagData;

final localTagStorageProvider = Provider<LocalTagStorageBase>((ref) {
  final prefs = SharedPreferencesAsync();
  return SharedPreferencesLocalTagStorage(prefs);
});

final tagRepositoryProvider = FutureProvider<TagRepository>((ref) async {
  return TagRepository.getInstance();
});

final tagSyncServiceProvider = FutureProvider<TagSyncService>((ref) async {
  final storage = ref.watch(localTagStorageProvider);
  final networkChecker = ref.watch(networkCheckerProvider);
  final repository = await ref.watch(tagRepositoryProvider.future);

  return TagSyncService(
    storage: storage,
    networkChecker: networkChecker,
    repository: repository,
  );
});

/// Mapping of old local→new server tag IDs from the last sync.
final tagIdMappingProvider = StateProvider<Map<String, String>>((ref) => {});

final tagsProvider = AsyncNotifierProvider<TagsNotifier, List<TagData>>(() {
  return TagsNotifier();
});

class TagsNotifier extends AsyncNotifier<List<TagData>> {
  @override
  Future<List<TagData>> build() async {
    ref.listen(sessionProvider, (prev, next) {
      final prevUserId = prev?.valueOrNull?.user.id;
      final nextUserId = next.valueOrNull?.user.id;
      if (prevUserId != nextUserId) {
        ref.invalidateSelf();
      }
    });

    final syncService = await ref.watch(tagSyncServiceProvider.future);
    final session = ref.read(sessionProvider).valueOrNull;
    final currentUserId = session?.user.id;
    final isAuthenticated = ref.read(isAuthenticatedProvider);

    await syncService.clearIfUserChanged(currentUserId);

    final cached = await syncService.getAllTags();
    state = AsyncValue.data(cached);

    if (isAuthenticated) {
      _syncInBackground(syncService);
    }

    return cached;
  }

  Future<void> _syncInBackground(TagSyncService syncService) async {
    try {
      final idMapping = await syncService.syncWithServer();
      if (idMapping.isNotEmpty) {
        ref.read(tagIdMappingProvider.notifier).state = idMapping;
      }
      final fresh = await syncService.getAllTags();
      state = AsyncValue.data(fresh);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Tag background sync failed: $e\n$st');
      }
    }
  }

  Future<TagData?> createTag({required String name, required int color}) async {
    final isAuthenticated = ref.read(isAuthenticatedProvider);
    final syncService = await ref.read(tagSyncServiceProvider.future);

    try {
      final created = await syncService.createTag(
        name: name,
        color: color,
        isAuthenticated: isAuthenticated,
      );
      state = AsyncValue.data([created, ...(state.value ?? [])]);
      return created;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Failed to create tag: $e\n$st');
      }
      rethrow;
    }
  }

  Future<TagData?> updateTag(TagData tag, {String? name, int? color}) async {
    final isAuthenticated = ref.read(isAuthenticatedProvider);
    final syncService = await ref.read(tagSyncServiceProvider.future);

    try {
      final updated = await syncService.updateTag(
        tag: tag,
        name: name,
        color: color,
        isAuthenticated: isAuthenticated,
      );
      if (updated != null) {
        state = AsyncValue.data(
          (state.value ?? []).map((t) => t.id == updated.id ? updated : t).toList(),
        );
      }
      return updated;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Failed to update tag: $e\n$st');
      }
      rethrow;
    }
  }

  Future<void> deleteTag(TagData tag) async {
    final isAuthenticated = ref.read(isAuthenticatedProvider);
    final syncService = await ref.read(tagSyncServiceProvider.future);

    state = AsyncValue.data(
      (state.value ?? []).where((t) => t.id != tag.id).toList(),
    );

    try {
      await syncService.deleteTag(tag: tag, isAuthenticated: isAuthenticated);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Failed to delete tag: $e\n$st');
      }
    }

    // Drop this tag ID from any cached pin's tagIds in the pins provider state.
    ref.read(pinsProvider.notifier).removeTagFromAllPins(tag.id);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}
