import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memomap/features/auth/data/auth_repository.dart';

final authRepositoryProvider = FutureProvider<AuthRepository>((ref) async {
  return AuthRepository.getInstance();
});

final sessionProvider = FutureProvider<SessionResponse?>((ref) async {
  final authRepository = await ref.watch(authRepositoryProvider.future);
  return authRepository.getSession();
});

final currentUserProvider = Provider<User?>((ref) {
  final session = ref.watch(sessionProvider);
  return session.valueOrNull?.user;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  final session = ref.watch(sessionProvider);
  final result = session.valueOrNull;
  return result != null;
});

final emailAuthProvider =
    AutoDisposeAsyncNotifierProvider<EmailAuthNotifier, void>(
  EmailAuthNotifier.new,
);

class EmailAuthNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() => null;

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = await ref.read(authRepositoryProvider.future);
      await repo.signInWithEmail(email: email, password: password);
      ref.invalidate(sessionProvider);
    });
  }

  Future<void> signUp(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = await ref.read(authRepositoryProvider.future);
      await repo.signUpWithEmail(email: email, password: password);
      ref.invalidate(sessionProvider);
    });
  }
}

final googleAuthProvider =
    AutoDisposeAsyncNotifierProvider<GoogleAuthNotifier, void>(
  GoogleAuthNotifier.new,
);

class GoogleAuthNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() => null;

  Future<void> signIn() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = await ref.read(authRepositoryProvider.future);
      await repo.signInWithGoogle();
      ref.invalidate(sessionProvider);
    });
  }
}
