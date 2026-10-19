import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/models/models.dart';
import '../data/storage/local_store.dart';

/// Local playlists. Nothing is synchronized anywhere.
class PlaylistRepository extends ChangeNotifier {
  PlaylistRepository(this._store) {
    for (final v in _store.playlists.values) {
      final p = Playlist.fromJson(v as Map);
      _items[p.id] = p;
    }
  }

  final LocalStore _store;
  final Map<String, Playlist> _items = {};
  final _rng = Random();

  List<Playlist> get all => _items.values.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  Playlist? byId(String id) => _items[id];

  static const starterNames = ['Workout', 'Chill', 'Gospel', 'Afrobeats'];

  Future<void> _put(Playlist p) async {
    _items[p.id] = p;
    await _store.playlists.put(p.id, p.toJson());
    notifyListeners();
  }

  Future<Playlist> create(String name, {List<String> trackIds = const []}) async {
    final now = DateTime.now();
    final p = Playlist(
      id: 'pl_${now.microsecondsSinceEpoch}_${_rng.nextInt(1 << 20)}',
      name: name.trim().isEmpty ? 'New playlist' : name.trim(),
      trackIds: List.of(trackIds),
      createdAt: now,
      updatedAt: now,
    );
    await _put(p);
    return p;
  }

  Future<void> rename(String id, String name) async {
    final p = _items[id];
    if (p != null && name.trim().isNotEmpty) await _put(p.copyWith(name: name.trim()));
  }

  Future<void> delete(String id) async {
    _items.remove(id);
    await _store.playlists.delete(id);
    notifyListeners();
  }

  /// Returns false when the track was already in the playlist.
  Future<bool> addTrack(String id, String trackId) async {
    final p = _items[id];
    if (p == null || p.trackIds.contains(trackId)) return false;
    await _put(p.copyWith(trackIds: [...p.trackIds, trackId]));
    return true;
  }

  Future<void> removeTrack(String id, String trackId) async {
    final p = _items[id];
    if (p == null) return;
    await _put(p.copyWith(trackIds: p.trackIds.where((t) => t != trackId).toList()));
  }

  Future<void> reorder(String id, int from, int to) async {
    final p = _items[id];
    if (p == null) return;
    final ids = List.of(p.trackIds);
    final moved = ids.removeAt(from);
    ids.insert(to.clamp(0, ids.length), moved);
    await _put(p.copyWith(trackIds: ids));
  }

  /// Drop references to a deleted track from every playlist.
  Future<void> forgetTrack(String trackId) async {
    for (final p in all) {
      if (p.trackIds.contains(trackId)) await removeTrack(p.id, trackId);
    }
  }
}
