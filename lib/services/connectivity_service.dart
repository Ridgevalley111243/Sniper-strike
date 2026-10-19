import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Tracks whether the internet is reachable. Only discovery (search, preview,
/// download, lyrics) needs it — local playback keeps working offline.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService() {
    _sub = _c.onConnectivityChanged.listen(_apply);
    _c.checkConnectivity().then(_apply).catchError((_) {});
  }

  final _c = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  List<ConnectivityResult> _state = const [ConnectivityResult.wifi];

  bool get isOnline => !_state.every((r) => r == ConnectivityResult.none);
  bool get onWifi => _state.any((r) => r == ConnectivityResult.wifi || r == ConnectivityResult.ethernet);

  void _apply(List<ConnectivityResult> r) {
    if (listEquals(r, _state)) return;
    _state = r;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
