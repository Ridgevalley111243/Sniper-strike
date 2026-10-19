import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'file_store.dart';

Future<FileStore> openFileStore() async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}${Platform.pathSeparator}TRUHive Music');
  await dir.create(recursive: true);
  final tmp = Directory('${(await getTemporaryDirectory()).path}${Platform.pathSeparator}truhive-previews');
  await tmp.create(recursive: true);
  return _IoFileStore(dir, tmp);
}

class _IoFileStore implements FileStore {
  _IoFileStore(this.dir, this.tmp);

  final Directory dir;
  final Directory tmp;

  File _file(String key) => File('${dir.path}${Platform.pathSeparator}${_safe(key)}');
  static String _safe(String key) => key.replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_');

  @override
  String get locationDescription => dir.path;

  @override
  bool get isBrowserStorage => false;

  @override
  Future<void> save(String key, Uint8List bytes) async {
    final f = _file(key);
    final partial = File('${f.path}.part');
    await partial.writeAsBytes(bytes, flush: true);
    await partial.rename(f.path);
  }

  @override
  Future<Uint8List?> read(String key) async {
    final f = _file(key);
    return await f.exists() ? f.readAsBytes() : null;
  }

  @override
  Future<bool> exists(String key) => _file(key).exists();

  @override
  Future<void> delete(String key) async {
    final f = _file(key);
    if (await f.exists()) await f.delete();
  }

  @override
  Future<void> clear() async {
    await for (final e in dir.list()) {
      if (e is File) await e.delete();
    }
  }

  @override
  Future<Uri> playableUri(String key, String mimeType) async => Uri.file(_file(key).path);

  @override
  Future<Uri> ephemeralUri(String name, Uint8List bytes, String mimeType) async {
    // Keep only the most recent previews around.
    final existing = (await tmp.list().toList()).whereType<File>().toList();
    if (existing.length > 6) {
      existing.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
      for (final f in existing.take(existing.length - 6)) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
    final f = File('${tmp.path}${Platform.pathSeparator}${_safe(name)}');
    await f.writeAsBytes(bytes, flush: true);
    return Uri.file(f.path);
  }

  @override
  Future<StorageInfo> info() async {
    var used = 0;
    await for (final e in dir.list()) {
      if (e is File) used += await e.length();
    }
    // Free-space reporting needs platform channels that are not reliable across
    // devices, so only TRUHive's own usage is reported on native platforms.
    return StorageInfo(usedByApp: used);
  }

  @override
  Future<bool> requestPersistence() async => true; // app sandbox files are never evicted
}
