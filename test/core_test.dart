import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:truhive/audio/synth.dart';
import 'package:truhive/core/models/models.dart';
import 'package:truhive/core/util/format.dart';
import 'package:truhive/data/storage/file_store.dart';
import 'package:truhive/data/storage/local_store.dart';
import 'package:truhive/services/library_repository.dart';
import 'package:truhive/services/search_controller.dart';
import 'package:truhive/sources/backend_source.dart';
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

  group('source manager', () {
    final backend = MockClient((req) async {
      if (req.url.path.endsWith('/api/sources')) {
        return http.Response(
          '{"sources":[{"id":"jm","name":"Jamendo","download":true,"lyrics":true},'
          '{"id":"it","name":"Apple Music","download":false,"lyrics":true}]}',
          200,
        );
      }
      return http.Response('{}', 404);
    });

    test('a backend replaces the demo sources with one source per provider', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(SourceManager(prefs).isEnabled('openwave'), isTrue); // no backend: demos
      await prefs.setString('sources.backendUrl', 'https://example.test/fn');
      final sm = SourceManager(prefs, client: backend);
      // Until the backend answers, the built-in provider list is used.
      expect(sm.all.map((s) => s.id), ['backend.jm', 'backend.au', 'backend.cc', 'backend.ov', 'backend.ia', 'backend.it']);
      expect(sm.all.any((s) => s.isDemo), isFalse);
      expect(sm.enabled.length, 6);
      await sm.refreshProviders();
      expect(sm.all.map((s) => s.id), ['backend.jm', 'backend.it']);
      expect(sm.byId('backend.it')!.capabilities.download, isFalse);
      expect(sm.byId('backend.jm')!.name, 'Jamendo');
      // Songs saved before the split still find a source.
      expect(sm.byId('backend'), isA<BackendSource>());
      // The fetched list is remembered for offline starts.
      expect(SourceManager(prefs).all.map((s) => s.id), ['backend.jm', 'backend.it']);
    });

    test('disconnecting a bundled backend sticks and brings the demos back', () async {
      SharedPreferences.setMockInitialValues({'sources.backendUrl': 'https://example.test/fn'});
      final prefs = await SharedPreferences.getInstance();
      final sm = SourceManager(prefs, client: backend);
      await sm.setBackendUrl('');
      expect(SourceManager(prefs).backendUrl, isNull);
      expect(SourceManager(prefs).byId('backend.jm'), isNull);
      expect(SourceManager(prefs).isEnabled('openwave'), isTrue);
    });

    test('provider search asks for that provider and loads covers through the backend', () async {
      late Uri asked;
      final src = BackendSource(
        'https://example.test/fn/',
        provider: const BackendProvider(id: 'it', name: 'Apple Music', lyrics: true),
        client: MockClient((req) async {
          asked = req.url;
          return http.Response(
            '{"results":[{"id":"it:1","title":"Hello","artist":"Adele","durationMs":295000,'
            '"preview":true,"artworkUrl":"https://is1-ssl.mzstatic.com/a/600x600bb.jpg"}]}',
            200,
          );
        }),
      );
      final hits = await src.search('hello');
      expect(asked.path, '/fn/api/search');
      expect(asked.queryParameters, {'q': 'hello', 'provider': 'it'});
      expect(src.id, 'backend.it');
      expect(src.monogram, 'AM');
      final art = Uri.parse(hits.single.artSeed);
      expect(art.path, '/fn/api/art');
      expect(art.queryParameters['u'], 'https://is1-ssl.mzstatic.com/a/600x600bb.jpg');
      expect(hits.single.sourceId, 'backend.it');
    });
  });

  group('online songs', () {
    late LibraryRepository lib;
    final files = _MemoryFiles();

    setUp(() async {
      Hive.init(Directory.systemTemp.createTempSync('truhive').path);
      final store = LocalStore.fromBoxes(
        await Hive.openBox<dynamic>('tracks'),
        await Hive.openBox<dynamic>('playlists'),
        await Hive.openBox<dynamic>('meta'),
      );
      lib = LibraryRepository(store, files);
    });
    tearDown(() => Hive.close());

    const src = SourceTrack(
      sourceId: 'backend.au',
      sourceName: 'Audius',
      sourceTrackId: 'au:x1',
      title: 'Night Drive',
      artist: 'DJ Kofi',
      album: '',
      duration: Duration(minutes: 3),
      artSeed: 'au:x1',
      streamAvailable: true,
    );

    test('are saved apart from files and show up in favorites and history', () async {
      final online = Track.online(src);
      expect(online.isOnline, isTrue);
      expect(online.id, src.localId);
      await lib.saveOnline(online);
      await lib.toggleFavorite(online.id);
      await lib.markPlayed(online.id);
      expect(lib.byId(online.id)?.isOnline, isTrue);
      expect(lib.contains(online.id), isFalse, reason: 'not a file on this device');
      expect(lib.tracks, isEmpty);
      expect(lib.totalBytes, 0);
      expect(lib.favorites.single.id, online.id);
      expect(lib.recentlyPlayed.single.id, online.id);
    });

    test('a download of the same song takes over, and clearing files keeps the online song', () async {
      final online = Track.online(src);
      await lib.saveOnline(online);
      await lib.toggleFavorite(online.id);
      final file = Track(
        id: src.localId,
        title: src.title,
        artist: src.artist,
        album: '',
        duration: src.duration,
        artSeed: src.artSeed,
        origin: TrackOrigin.download,
        fileKey: 'k1',
        fileName: 'night.mp3',
        sizeBytes: 1000,
        mimeType: 'audio/mpeg',
        addedAt: DateTime(2026),
        sourceId: src.sourceId,
        sourceTrackId: src.sourceTrackId,
      );
      await lib.add(file);
      expect(lib.byId(src.localId)?.isOnline, isFalse, reason: 'downloaded copy wins');
      await lib.clearAll();
      expect(lib.byId(src.localId)?.isOnline, isTrue);
      expect(lib.isFavorite(src.localId), isTrue);
    });

    test('survive a restart', () async {
      await lib.saveOnline(Track.online(src));
      final store = LocalStore.fromBoxes(Hive.box<dynamic>('tracks'), Hive.box<dynamic>('playlists'), Hive.box<dynamic>('meta'));
      final again = LibraryRepository(store, files);
      expect(again.byId(src.localId)?.title, 'Night Drive');
      expect(again.byId(src.localId)?.sourceTrackId, 'au:x1');
    });

    test('backend sources stream full songs where allowed', () {
      final b = BackendSource(
        'https://example.test/fn',
        provider: const BackendProvider(id: 'au', name: 'Audius', stream: true, download: true),
      );
      expect(b.capabilities.stream, isTrue);
      expect(b.streamUri('au:x1').toString(), 'https://example.test/fn/api/stream/au%3Ax1');
      final apple = BackendSource('https://example.test/fn', provider: const BackendProvider(id: 'it', name: 'Apple Music'));
      expect(apple.capabilities.stream, isFalse);
    });

    test('a group can stream when any source allows it', () {
      final preview = SourceTrack(
        sourceId: 'backend.it',
        sourceName: 'Apple Music',
        sourceTrackId: 'it:1',
        title: src.title,
        artist: src.artist,
        album: '',
        duration: src.duration,
        artSeed: 'x',
        previewAvailable: true,
      );
      final g = TrackGroup('k', [preview, src]);
      expect(g.canStream, isTrue);
      expect(g.streamSource, same(src));
      expect(TrackGroup('k', [preview]).canStream, isFalse);
    });
  });
}

class _MemoryFiles implements FileStore {
  @override
  String get locationDescription => 'memory';
  @override
  bool get isBrowserStorage => false;
  @override
  Future<void> save(String key, Uint8List bytes) async {}
  @override
  Future<Uint8List?> read(String key) async => null;
  @override
  Future<bool> exists(String key) async => false;
  @override
  Future<void> delete(String key) async {}
  @override
  Future<void> clear() async {}
  @override
  Future<Uri> playableUri(String key, String mimeType) async => Uri.parse('file:///$key');
  @override
  Future<Uri> ephemeralUri(String name, Uint8List bytes, String mimeType) async => Uri.parse('file:///$name');
  @override
  Future<StorageInfo> info() async => const StorageInfo(usedByApp: 0);
  @override
  Future<bool> requestPersistence() async => true;
}
