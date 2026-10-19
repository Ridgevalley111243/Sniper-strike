import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../core/models/models.dart';
import '../sources/music_source.dart';
import '../sources/source_manager.dart';
import 'connectivity_service.dart';
import 'library_repository.dart';
import 'settings_controller.dart';

class DownloadTask {
  DownloadTask(this.group, this.source) : createdAt = DateTime.now();

  final TrackGroup group;
  final SourceTrack source;
  final DateTime createdAt;
  DownloadStatus status = DownloadStatus.queued;
  int received = 0;
  int total = 0;
  double bytesPerSecond = 0;
  String? error;
  String? waitingReason;
  String mimeType = 'audio/wav';
  String extension = 'wav';
  bool supportsResume = true;

  final BytesBuilder _buffer = BytesBuilder(copy: false);
  StreamSubscription<List<int>>? _sub;
  DateTime _speedAt = DateTime.now();
  int _speedBytes = 0;

  String get id => source.localId;
  double get progress => total > 0 ? received / total : 0;
  bool get isActive =>
      status == DownloadStatus.queued || status == DownloadStatus.downloading || status == DownloadStatus.saving;
}

/// Downloads authorized tracks to the device with progress, pause/resume
/// (byte ranges), cancel and retry. Completed files land in [LibraryRepository].
class DownloadManager extends ChangeNotifier {
  DownloadManager(this._sources, this._library, this._settings, this._net);

  final SourceManager _sources;
  final LibraryRepository _library;
  final SettingsController _settings;
  final ConnectivityService _net;
  static const _maxConcurrent = 2;

  final List<DownloadTask> _tasks = [];
  final _completed = StreamController<Track>.broadcast();
  Timer? _notifyTimer;

  /// Fires once per finished download (drives the "Download complete" sheet).
  Stream<Track> get completions => _completed.stream;

  List<DownloadTask> get active =>
      _tasks.where((t) => t.status != DownloadStatus.completed && t.status != DownloadStatus.canceled).toList();
  DownloadTask? taskFor(String localId) {
    for (final t in _tasks) {
      if (t.id == localId && t.status != DownloadStatus.canceled) return t;
    }
    return null;
  }

  bool isDownloaded(SourceTrack s) => _library.contains(s.localId);

  /// Starts (or returns the existing) download of [group] from [from] or the
  /// best download-capable source.
  DownloadTask? start(TrackGroup group, {SourceTrack? from}) {
    final src = from ?? group.downloadSource;
    if (src == null || !src.downloadAvailable) return null;
    if (isDownloaded(src)) return null;
    final existing = taskFor(src.localId);
    if (existing != null && existing.status != DownloadStatus.failed) return existing;
    if (existing != null) _tasks.remove(existing);
    final task = DownloadTask(group, src)..total = src.sizeBytes ?? 0;
    _tasks.insert(0, task);
    _pump();
    notifyListeners();
    return task;
  }

  void pause(DownloadTask t) {
    if (t.status != DownloadStatus.downloading && t.status != DownloadStatus.queued) return;
    t._sub?.cancel();
    t._sub = null;
    t.status = DownloadStatus.paused;
    t.bytesPerSecond = 0;
    notifyListeners();
    _pump();
  }

  void resume(DownloadTask t) {
    if (t.status != DownloadStatus.paused && t.status != DownloadStatus.failed) return;
    t.status = DownloadStatus.queued;
    t.error = null;
    _pump();
    notifyListeners();
  }

  void cancel(DownloadTask t) {
    t._sub?.cancel();
    t._sub = null;
    t.status = DownloadStatus.canceled;
    t._buffer.clear();
    _tasks.remove(t);
    notifyListeners();
    _pump();
  }

  void pauseAll() {
    for (final t in active) {
      pause(t);
    }
  }

  void _pump() {
    final running = _tasks.where((t) => t.status == DownloadStatus.downloading).length;
    var slots = _maxConcurrent - running;
    for (final t in _tasks.reversed) {
      if (slots <= 0) break;
      if (t.status != DownloadStatus.queued) continue;
      if (!_net.isOnline) {
        t.waitingReason = 'Waiting for a connection';
        continue;
      }
      if (_settings.wifiOnlyDownloads && !_net.onWifi) {
        t.waitingReason = 'Waiting for Wi-Fi';
        continue;
      }
      t.waitingReason = null;
      slots--;
      _run(t);
    }
  }

  Future<void> _run(DownloadTask t) async {
    final source = _sources.byId(t.source.sourceId);
    if (source == null) return _fail(t, 'This source is no longer available.');
    t.status = DownloadStatus.downloading;
    notifyListeners();
    final DownloadStream stream;
    try {
      stream = await source.openDownload(t.source, fromByte: t.received);
    } catch (e) {
      return _fail(t, e is SourceUnavailableException ? '${e.sourceName} is unavailable right now.' : 'Download could not start.');
    }
    if (t.status != DownloadStatus.downloading) return; // paused/canceled while connecting
    if (stream.fromByte == 0 && t.received > 0) {
      // Server ignored the range request — restart cleanly.
      t._buffer.clear();
      t.received = 0;
    }
    t
      ..total = stream.totalBytes
      ..mimeType = stream.mimeType
      ..extension = stream.fileExtension
      ..supportsResume = stream.supportsResume
      .._speedAt = DateTime.now()
      .._speedBytes = 0;
    t._sub = stream.bytes.listen(
      (chunk) {
        t._buffer.add(chunk is Uint8List ? chunk : Uint8List.fromList(chunk));
        t.received += chunk.length;
        t._speedBytes += chunk.length;
        final dt = DateTime.now().difference(t._speedAt).inMilliseconds;
        if (dt >= 700) {
          final now = t._speedBytes * 1000 / dt;
          t.bytesPerSecond = t.bytesPerSecond == 0 ? now : t.bytesPerSecond * 0.6 + now * 0.4;
          t._speedAt = DateTime.now();
          t._speedBytes = 0;
        }
        _notifySoon();
      },
      onError: (Object e) => _fail(t, 'The connection was interrupted.'),
      onDone: () => _finish(t),
      cancelOnError: true,
    );
  }

  Future<void> _finish(DownloadTask t) async {
    if (t.status != DownloadStatus.downloading) return;
    t._sub = null;
    t.status = DownloadStatus.saving;
    t.bytesPerSecond = 0;
    notifyListeners();
    try {
      final bytes = t._buffer.takeBytes();
      final s = t.source;
      final fileName = '${s.artist} - ${s.title}.${t.extension}'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final key = '${s.sourceId}_${s.sourceTrackId}.${t.extension}';
      await _library.files.save(key, bytes);
      final track = Track(
        id: s.localId,
        title: s.title,
        artist: s.artist,
        album: s.album,
        duration: s.duration,
        artSeed: s.artSeed,
        origin: TrackOrigin.download,
        fileKey: key,
        fileName: fileName,
        sizeBytes: bytes.lengthInBytes,
        mimeType: t.mimeType,
        addedAt: DateTime.now(),
        genre: s.genre,
        year: s.year,
        sourceId: s.sourceId,
        sourceName: s.sourceName,
        sourceTrackId: s.sourceTrackId,
        lyricsAvailable: s.lyricsAvailable,
        inLibrary: _settings.autoAddDownloads,
      );
      await _library.add(track);
      t.status = DownloadStatus.completed;
      t.received = t.total = bytes.lengthInBytes;
      _tasks.remove(t);
      _completed.add(track);
    } catch (e) {
      _fail(t, 'Not enough space to save this file.');
      return;
    }
    notifyListeners();
    _pump();
  }

  void _fail(DownloadTask t, String message) {
    t._sub?.cancel();
    t._sub = null;
    t.status = DownloadStatus.failed;
    t.error = message;
    t.bytesPerSecond = 0;
    notifyListeners();
    _pump();
  }

  void _notifySoon() {
    if (_notifyTimer?.isActive ?? false) return;
    _notifyTimer = Timer(const Duration(milliseconds: 150), notifyListeners);
  }

  /// Re-evaluate waiting downloads (e.g. connectivity came back).
  void onNetworkChanged() {
    _pump();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final t in _tasks) {
      t._sub?.cancel();
    }
    _notifyTimer?.cancel();
    _completed.close();
    super.dispose();
  }
}
