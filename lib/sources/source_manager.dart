import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend_source.dart';
import 'demo/demo_source.dart';
import 'music_source.dart';

/// Registry of music sources: which exist, which the user enabled, and how
/// healthy each one is. Adding a provider means registering one more
/// [MusicSource] here — nothing else in the app changes.
class SourceManager extends ChangeNotifier {
  SourceManager(this._prefs) {
    _sources.addAll(buildDemoSources());
    final url = backendUrl;
    if (url != null) _sources.add(BackendSource(url));
    final saved = _prefs.getStringList(_kEnabled);
    // With real providers available, a fresh install starts on them; the
    // demo sources stay one switch away in Manage Sources.
    _enabled = saved?.toSet() ?? (url != null ? {'backend'} : {for (final s in _sources) s.id});
    // Sources added since the last launch (e.g. a newly bundled backend) start enabled.
    final known = _prefs.getStringList(_kKnown);
    if (known != null) _enabled.addAll(_sources.map((s) => s.id).where((id) => !known.contains(id)));
    _prefs.setStringList(_kKnown, [for (final s in _sources) s.id]);
    _prefs.setStringList(_kEnabled, _enabled.toList());
  }

  static const _kEnabled = 'sources.enabled';
  static const _kBackend = 'sources.backendUrl';
  static const _kKnown = 'sources.known';

  /// Backend bundled at build time: `--dart-define=TRUHIVE_BACKEND_URL=...`.
  static const _defaultBackend = String.fromEnvironment('TRUHIVE_BACKEND_URL');

  final SharedPreferences _prefs;
  final List<MusicSource> _sources = [];
  late Set<String> _enabled;
  final Map<String, SourceHealth> _health = {};
  final Map<String, DateTime> _checkedAt = {};

  List<MusicSource> get all => List.unmodifiable(_sources);
  List<MusicSource> get enabled => _sources.where((s) => _enabled.contains(s.id)).toList();
  bool isEnabled(String id) => _enabled.contains(id);
  SourceHealth health(String id) => _health[id] ?? SourceHealth.unknown;
  DateTime? checkedAt(String id) => _checkedAt[id];
  /// The user's choice wins; an empty string means they disconnected it.
  String? get backendUrl {
    final url = _prefs.getString(_kBackend) ?? _defaultBackend;
    return url.isEmpty ? null : url;
  }

  MusicSource? byId(String id) {
    for (final s in _sources) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<void> setEnabled(String id, bool on) async {
    on ? _enabled.add(id) : _enabled.remove(id);
    await _prefs.setStringList(_kEnabled, _enabled.toList());
    notifyListeners();
  }

  /// Search results report availability as a side effect, so the Source
  /// Manager stays current without extra network calls.
  void reportHealth(String id, bool ok) {
    _health[id] = ok ? SourceHealth.available : SourceHealth.unavailable;
    _checkedAt[id] = DateTime.now();
    notifyListeners();
  }

  Future<void> check(String id) async {
    final s = byId(id);
    if (s == null) return;
    _health[id] = SourceHealth.checking;
    notifyListeners();
    reportHealth(id, await s.ping());
  }

  Future<void> checkAll() => Future.wait([for (final s in _sources) check(s.id)]);

  /// Connect (or disconnect, with an empty url) a TRUHive backend.
  Future<void> setBackendUrl(String url) async {
    _sources.removeWhere((s) => s is BackendSource);
    final clean = url.trim();
    if (clean.isEmpty) {
      await _prefs.setString(_kBackend, '');
    } else {
      await _prefs.setString(_kBackend, clean);
      _sources.add(BackendSource(clean));
      _enabled.add('backend');
      await _prefs.setStringList(_kEnabled, _enabled.toList());
      check('backend');
    }
    notifyListeners();
  }
}
