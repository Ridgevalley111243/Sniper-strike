import 'dart:typed_data';

import 'file_store_io.dart' if (dart.library.js_interop) 'file_store_web.dart' as impl;

class StorageInfo {
  const StorageInfo({required this.usedByApp, this.available, this.quota});

  /// Bytes TRUHive's own audio files occupy.
  final int usedByApp;

  /// Bytes still available to the app, when the platform reports it reliably.
  final int? available;
  final int? quota;
}

/// Where audio files physically live.
///
/// * Android / iOS / desktop: real files inside the app's "TRUHive Music"
///   folder (see [locationDescription]).
/// * Web: the browser's private storage (IndexedDB). Browsers do not allow
///   writing into arbitrary device folders, so "Save to device" exports a copy
///   through the browser's normal download flow instead.
abstract class FileStore {
  static Future<FileStore> open() => impl.openFileStore();

  String get locationDescription;
  bool get isBrowserStorage;

  Future<void> save(String key, Uint8List bytes);
  Future<Uint8List?> read(String key);
  Future<bool> exists(String key);
  Future<void> delete(String key);
  Future<void> clear();

  /// A URI the audio player can open for a stored file.
  Future<Uri> playableUri(String key, String mimeType);

  /// A URI for bytes that should not be kept (previews).
  Future<Uri> ephemeralUri(String name, Uint8List bytes, String mimeType);

  Future<StorageInfo> info();

  /// Ask the platform not to evict TRUHive's data under storage pressure.
  Future<bool> requestPersistence();
}
