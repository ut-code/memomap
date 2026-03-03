import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

abstract interface class NetworkCheckerBase {
  Future<bool> get isOnline;
  Stream<bool> get onConnectivityChanged;
}

class ConnectivityPlusNetworkChecker implements NetworkCheckerBase {
  final Connectivity _connectivity;

  ConnectivityPlusNetworkChecker({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  @override
  Future<bool> get isOnline async {
    final results = await _connectivity.checkConnectivity();
    return _hasConnection(results);
  }

  @override
  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map(_hasConnection);
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((result) =>
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.ethernet);
  }
}
