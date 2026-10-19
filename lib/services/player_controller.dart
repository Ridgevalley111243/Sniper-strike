import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../core/models/models.dart';
import '../data/storage/file_store.dart';
import '../sources/source_manager.dart';
import 'library_repository.dart';

enum PlayerRepeat { off, all, one }

/// The single source of truth for playback. The mini player, the full player,
/// the desktop player bar, the queue and the lock-screen controls all read
/// from this one controller.
/// Real cover art (an image URL used as the art seed) for the lock screen and
/// notification; generated covers have no URL to show there.
Uri? _artUri(String seed) => seed.startsWith('https://') ? Uri.tryParse(seed) : null;

class PlayerController extends ChangeNotifier {
  PlayerController(this._library, this._files, this._sources, {this.autoplayEnabled}) {
    _subs.addAll([
      _player.currentIndexStream.listen((_) => _onTrackChanged()),
      _player.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed) {
          if (isPreview) {
            _player.pause();
            _player.seek(Duration.zero);
          } else {
            _continueFromLibrary();
          }
        }
        notifyListeners();
      }),
      _player.shuffleModeEnabledStream.listen((_) => notifyListeners()),
      _player.durationStream.listen((d) {
        final t = current;
        if (t != null && d != null && !isPreview) _library.updateDuration(t.id, d);
        notifyListeners();
      }),
    ]);
  }

  final LibraryRepository _library;
  final FileStore _files;
  final SourceManager _sources;

  /// "Autoplay" setting: keep playing from the library when the queue ends.
  final bool Function()? autoplayEnabled;
  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subs = [];

  List<Track> _queue = [];
  PlayerRepeat _repeat = PlayerRepeat.off;

  // Preview state (a 30-second clip from an online source).
  TrackGroup? previewGroup;
  SourceTrack? previewSource;
  bool previewLoading = false;
  String? lastError;

  bool get isPreview => previewGroup != null;
  bool get hasMedia => isPreview || current != null;
  bool get isPlaying => _player.playing;
  bool get isBuffering =>
      previewLoading ||
      _player.processingState == ProcessingState.loading ||
      _player.processingState == ProcessingState.buffering;
  bool get shuffle => _player.shuffleModeEnabled;
  PlayerRepeat get repeat => _repeat;

  Stream<Duration> get position => _player.positionStream;
  Duration get positionNow => _player.position;
  Duration get duration =>
      _player.duration ?? (isPreview ? const Duration(seconds: 30) : (current?.duration ?? Duration.zero));

  List<Track> get queue => List.unmodifiable(_queue);
  int? get currentIndex => isPreview ? null : _player.currentIndex;

  Track? get current {
    if (isPreview) return null;
    final i = _player.currentIndex;
    if (i == null || i < 0 || i >= _queue.length) return null;
    return _queue[i];
  }

  /// Tracks that will play after the current one, in actual play order.
  List<(int, Track)> get upNext {
    final i = currentIndex;
    if (i == null || _queue.isEmpty) return const [];
    final order = shuffle ? _player.effectiveIndices : List.generate(_queue.length, (k) => k);
    final at = order.indexOf(i);
    return [for (final k in order.skip(at + 1)) (k, _queue[k])];
  }

  String get title => isPreview ? previewGroup!.title : (current?.title ?? '');
  String get artist => isPreview ? previewGroup!.artist : (current?.artist ?? '');
  String get artSeed => isPreview ? previewGroup!.artSeed : (current?.artSeed ?? 'none');

  Future<AudioSource> _sourceFor(Track t) async {
    final uri = await _files.playableUri(t.fileKey, t.mimeType);
    return AudioSource.uri(uri, tag: MediaItem(id: t.id, title: t.title, artist: t.artist, album: t.album, duration: t.duration, artUri: _artUri(t.artSeed)));
  }

  Future<void> playTracks(List<Track> tracks, {int start = 0, bool shuffle = false}) async {
    if (tracks.isEmpty) return;
    previewGroup = null;
    previewSource = null;
    lastError = null;
    _queue = List.of(tracks);
    notifyListeners();
    try {
      final sources = await Future.wait(_queue.map(_sourceFor));
      await _player.setShuffleModeEnabled(shuffle);
      await _player.setAudioSources(sources, initialIndex: start.clamp(0, sources.length - 1), initialPosition: Duration.zero);
      if (shuffle) await _player.shuffle();
      await _applyLoopMode();
      unawaited(_player.play());
    } catch (e) {
      lastError = 'This file could not be played.';
      notifyListeners();
    }
  }

  Future<void> playTrack(Track t, {List<Track>? context}) async {
    final list = context ?? [t];
    final i = list.indexWhere((x) => x.id == t.id);
    await playTracks(list, start: i < 0 ? 0 : i);
  }

  /// Plays a short preview from the best preview-capable source of [g].
  Future<void> playPreview(TrackGroup g, {SourceTrack? from}) async {
    final src = from ?? g.previewSource;
    if (src == null) return;
    if (previewGroup?.key == g.key && previewSource?.sourceId == src.sourceId && !previewLoading) {
      return togglePlay();
    }
    final source = _sources.byId(src.sourceId);
    if (source == null) return;
    previewGroup = g;
    previewSource = src;
    previewLoading = true;
    lastError = null;
    _queue = [];
    notifyListeners();
    try {
      await _player.stop();
      final clip = await source.getPreview(src);
      if (previewSource != src) return; // user started another preview meanwhile
      final uri = clip.uri ?? await _files.ephemeralUri('preview-${src.sourceId}-${src.sourceTrackId}.wav', clip.bytes!, clip.mimeType);
      await _player.setAudioSource(AudioSource.uri(uri,
          tag: MediaItem(
              id: 'preview:${src.localId}', title: g.title, artist: '${g.artist} · Preview', duration: clip.length, artUri: _artUri(g.artSeed))));
      await _player.setLoopMode(LoopMode.off);
      previewLoading = false;
      notifyListeners();
      unawaited(_player.play());
    } catch (e) {
      previewLoading = false;
      previewGroup = null;
      previewSource = null;
      lastError = 'Preview unavailable from ${src.sourceName}.';
      notifyListeners();
    }
  }

  bool isPreviewing(TrackGroup g) => previewGroup?.key == g.key;

  Future<void> _continueFromLibrary() async {
    if (!(autoplayEnabled?.call() ?? false) || _repeat != PlayerRepeat.off || _queue.isEmpty) return;
    final played = _queue.map((t) => t.id).toSet();
    final more = _library.libraryTracks.where((t) => !played.contains(t.id)).toList()..shuffle();
    if (more.isEmpty) return;
    await playTracks(more.take(20).toList());
  }

  Future<void> seekToIndex(int index) => _player.seek(Duration.zero, index: index);

  Future<void> togglePlay() async => _player.playing ? _player.pause() : _player.play();
  Future<void> pause() => _player.pause();
  Future<void> seek(Duration d) => _player.seek(d);

  Future<void> next() async {
    if (_player.hasNext) await _player.seekToNext();
  }

  Future<void> previous() async {
    if (_player.position > const Duration(seconds: 3) || !_player.hasPrevious) {
      await _player.seek(Duration.zero);
    } else {
      await _player.seekToPrevious();
    }
  }

  Future<void> toggleShuffle() async {
    final on = !_player.shuffleModeEnabled;
    if (on) await _player.shuffle();
    await _player.setShuffleModeEnabled(on);
    notifyListeners();
  }

  Future<void> cycleRepeat() async {
    _repeat = PlayerRepeat.values[(_repeat.index + 1) % PlayerRepeat.values.length];
    await _applyLoopMode();
    notifyListeners();
  }

  Future<void> _applyLoopMode() => _player.setLoopMode(switch (_repeat) {
        PlayerRepeat.off => LoopMode.off,
        PlayerRepeat.all => LoopMode.all,
        PlayerRepeat.one => LoopMode.one,
      });

  // ---------------- queue ----------------
  Future<void> playNext(Track t) async {
    if (current == null) return playTracks([t]);
    final at = (_player.currentIndex ?? 0) + 1;
    _queue.insert(at, t);
    await _player.insertAudioSource(at, await _sourceFor(t));
    notifyListeners();
  }

  Future<void> addToQueue(Track t) async {
    if (current == null) return playTracks([t]);
    _queue.add(t);
    await _player.addAudioSource(await _sourceFor(t));
    notifyListeners();
  }

  Future<void> removeAt(int index) async {
    if (index == _player.currentIndex || index < 0 || index >= _queue.length) return;
    _queue.removeAt(index);
    await _player.removeAudioSourceAt(index);
    notifyListeners();
  }

  Future<void> move(int from, int to) async {
    if (from == to || from < 0 || from >= _queue.length) return;
    final t = _queue.removeAt(from);
    final dest = to.clamp(0, _queue.length);
    _queue.insert(dest, t);
    await _player.moveAudioSource(from, dest);
    notifyListeners();
  }

  /// Clears everything after the current track.
  Future<void> clearUpNext() async {
    final i = _player.currentIndex;
    if (i == null) return;
    for (var k = _queue.length - 1; k >= 0; k--) {
      if (k != i) {
        _queue.removeAt(k);
        await _player.removeAudioSourceAt(k);
      }
    }
    notifyListeners();
  }

  /// Called when a track is deleted from the device.
  Future<void> forget(String trackId) async {
    final idx = _queue.indexWhere((t) => t.id == trackId);
    if (idx < 0) return;
    if (idx == _player.currentIndex) {
      await _player.stop();
      _queue = [];
      await _player.clearAudioSources();
    } else {
      await removeAt(idx);
    }
    notifyListeners();
  }

  void _onTrackChanged() {
    final t = current;
    if (t != null) _library.markPlayed(t.id);
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }
}
