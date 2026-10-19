import 'package:hive_ce_flutter/hive_ce_flutter.dart';

/// Local-first persistence. Hive is backed by files on Android/iOS/desktop and
/// by IndexedDB on the web, so the same code works everywhere. Values are plain
/// JSON-like maps, so no code generation is needed.
class LocalStore {
  LocalStore._(this.tracks, this.playlists, this.meta);

  /// Wraps already-open boxes (tests open them in a temporary directory).
  LocalStore.fromBoxes(this.tracks, this.playlists, this.meta);

  final Box<dynamic> tracks;
  final Box<dynamic> playlists;
  final Box<dynamic> meta;

  static Future<LocalStore> open() async {
    await Hive.initFlutter('truhive');
    final boxes = await Future.wait([
      Hive.openBox<dynamic>('tracks'),
      Hive.openBox<dynamic>('playlists'),
      Hive.openBox<dynamic>('meta'),
    ]);
    return LocalStore._(boxes[0], boxes[1], boxes[2]);
  }
}
