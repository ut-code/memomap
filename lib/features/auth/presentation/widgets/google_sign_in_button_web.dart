import 'package:flutter/material.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart';

final _plugin = GoogleSignInPlugin();
final _initFuture = _plugin.init();

Future<void> ensureInitialized() => _initFuture;

Widget buildGoogleButton() {
  return _plugin.renderButton();
}

void setupWebAuth(void Function(String idToken) onIdToken) {
  _plugin.userDataEvents?.listen((userData) {
    if (userData != null && userData.idToken != null) {
      onIdToken(userData.idToken!);
    }
  });
}
