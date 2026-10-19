import 'package:flutter/foundation.dart';

import '../core/models/models.dart';
import '../data/storage/file_store.dart';
import '../data/storage/local_store.dart';

enum LibrarySort { recent, title, artist }

/// Everything stored on this device: downloaded + imported tracks, favorites,
/// listening history and unlocked lyrics.
class LibraryRepository extends ChangeNotifier {
  LibraryRepository(this._store, this.files) {
    for (final v in _store.tracks.values) {
      final t = Track.fromJson(v as Map);
      _tracks[t.id] = t;
    }
  }

  final LocalStore _store;
  final FileStore files;
  final Map<String, Track> _tracks = {};

  /// Every file on the device (Downloads screen).
  List<Track> get tracks => _sorted(_tracks.values.toList(), LibrarySort.recent);

  /// Tracks shown in Library (see [Track.inLibrary]).
  List<Track> get libraryTracks => tracks.where((t) => t.inLibrary).toList();

  Future<void> setInLibrary(String id, bool v) async {
    final t = _tracks[id];
    if (t != null) await add(t.copyWith(inLibrary: v));
  }
  bool get isEmpty => _tracks.isEmpty;
  Track? byId(String id) => _tracks[id];
  bool contains(String id) => _tracks.containsKey(id);
  int get totalBytes => _tracks.values.fold(0, (a, t) => a + t.sizeBytes);

  List<Track> sorted(LibrarySort s) => _sorted(_tracks.values.where((t) => t.inLibrary).toList(), s);

  static List<Track> _sorted(List<Track> list, LibrarySort s) {
    switch (s) {
      case LibrarySort.recent:
        list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      case LibrarySort.title:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case LibrarySort.artist:
        list.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
    }
    return list;
  }

  List<Track> search(String q) {
    final s = q.toLowerCase().trim();
    if (s.isEmpty) return tracks;
    return tracks
        .where((t) => '${t.title} ${t.artist} ${t.album}'.toLowerCase().contains(s))
        .toList();
  }

  Map<String, List<Track>> get byArtist => _group((t) => t.artist);
  Map<String, List<Track>> get byAlbum => _group((t) => t.album.isEmpty ? 'Unknown album' : t.album);

  Map<String, List<Track>> _group(String Function(Track) key) {
    final m = <String, List<Track>>{};
    for (final t in sorted(LibrarySort.title)) {
      (m[key(t)] ??= []).add(t);
    }
    return Map.fromEntries(m.entries.toList()..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase())));
  }

  Future<void> add(Track t) async {
    _tracks[t.id] = t;
    await _store.tracks.put(t.id, t.toJson());
    notifyListeners();
  }

  Future<void> updateDuration(String id, Duration d) async {
    final t = _tracks[id];
    if (t == null || d == Duration.zero || (t.duration - d).abs() < const Duration(seconds: 1)) return;
    await add(t.copyWith(duration: d));
  }

  Future<void> remove(String id) async {
    final t = _tracks.remove(id);
    if (t == null) return;
    await files.delete(t.fileKey);
    await _store.tracks.delete(id);
    _favorites.remove(id);
    _recent.remove(id);
    await _saveMeta();
    notifyListeners();
  }

  Future<void> clearAll() async {
    await files.clear();
    await _store.tracks.clear();
    _tracks.clear();
    _favorites.clear();
    _recent.clear();
    await _saveMeta();
    notifyListeners();
  }

  // ---- favorites / recents / lyrics unlocks (stored in the meta box) ----
  late final List<String> _favorites = List<String>.from(_store.meta.get('favorites') as List? ?? const []);
  late final List<String> _recent = List<String>.from(_store.meta.get('recent') as List? ?? const []);
  late final Set<String> _unlocked = Set<String>.from(_store.meta.get('lyricsUnlocked') as List? ?? const []);

  Future<void> _saveMeta() async {
    await _store.meta.put('favorites', _favorites);
    await _store.meta.put('recent', _recent);
    await _store.meta.put('lyricsUnlocked', _unlocked.toList());
  }

  bool isFavorite(String id) => _favorites.contains(id);
  List<Track> get favorites => [for (final id in _favorites) ?_tracks[id]];

  Future<void> toggleFavorite(String id) async {
    _favorites.contains(id) ? _favorites.remove(id) : _favorites.insert(0, id);
    await _saveMeta();
    notifyListeners();
  }

  List<Track> get recentlyPlayed => [for (final id in _recent) ?_tracks[id]];

  Future<void> markPlayed(String id) async {
    if (!_tracks.containsKey(id)) return;
    _recent
      ..remove(id)
      ..insert(0, id);
    if (_recent.length > 30) _recent.removeRange(30, _recent.length);
    await _saveMeta();
    notifyListeners();
  }

  bool lyricsUnlocked(String id) => _unlocked.contains(id);
  Future<void> unlockLyrics(String id) async {
    _unlocked.add(id);
    await _saveMeta();
    notifyListeners();
  }
}
