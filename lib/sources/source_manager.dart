import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'backend_source.dart';
import 'demo/demo_source.dart';
import 'music_source.dart';

/// Registry of music sources: which exist, which the user enabled, and how
/// healthy each one is. Adding a provider means registering one more
/// [MusicSource] here — nothing else in the app changes.
///
/// With a backend connected, each provider it offers is a source of its own;
/// without one, the app runs on the offline demo sources.
class SourceManager extends ChangeNotifier {
  SourceManager(this._prefs, {this.client}) {
    _register();
    final saved = _prefs.getStringList(_kEnabled);
    _enabled = saved?.toSet() ?? {for (final s in _sources) s.id};
    _enableNewSources();
    if (backendUrl != null) refreshProviders();
  }

  static const _kEnabled = 'sources.enabled';
  static const _kBackend = 'sources.backendUrl';
  static const _kKnown = 'sources.known';
  static const _kProviders = 'sources.backendProviders';

  /// Backend bundled at build time: `--dart-define=TRUHIVE_BACKEND_URL=...`.
  static const _defaultBackend = String.fromEnvironment('TRUHIVE_BACKEND_URL');

  /// Used until the backend's own list has been fetched once.
  static const _fallbackProviders = [
    BackendProvider(id: 'jm', name: 'Jamendo', description: 'Independent artists · Creative Commons', download: true, lyrics: true),
    BackendProvider(id: 'au', name: 'Audius', description: 'Independent artists · hip-hop, electronic, Afrobeats', download: true),
    BackendProvider(
      id: 'ia',
      name: 'Internet Archive',
      description: 'Public domain, Creative Commons and live concert recordings',
      download: true,
    ),
    BackendProvider(id: 'it', name: 'Apple Music', description: 'Mainstream catalogue · 30-second previews', lyrics: true),
  ];

  final SharedPreferences _prefs;

  /// HTTP client for backend sources (tests inject a fake one).
  final http.Client? client;
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
    // Songs saved before the backend was split per provider: any backend
    // source can still serve them, since track ids name their provider.
    if (id == 'backend') return _sources.whereType<BackendSource>().firstOrNull;
    return null;
  }

  void _register() {
    _sources.clear();
    final url = backendUrl;
    if (url == null) {
      _sources.addAll(buildDemoSources());
      return;
    }
    for (final p in _cachedProviders()) {
      _sources.add(BackendSource(url, provider: p, client: client));
    }
  }

  List<BackendProvider> _cachedProviders() {
    final raw = _prefs.getString(_kProviders);
    if (raw == null) return _fallbackProviders;
    try {
      return [for (final j in (jsonDecode(raw) as List).cast<Map<String, dynamic>>()) BackendProvider.fromJson(j)];
    } catch (_) {
      return _fallbackProviders;
    }
  }

  /// Sources that appeared since the last launch start enabled.
  void _enableNewSources() {
    final known = _prefs.getStringList(_kKnown);
    if (known != null) _enabled.addAll(_sources.map((s) => s.id).where((id) => !known.contains(id)));
    _prefs.setStringList(_kKnown, {...?known, for (final s in _sources) s.id}.toList());
    _prefs.setStringList(_kEnabled, _enabled.toList());
  }

  /// Picks up providers the backend added or removed since last time.
  Future<void> refreshProviders() async {
    final url = backendUrl;
    if (url == null) return;
    try {
      final providers = await BackendSource.fetchProviders(url, client: client);
      if (providers.isEmpty || backendUrl != url) return;
      await _prefs.setString(_kProviders, jsonEncode([for (final p in providers) p.toJson()]));
      _register();
      _enableNewSources();
      notifyListeners();
    } catch (_) {
      // Offline or unreachable: keep the providers we already know.
    }
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
    final clean = url.trim();
    await _prefs.setString(_kBackend, clean);
    await _prefs.remove(_kProviders);
    _register();
    _enableNewSources();
    notifyListeners();
    if (clean.isNotEmpty) {
      await refreshProviders();
      checkAll();
    }
  }
}
