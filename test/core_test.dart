import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:truhive/audio/synth.dart';
import 'package:truhive/core/models/models.dart';
import 'package:truhive/core/util/format.dart';
import 'package:truhive/services/search_controller.dart';
import 'package:truhive/sources/demo/demo_source.dart';
import 'package:truhive/sources/music_source.dart';
import 'package:truhive/sources/source_manager.dart';

SourceTrack _hit(String source, String title, String artist, int seconds) => SourceTrack(
      sourceId: source,
      sourceName: source,
      sourceTrackId: '$source-$title',
      title: title,
      artist: artist,
      album: '',
      duration: Duration(seconds: seconds),
      artSeed: title,
      downloadAvailable: source == 'b',
      previewAvailable: true,
    );

Future<Uint8List> _collect(Stream<List<int>> s) async {
  final b = BytesBuilder();
  await for (final c in s) {
    b.add(c);
  }
  return b.takeBytes();
}

void main() {
  group('result normalization', () {
    test('groups the same recording across sources and keeps different cuts apart', () {
      final groups = MusicSearchController.groupResults([
        _hit('a', 'On God', 'Kaelo Mensah', 222),
        _hit('b', 'On God', 'kaelo mensah', 223),
        _hit('c', 'On God!', 'Kaelo  Mensah', 221),
        _hit('a', 'On God', 'Kaelo Mensah', 300), // different length = different recording
        _hit('a', 'God Over Everything', 'Ama Serwaa', 198),
      ], 'on god');
      expect(groups, hasLength(3));
      final top = groups.first;
      expect(top.title, 'On God');
      expect(top.sources, hasLength(3));
      // Download-capable source is preferred within the group.
      expect(top.primary.sourceId, 'b');
      expect(top.canDownload, isTrue);
    });

    test('normalizeForMatch strips punctuation and case', () {
      expect(normalizeForMatch('  On God (Remastered)! '), 'on god remastered');
    });
  });

  group('demo audio', () {
    test('WAV header size matches the rendered sample count', () {
      const d = Duration(seconds: 3);
      final s = Synth(SongSpec.fromSeed(7, SongStyle.afrobeats, d), sampleRate: 8000);
      final h = wavHeader(s.totalSamples, 8000);
      expect(h.length, 44);
      expect(ByteData.sublistView(h).getUint32(40, Endian.little), s.totalSamples * 2);
      expect(wavSize(d, 8000), 44 + s.totalSamples * 2);
      final pcm = s.renderPcm(0, s.totalSamples);
      expect(pcm.length, s.totalSamples * 2);
      expect(pcm.any((b) => b != 0), isTrue);
    });

    test('rendering is deterministic, so resumed downloads stitch exactly', () {
      final s = Synth(SongSpec.fromSeed(42, SongStyle.chill, const Duration(seconds: 2)), sampleRate: 8000);
      final whole = s.renderPcm(0, 1000);
      final parts = [...s.renderPcm(0, 400), ...s.renderPcm(400, 600)];
      expect(parts, whole);
    });
  });

  group('demo sources', () {
    final sources = buildDemoSources();
    final openwave = sources.firstWhere((s) => s.id == 'openwave');
    final indie = sources.firstWhere((s) => s.id == 'indievault');
    final arcadia = sources.firstWhere((s) => s.id == 'arcadia');

    test('search matches title, artist, album and genre', () async {
      expect((await openwave.search('on god')).map((t) => t.title), containsAll(['On God', 'On God (Acoustic)']));
      expect((await openwave.search('hollow pines')).length, greaterThanOrEqualTo(3));
      expect(await openwave.search('   '), isEmpty);
    });

    test('capabilities are honest per source', () async {
      final a = (await arcadia.search('on god')).first;
      expect(a.previewAvailable, isTrue);
      expect(a.downloadAvailable, isFalse);
      expect(() => arcadia.openDownload(a), throwsA(isA<UnsupportedCapabilityException>()));
      await expectLater(indie.search('on god'), throwsA(isA<SourceUnavailableException>()));
    });

    test('download stream delivers exactly the advertised size and resumes byte-exactly', () async {
      final fast = DemoSource(
        id: 'openwave',
        name: 'OpenWave',
        monogram: 'OW',
        description: '',
        capabilities: const SourceCapabilities(preview: true, download: true),
        sampleRate: 4000,
        latency: (0, 1),
        bytesPerSecond: 1 << 30,
      );
      final t = (await fast.search('salt photographs')).single;
      final full = await fast.openDownload(t);
      final all = await _collect(full.bytes);
      expect(all.length, full.totalBytes);
      expect(full.totalBytes, t.sizeBytes);
      for (final cut in [17, 44, 45, 1001]) {
        final rest = await fast.openDownload(t, fromByte: cut);
        final tail = await _collect(rest.bytes);
        expect(tail.length, full.totalBytes - cut);
        expect(tail, all.sublist(cut), reason: 'resume from byte $cut');
      }
    });
  });

  group('search engine', () {
    test('one unavailable source does not break the search', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final sm = SourceManager(prefs);
      final search = MusicSearchController(sm);
      search.onQueryChanged('on god');
      await search.run();
      expect(search.failed.keys, contains('indievault'));
      expect(search.responded, containsAll(['openwave', 'commons', 'arcadia']));
      expect(search.results.first.title, 'On God');
      expect(search.results.first.sources.length, greaterThanOrEqualTo(3));
      expect(sm.health('indievault').name, 'unavailable');
    });
  });
}
