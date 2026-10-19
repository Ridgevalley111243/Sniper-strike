import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/models/models.dart';
import 'music_source.dart';

/// Adapter for a TRUHive backend that proxies real, licensed providers.
///
/// Provider API keys must live on that server — never in this app. The
/// expected contract is documented in README.md ("Connecting a backend").
class BackendSource extends MusicSource {
  BackendSource(this.baseUrl, {http.Client? client}) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  static const _timeout = Duration(seconds: 12);

  @override
  String get id => 'backend';
  @override
  String get name => 'TRUHive Backend';
  @override
  String get monogram => 'TB';
  @override
  String get description => 'Live providers via $baseUrl';
  @override
  bool get isDemo => false;
  @override
  SourceCapabilities get capabilities =>
      const SourceCapabilities(search: true, preview: true, download: true, lyrics: true);

  Uri _u(String path, [Map<String, String>? q]) {
    final base = Uri.parse(baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl);
    return base.replace(path: '${base.path}$path', queryParameters: q);
  }

  Future<Map<String, dynamic>> _json(Uri uri) async {
    try {
      final r = await _client.get(uri).timeout(_timeout);
      if (r.statusCode != 200) throw SourceUnavailableException(name, 'HTTP ${r.statusCode}');
      return jsonDecode(r.body) as Map<String, dynamic>;
    } on SourceUnavailableException {
      rethrow;
    } catch (e) {
      throw SourceUnavailableException(name, e.toString());
    }
  }

  @override
  Future<List<SourceTrack>> search(String query) async {
    final data = await _json(_u('/api/search', {'q': query}));
    return [
      for (final j in (data['results'] as List).cast<Map<String, dynamic>>())
        SourceTrack(
          sourceId: id,
          sourceName: (j['provider'] as String?) ?? name,
          sourceTrackId: j['id'] as String,
          title: j['title'] as String,
          artist: j['artist'] as String,
          album: (j['album'] as String?) ?? '',
          duration: Duration(milliseconds: (j['durationMs'] as num?)?.toInt() ?? 0),
          artSeed: (j['artworkSeed'] as String?) ?? (j['id'] as String),
          genre: j['genre'] as String?,
          year: (j['year'] as num?)?.toInt(),
          previewAvailable: (j['preview'] as bool?) ?? false,
          downloadAvailable: (j['download'] as bool?) ?? false,
          lyricsAvailable: (j['lyrics'] as bool?) ?? false,
          format: j['format'] as String?,
          sizeBytes: (j['sizeBytes'] as num?)?.toInt(),
        ),
    ];
  }

  @override
  Future<PreviewAudio> getPreview(SourceTrack track) async {
    final uri = _u('/api/preview/${Uri.encodeComponent(track.sourceTrackId)}');
    return PreviewAudio(uri: uri, mimeType: 'audio/mpeg', length: const Duration(seconds: 30));
  }

  @override
  Future<DownloadStream> openDownload(SourceTrack track, {int fromByte = 0}) async {
    final req = http.Request('GET', _u('/api/download/${Uri.encodeComponent(track.sourceTrackId)}'));
    if (fromByte > 0) req.headers['Range'] = 'bytes=$fromByte-';
    final http.StreamedResponse res;
    try {
      res = await _client.send(req).timeout(_timeout);
    } catch (e) {
      throw SourceUnavailableException(name, e.toString());
    }
    if (res.statusCode != 200 && res.statusCode != 206) {
      throw SourceUnavailableException(name, 'HTTP ${res.statusCode}');
    }
    final resumed = res.statusCode == 206;
    final start = resumed ? fromByte : 0;
    final length = res.contentLength ?? track.sizeBytes ?? 0;
    final mime = res.headers['content-type'] ?? 'audio/mpeg';
    return DownloadStream(
      totalBytes: start + length,
      fromByte: start,
      bytes: res.stream,
      mimeType: mime,
      fileExtension: _ext(mime),
      supportsResume: res.headers['accept-ranges'] == 'bytes' || resumed,
    );
  }

  static String _ext(String mime) => switch (mime.split(';').first.trim()) {
        'audio/mpeg' => 'mp3',
        'audio/mp4' || 'audio/aac' => 'm4a',
        'audio/ogg' => 'ogg',
        'audio/flac' => 'flac',
        'audio/wav' || 'audio/x-wav' => 'wav',
        _ => 'audio',
      };

  @override
  Future<Lyrics?> getLyrics(SourceTrack track) async {
    final data = await _json(_u('/api/lyrics/${Uri.encodeComponent(track.sourceTrackId)}'));
    final lines = (data['lines'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    if (lines.isEmpty) return null;
    return Lyrics(
      providerName: (data['provider'] as String?) ?? name,
      synced: (data['synced'] as bool?) ?? false,
      lines: [
        for (final l in lines)
          LyricLine(l['timeMs'] == null ? null : Duration(milliseconds: (l['timeMs'] as num).toInt()), l['text'] as String),
      ],
    );
  }

  @override
  Future<bool> ping() async {
    try {
      final r = await _client.get(_u('/api/health')).timeout(const Duration(seconds: 6));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
