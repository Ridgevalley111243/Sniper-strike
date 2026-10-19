import 'package:share_plus/share_plus.dart';

import '../core/models/models.dart';
import '../data/storage/file_store.dart';
import 'exporter/exporter.dart';

enum ShareOutcome { shared, dismissed, exported, unavailable, failed }

/// Shares the actual audio file through the platform share sheet (Android
/// Sharesheet: WhatsApp, Telegram, Bluetooth, Quick Share, Files, Gmail…;
/// Web Share API in browsers). Nothing is uploaded to a TRUHive server.
class ShareService {
  ShareService(this._files);
  final FileStore _files;

  Future<ShareOutcome> shareTrack(Track t) async {
    final bytes = await _files.read(t.fileKey);
    if (bytes == null) return ShareOutcome.failed;
    try {
      final r = await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(bytes, name: t.fileName, mimeType: t.mimeType)],
        fileNameOverrides: [t.fileName],
        title: t.title,
        text: '${t.title} — ${t.artist}',
        downloadFallbackEnabled: false,
        mailToFallbackEnabled: false,
      ));
      return switch (r.status) {
        ShareResultStatus.success => ShareOutcome.shared,
        ShareResultStatus.dismissed => ShareOutcome.dismissed,
        ShareResultStatus.unavailable => await _fallback(t, bytes),
      };
    } catch (_) {
      return _fallback(t, bytes);
    }
  }

  // When file sharing is not supported, offer a plain export instead.
  Future<ShareOutcome> _fallback(Track t, List<int> bytes) async =>
      await exportBytes(t.fileName, bytes, t.mimeType) ? ShareOutcome.exported : ShareOutcome.unavailable;

  /// Saves a copy outside TRUHive (system "Save as" dialog / browser download).
  Future<bool> exportToDevice(Track t) async {
    final bytes = await _files.read(t.fileKey);
    if (bytes == null) return false;
    return exportBytes(t.fileName, bytes, t.mimeType);
  }
}
