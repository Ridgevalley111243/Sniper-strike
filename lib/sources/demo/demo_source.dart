import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../audio/synth.dart';
import '../../core/models/models.dart';
import '../../core/util/format.dart';
import '../music_source.dart';
import 'demo_catalog.dart';

/// A self-contained demo provider. It behaves like a networked source
/// (latency, bandwidth, optional outage) but serves original audio that is
/// synthesized on the device, so nothing copyrighted is ever fetched. Swap it
/// for a real adapter (see `BackendSource`) without touching the UI.
class DemoSource extends MusicSource {
  DemoSource({
    required this.id,
    required this.name,
    required this.monogram,
    required this.description,
    required this.capabilities,
    required this.sampleRate,
    this.latency = const (300, 800),
    this.bytesPerSecond = 1600 * 1024,
    this.simulateOutage = false,
  });

  @override
  final String id;
  @override
  final String name;
  @override
  final String monogram;
  @override
  final String description;
  @override
  final SourceCapabilities capabilities;
  final int sampleRate;
  final (int, int) latency;
  final int bytesPerSecond;

  /// Lets the demo exercise the "one source is down" experience.
  final bool simulateOutage;

  @override
  bool get isDemo => true;

  final _rng = math.Random();

  List<DemoRecording> get _catalog {
    final ids = demoSourceCatalogs[id] ?? const [];
    return demoRecordings.where((r) => ids.contains(r.id)).toList();
  }

  DemoRecording _recording(SourceTrack t) => demoRecordings.firstWhere((r) => r.id == t.sourceTrackId);

  Future<void> _networkDelay() =>
      Future.delayed(Duration(milliseconds: latency.$1 + _rng.nextInt(math.max(1, latency.$2 - latency.$1))));

  Synth _synth(DemoRecording r) =>
      Synth(SongSpec.fromSeed(fnv1a(r.id), r.style, Duration(seconds: r.seconds)), sampleRate: sampleRate);

  SourceTrack _toTrack(DemoRecording r) => SourceTrack(
        sourceId: id,
        sourceName: name,
        sourceTrackId: r.id,
        title: r.title,
        artist: r.artist,
        album: r.album,
        genre: r.genre,
        year: r.year,
        duration: Duration(seconds: r.seconds),
        artSeed: r.id,
        previewAvailable: capabilities.preview,
        downloadAvailable: capabilities.download,
        lyricsAvailable: capabilities.lyrics && r.lyrics != null,
        format: 'WAV · ${(sampleRate / 1000).toStringAsFixed(sampleRate % 1000 == 0 ? 0 : 1)} kHz',
        sizeBytes: capabilities.download ? wavSize(Duration(seconds: r.seconds), sampleRate) : null,
      );

  @override
  Future<List<SourceTrack>> search(String query) async {
    await _networkDelay();
    if (simulateOutage) throw SourceUnavailableException(name, 'Simulated outage (demo)');
    final tokens = normalizeForMatch(query).split(' ').where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return const [];
    return [
      for (final r in _catalog)
        if (tokens.every((t) => normalizeForMatch('${r.title} ${r.artist} ${r.album} ${r.genre}').contains(t)))
          _toTrack(r),
    ];
  }

  /// Renders a sample range without blocking the UI thread for long.
  Future<Uint8List> _render(Synth s, int from, int count) async {
    final out = BytesBuilder(copy: false);
    final step = sampleRate ~/ 2;
    for (var i = 0; i < count; i += step) {
      out.add(s.renderPcm(from + i, math.min(step, count - i)));
      await Future<void>.delayed(Duration.zero);
    }
    return out.takeBytes();
  }

  @override
  Future<PreviewAudio> getPreview(SourceTrack track) async {
    if (!capabilities.preview) throw const UnsupportedCapabilityException('preview');
    await _networkDelay();
    if (simulateOutage) throw SourceUnavailableException(name);
    final r = _recording(track);
    final s = _synth(r);
    const clip = 30;
    final start = math.min(math.max(0, r.seconds - clip), (r.seconds * 0.28).round());
    final count = math.min(clip * sampleRate, s.totalSamples - start * sampleRate);
    final pcm = await _render(s, start * sampleRate, count);
    final bytes = BytesBuilder(copy: false)
      ..add(wavHeader(count, sampleRate))
      ..add(pcm);
    return PreviewAudio(bytes: bytes.takeBytes(), mimeType: 'audio/wav', length: Duration(seconds: count ~/ sampleRate));
  }

  @override
  Future<DownloadStream> openDownload(SourceTrack track, {int fromByte = 0}) async {
    if (!capabilities.download) throw const UnsupportedCapabilityException('download');
    await _networkDelay();
    if (simulateOutage) throw SourceUnavailableException(name);
    final r = _recording(track);
    final s = _synth(r);
    final total = 44 + s.totalSamples * 2;

    Stream<List<int>> body() async* {
      var pos = fromByte;
      final header = wavHeader(s.totalSamples, sampleRate);
      if (pos < 44) {
        yield header.sublist(pos);
        pos = 44;
      }
      final chunkSamples = sampleRate ~/ 2;
      var sample = (pos - 44) ~/ 2;
      final skipOdd = (pos - 44).isOdd;
      var first = true;
      final watch = Stopwatch()..start();
      var sent = 0;
      while (sample < s.totalSamples) {
        final n = math.min(chunkSamples, s.totalSamples - sample);
        var chunk = s.renderPcm(sample, n);
        if (first && skipOdd) chunk = chunk.sublist(1);
        first = false;
        sample += n;
        sent += chunk.length;
        yield chunk;
        // Pace the stream like a real connection so progress is meaningful.
        final targetMs = sent * 1000 ~/ bytesPerSecond;
        final wait = targetMs - watch.elapsedMilliseconds;
        await Future<void>.delayed(Duration(milliseconds: math.max(0, wait)));
      }
    }

    return DownloadStream(
      totalBytes: total,
      fromByte: fromByte,
      bytes: body(),
      mimeType: 'audio/wav',
      fileExtension: 'wav',
      supportsResume: true,
    );
  }

  @override
  Future<Lyrics?> getLyrics(SourceTrack track) async {
    if (!capabilities.lyrics) return null;
    await _networkDelay();
    final r = _recording(track);
    final lines = r.lyrics;
    if (lines == null) return null;
    const start = 12.0;
    final span = (r.seconds - 24 - start) / lines.length;
    return Lyrics(
      providerName: name,
      synced: true,
      lines: [
        for (var i = 0; i < lines.length; i++)
          LyricLine(Duration(milliseconds: ((start + i * span) * 1000).round()), lines[i]),
      ],
    );
  }

  @override
  Future<bool> ping() async {
    await _networkDelay();
    return !simulateOutage;
  }
}

List<MusicSource> buildDemoSources() => [
      DemoSource(
        id: 'openwave',
        name: 'OpenWave',
        monogram: 'OW',
        description: 'Demo adapter · search, preview, download and synced lyrics',
        capabilities: const SourceCapabilities(preview: true, download: true, lyrics: true),
        sampleRate: 22050,
      ),
      DemoSource(
        id: 'commons',
        name: 'Commons Audio',
        monogram: 'CA',
        description: 'Demo adapter · search, preview and download',
        capabilities: const SourceCapabilities(preview: true, download: true),
        sampleRate: 16000,
        latency: (450, 1100),
        bytesPerSecond: 900 * 1024,
      ),
      DemoSource(
        id: 'arcadia',
        name: 'Arcadia',
        monogram: 'AR',
        description: 'Demo adapter · search and 30-second previews only',
        capabilities: const SourceCapabilities(preview: true),
        sampleRate: 22050,
        latency: (250, 600),
      ),
      DemoSource(
        id: 'indievault',
        name: 'IndieVault',
        monogram: 'IV',
        description: 'Demo adapter · simulates an outage to show error handling',
        capabilities: const SourceCapabilities(preview: true, download: true),
        sampleRate: 22050,
        latency: (900, 1600),
        simulateOutage: true,
      ),
    ];
