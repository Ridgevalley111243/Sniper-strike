import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/models/models.dart';
import '../core/util/format.dart';
import '../sources/music_source.dart';
import '../sources/source_manager.dart';

class SearchFilters {
  const SearchFilters({this.downloadableOnly = false, this.genre});
  final bool downloadableOnly;
  final String? genre;
  bool get isActive => downloadableOnly || genre != null;
}

/// Centralized search state + the multi-source search engine:
/// SEARCH → SOURCE MANAGER → parallel adapters → NORMALIZE → GROUP → UI.
class MusicSearchController extends ChangeNotifier {
  MusicSearchController(this._sources);

  final SourceManager _sources;
  static const _timeout = Duration(seconds: 8);
  static const _cacheTtl = Duration(minutes: 5);

  String query = '';
  String? sourceFilter; // null = all enabled sources
  SearchFilters filters = const SearchFilters();
  bool hasSearched = false;
  final Set<String> loading = {};
  final Map<String, String> failed = {};
  final Set<String> responded = {};
  final Map<String, List<SourceTrack>> _raw = {};
  List<TrackGroup> _groups = const [];

  Timer? _debounce;
  int _generation = 0;
  final Map<String, (DateTime, List<SourceTrack>)> _cache = {};

  List<MusicSource> get searchedSources =>
      _sources.enabled.where((s) => s.capabilities.search && (sourceFilter == null || s.id == sourceFilter)).toList();

  bool get isLoading => loading.isNotEmpty;

  List<TrackGroup> get results {
    return _groups.where((g) {
      if (filters.downloadableOnly && !g.canDownload) return false;
      if (filters.genre != null && g.genre != filters.genre) return false;
      return true;
    }).toList();
  }

  Set<String> get genres => {for (final g in _groups) ?g.genre};

  void onQueryChanged(String q) {
    query = q;
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      _reset();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), run);
    notifyListeners();
  }

  void setSourceFilter(String? id) {
    sourceFilter = id;
    if (query.trim().isNotEmpty) run();
    notifyListeners();
  }

  void setFilters(SearchFilters f) {
    filters = f;
    notifyListeners();
  }

  void _reset() {
    _generation++;
    hasSearched = false;
    loading.clear();
    failed.clear();
    responded.clear();
    _raw.clear();
    _groups = const [];
    notifyListeners();
  }

  /// Runs (or re-runs) the current query against every selected source.
  Future<void> run() async {
    _debounce?.cancel();
    final q = query.trim();
    if (q.isEmpty) return _reset();
    final gen = ++_generation;
    hasSearched = true;
    failed.clear();
    responded.clear();
    _raw.clear();
    _groups = const [];
    final targets = searchedSources;
    loading
      ..clear()
      ..addAll(targets.map((s) => s.id));
    notifyListeners();
    await Future.wait(targets.map((s) => _searchOne(s, q, gen)));
  }

  Future<void> retry(String sourceId) async {
    final s = _sources.byId(sourceId);
    if (s == null || query.trim().isEmpty) return;
    failed.remove(sourceId);
    loading.add(sourceId);
    notifyListeners();
    await _searchOne(s, query.trim(), _generation);
  }

  Future<void> _searchOne(MusicSource s, String q, int gen) async {
    final cacheKey = '${s.id}|${normalizeForMatch(q)}';
    try {
      final cached = _cache[cacheKey];
      final List<SourceTrack> hits;
      if (cached != null && DateTime.now().difference(cached.$1) < _cacheTtl) {
        hits = cached.$2;
      } else {
        hits = await s.search(q).timeout(_timeout);
        _cache[cacheKey] = (DateTime.now(), hits);
      }
      if (gen != _generation) return; // a newer search started — drop stale results
      _raw[s.id] = hits;
      responded.add(s.id);
      _sources.reportHealth(s.id, true);
    } catch (e) {
      if (gen != _generation) return;
      failed[s.id] = e is TimeoutException ? 'took too long to respond' : 'is unavailable right now';
      _sources.reportHealth(s.id, false);
    } finally {
      if (gen == _generation) {
        loading.remove(s.id);
        _groups = groupResults(_raw.values.expand((x) => x).toList(), q);
        notifyListeners();
      }
    }
  }

  /// Normalizes and groups duplicate recordings across sources, then ranks.
  static List<TrackGroup> groupResults(List<SourceTrack> hits, String q) {
    final groups = <String, List<SourceTrack>>{};
    for (final h in hits) {
      final base = '${normalizeForMatch(h.title)}|${normalizeForMatch(h.artist)}';
      // Same title + artist but clearly different length = different recording.
      var key = base;
      var i = 0;
      while (groups.containsKey(key) && (groups[key]!.first.duration - h.duration).abs() > const Duration(seconds: 3)) {
        key = '$base#${++i}';
      }
      (groups[key] ??= []).add(h);
    }
    final nq = normalizeForMatch(q);
    int score(TrackGroup g) {
      final t = normalizeForMatch(g.title);
      var s = 0;
      if (t == nq) s += 100;
      if (t.startsWith(nq)) s += 50;
      if (t.contains(nq)) s += 20;
      if (normalizeForMatch(g.artist).contains(nq)) s += 10;
      s += g.sources.length * 5;
      if (g.canDownload) s += 3;
      return s;
    }

    final list = [
      for (final e in groups.entries)
        TrackGroup(e.key, e.value..sort((a, b) => _rank(b).compareTo(_rank(a)))),
    ];
    // Deterministic order so rows don't jump around as sources respond.
    list.sort((a, b) {
      final d = score(b).compareTo(score(a));
      return d != 0 ? d : a.key.compareTo(b.key);
    });
    return list;
  }

  // Prefer sources that can do more (download > preview > search only).
  static int _rank(SourceTrack s) => (s.downloadAvailable ? 4 : 0) + (s.previewAvailable ? 2 : 0) + (s.lyricsAvailable ? 1 : 0);

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
