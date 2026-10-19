import 'dart:js_interop';
import 'dart:typed_data';

import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:web/web.dart' as web;

import 'file_store.dart';

Future<FileStore> openFileStore() async {
  final box = await Hive.openBox<dynamic>('files');
  return _WebFileStore(box);
}

class _WebFileStore implements FileStore {
  _WebFileStore(this.box);

  final Box<dynamic> box;
  final Map<String, String> _blobUrls = {};
  String? _lastEphemeral;

  @override
  String get locationDescription => 'This browser’s private storage';

  @override
  bool get isBrowserStorage => true;

  @override
  Future<void> save(String key, Uint8List bytes) => box.put(key, bytes);

  @override
  Future<Uint8List?> read(String key) async {
    final v = box.get(key);
    if (v == null) return null;
    return v is Uint8List ? v : Uint8List.fromList(List<int>.from(v as List));
  }

  @override
  Future<bool> exists(String key) async => box.containsKey(key);

  @override
  Future<void> delete(String key) async {
    final url = _blobUrls.remove(key);
    if (url != null) web.URL.revokeObjectURL(url);
    await box.delete(key);
  }

  @override
  Future<void> clear() async {
    for (final url in _blobUrls.values) {
      web.URL.revokeObjectURL(url);
    }
    _blobUrls.clear();
    await box.clear();
  }

  String _blobUrl(Uint8List bytes, String mimeType) {
    final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
    return web.URL.createObjectURL(blob);
  }

  @override
  Future<Uri> playableUri(String key, String mimeType) async {
    final cached = _blobUrls[key];
    if (cached != null) return Uri.parse(cached);
    final bytes = await read(key);
    if (bytes == null) throw StateError('File $key is missing');
    final url = _blobUrl(bytes, mimeType);
    _blobUrls[key] = url;
    return Uri.parse(url);
  }

  @override
  Future<Uri> ephemeralUri(String name, Uint8List bytes, String mimeType) async {
    if (_lastEphemeral != null) web.URL.revokeObjectURL(_lastEphemeral!);
    final url = _blobUrl(bytes, mimeType);
    _lastEphemeral = url;
    return Uri.parse(url);
  }

  @override
  Future<StorageInfo> info() async {
    var used = 0;
    for (final v in box.values) {
      if (v is Uint8List) used += v.lengthInBytes;
    }
    try {
      final est = await web.window.navigator.storage.estimate().toDart;
      final quota = est.quota.toInt();
      final usage = est.usage.toInt();
      return StorageInfo(usedByApp: used, quota: quota, available: quota - usage);
    } catch (_) {
      return StorageInfo(usedByApp: used);
    }
  }

  @override
  Future<bool> requestPersistence() async {
    try {
      return (await web.window.navigator.storage.persist().toDart).toDart;
    } catch (_) {
      return false;
    }
  }
}
