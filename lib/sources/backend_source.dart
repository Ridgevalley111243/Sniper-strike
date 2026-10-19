import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/models/models.dart';
import 'music_source.dart';

/// One provider the backend exposes (`GET /api/sources`).
class BackendProvider {
  const BackendProvider({
    required this.id,
    required this.name,
    this.description = '',
    this.preview = true,
    this.stream = false,
    this.download = false,
    this.lyrics = false,
  });

  factory BackendProvider.fromJson(Map<String, dynamic> j) => BackendProvider(
    id: j['id'] as String,
    name: j['name'] as String,
    description: (j['description'] as String?) ?? '',
    preview: (j['preview'] as bool?) ?? true,
    stream: (j['stream'] as bool?) ?? false,
    download: (j['download'] as bool?) ?? false,
    lyrics: (j['lyrics'] as bool?) ?? false,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'preview': preview,
    'stream': stream,
    'download': download,
    'lyrics': lyrics,
  };

  final String id;
  final String name;
  final String description;
  final bool preview;
  final bool stream;
  final bool download;
  final bool lyrics;
}

/// Adapter for a TRUHive backend that proxies real, licensed providers.
/// Each provider the backend offers becomes its own source in the app.
///
/// Provider API keys must live on that server — never in this app. The
/// expected contract is documented in README.md ("Connecting a backend").
class BackendSource extends MusicSource {
  BackendSource(this.baseUrl, {this.provider, http.Client? client}) : _client = client ?? http.Client();

  final String baseUrl;

  /// The provider this source searches; null searches all of them.
  final BackendProvider? provider;
  final http.Client _client;
  static const _timeout = Duration(seconds: 12);

  /// Source id for a provider; tracks are keyed by it in the library.
  static String idFor(String providerId) => 'backend.$providerId';

  @override
  String get id => provider == null ? 'backend' : idFor(provider!.id);
  @override
  String get name => provider?.name ?? 'TRUHive Backend';
  @override
  String get monogram {
    final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return (words.length > 1 ? words[0][0] + words[1][0] : name.padRight(2).substring(0, 2)).trim().toUpperCase();
  }

  @override
  String get description => provider?.description ?? 'Live providers via $baseUrl';
  @override
  bool get isDemo => false;
  @override
  SourceCapabilities get capabilities => provider == null
      ? const SourceCapabilities(search: true, preview: true, stream: true, download: true, lyrics: true)
      : SourceCapabilities(
          search: true,
          preview: provider!.preview,
          stream: provider!.stream,
          download: provider!.download,
          lyrics: provider!.lyrics,
        );

  Uri _u(String path, [Map<String, String>? q]) => endpoint(baseUrl, path, q);

  static Uri endpoint(String baseUrl, String path, [Map<String, String>? q]) {
    final base = Uri.parse(baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl);
    return base.replace(path: '${base.path}$path', queryParameters: q);
  }

  /// The providers a backend currently offers.
  static Future<List<BackendProvider>> fetchProviders(String baseUrl, {http.Client? client}) async {
    final c = client ?? http.Client();
    final r = await c.get(endpoint(baseUrl, '/api/sources')).timeout(const Duration(seconds: 8));
    if (r.statusCode != 200) throw SourceUnavailableException('TRUHive Backend', 'HTTP ${r.statusCode}');
    final list = (jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>)['sources'] as List;
    return [for (final j in list.cast<Map<String, dynamic>>()) BackendProvider.fromJson(j)];
  }

  Future<Map<String, dynamic>> _json(Uri uri) async {
    try {
      final r = await _client.get(uri).timeout(_timeout);
      if (r.statusCode != 200) throw SourceUnavailableException(name, 'HTTP ${r.statusCode}');
      return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    } on SourceUnavailableException {
      rethrow;
    } catch (e) {
      throw SourceUnavailableException(name, e.toString());
    }
  }

  @override
  Future<List<SourceTrack>> search(String query) async {
    final data = await _json(_u('/api/search', {'q': query, if (provider != null) 'provider': provider!.id}));
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
          // A cover image URL doubles as the art seed (see Artwork); images go
          // through the backend so the web app may draw them. The signature
          // lets it fetch covers from any host it vouched for.
          artSeed: j['artworkUrl'] is String
              ? _u('/api/art', {'u': j['artworkUrl'] as String, if (j['artworkSig'] is String) 's': j['artworkSig'] as String})
                  .toString()
              : (j['artworkSeed'] as String?) ?? (j['id'] as String),
          genre: j['genre'] as String?,
          year: (j['year'] as num?)?.toInt(),
          previewAvailable: (j['preview'] as bool?) ?? false,
          streamAvailable: (j['stream'] as bool?) ?? false,
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
  Uri? streamUri(String sourceTrackId) => _u('/api/stream/${Uri.encodeComponent(sourceTrackId)}');

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
