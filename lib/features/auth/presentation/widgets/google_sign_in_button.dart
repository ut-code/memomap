import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memomap/features/auth/providers/auth_provider.dart';

import 'google_sign_in_button_stub.dart'
    if (dart.library.js_interop) 'google_sign_in_button_web.dart' as platform;

class GoogleSignInButton extends ConsumerStatefulWidget {
  const GoogleSignInButton({super.key});

  @override
  ConsumerState<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends ConsumerState<GoogleSignInButton> {
  bool _isLoading = false;
  bool _webInitialized = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _initWeb();
    }
  }

  Future<void> _initWeb() async {
    await platform.ensureInitialized();
    platform.setupWebAuth((idToken) async {
      if (!mounted) return;
      setState(() => _isLoading = true);
      try {
        final repo = await ref.read(authRepositoryProvider.future);
        await repo.signInWithGoogleIdToken(idToken);
        ref.invalidate(sessionProvider);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Google sign-in failed: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    });
    if (mounted) {
      setState(() => _webInitialized = true);
    }
  }

  Future<void> _handleMobileSignIn() async {
    await ref.read(googleAuthProvider.notifier).signIn();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(googleAuthProvider);
    final isLoading = _isLoading || authState.isLoading;

    if (kIsWeb) {
      if (!_webInitialized || isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return platform.buildGoogleButton();
    }

    // Mobile
    return OutlinedButton.icon(
      onPressed: isLoading ? null : _handleMobileSignIn,
      icon: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.g_mobiledata, size: 24),
      label: const Text('Sign in with Google'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
    );
  }
}
