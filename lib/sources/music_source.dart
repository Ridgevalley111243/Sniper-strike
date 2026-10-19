import 'dart:typed_data';

import '../core/models/models.dart';

/// Thrown when a source cannot be reached. The search engine isolates these
/// so one failing source never breaks the others.
class SourceUnavailableException implements Exception {
  const SourceUnavailableException(this.sourceName, [this.reason]);
  final String sourceName;
  final String? reason;
  @override
  String toString() => 'SourceUnavailableException($sourceName${reason == null ? '' : ': $reason'})';
}

class UnsupportedCapabilityException implements Exception {
  const UnsupportedCapabilityException(this.capability);
  final String capability;
}

/// A short audio clip the user can listen to before downloading.
class PreviewAudio {
  const PreviewAudio({this.uri, this.bytes, required this.mimeType, required this.length})
      : assert(uri != null || bytes != null);
  final Uri? uri;
  final Uint8List? bytes;
  final String mimeType;
  final Duration length;
}

/// A byte stream for an authorized download, starting at [fromByte].
class DownloadStream {
  const DownloadStream({
    required this.totalBytes,
    required this.fromByte,
    required this.bytes,
    required this.mimeType,
    required this.fileExtension,
    required this.supportsResume,
  });
  final int totalBytes;
  final int fromByte;
  final Stream<List<int>> bytes;
  final String mimeType;
  final String fileExtension;
  final bool supportsResume;
}

enum SourceHealth { unknown, checking, available, unavailable }

/// Contract every music provider adapter implements. A source only needs to
/// implement the capabilities it declares; the UI never offers the others.
abstract class MusicSource {
  String get id;
  String get name;

  /// Two-letter monogram used where a provider logo would appear.
  String get monogram;
  String get description;

  /// Demo adapters generate their own original audio so the whole app can be
  /// exercised without a real provider. They are labeled as demos in the UI.
  bool get isDemo;

  SourceCapabilities get capabilities;

  Future<List<SourceTrack>> search(String query);

  Future<PreviewAudio> getPreview(SourceTrack track) => throw const UnsupportedCapabilityException('preview');

  /// Full-length audio to play over the internet, where the source allows it.
  Uri? streamUri(String sourceTrackId) => null;

  Future<DownloadStream> openDownload(SourceTrack track, {int fromByte = 0}) =>
      throw const UnsupportedCapabilityException('download');

  Future<Lyrics?> getLyrics(SourceTrack track) async => null;

  /// Lightweight reachability probe used by the Source Manager.
  Future<bool> ping();
}
