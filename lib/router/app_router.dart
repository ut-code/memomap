import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memomap/features/auth/presentation/login_screen.dart';
import 'package:memomap/features/auth/providers/auth_provider.dart';
import 'package:memomap/features/map/presentation/map_screen.dart';
import 'package:memomap/features/profile/presentation/profile_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(sessionProvider);

  bool? isAuthenticated() {
    return session.when(
      data: (result) => result != null,
      loading: () => null,
      error: (_, _) => false,
    );
  }

  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const MapScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
        redirect: (context, state) {
          final auth = isAuthenticated();
          if (auth == null) return null;
          return auth ? '/' : null;
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
        redirect: (context, state) {
          final auth = isAuthenticated();
          if (auth == null) return null;
          return auth ? null : '/login';
        },
      ),
      GoRoute(
        path: '/auth-callback',
        builder: (context, state) => const AuthCallbackScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
});

class AuthCallbackScreen extends ConsumerStatefulWidget {
  const AuthCallbackScreen({super.key});

  @override
  ConsumerState<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends ConsumerState<AuthCallbackScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(sessionProvider);
      context.go('/');
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
