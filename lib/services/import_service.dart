import 'package:file_picker/file_picker.dart';

import '../core/models/models.dart';
import 'library_repository.dart';

/// Copies audio files the user picks (from the device's Music folder, Files
/// app, etc.) into TRUHive so they appear in the library and play offline.
class ImportService {
  ImportService(this._library);
  final LibraryRepository _library;

  static const _mime = {
    'mp3': 'audio/mpeg',
    'm4a': 'audio/mp4',
    'aac': 'audio/aac',
    'wav': 'audio/wav',
    'ogg': 'audio/ogg',
    'opus': 'audio/ogg',
    'flac': 'audio/flac',
  };

  /// Returns the number of files imported, or null if the user cancelled.
  Future<int?> pickAndImport() async {
    final files = await FilePicker.pickFiles(type: FileType.audio, dialogTitle: 'Import music');
    if (files.isEmpty) return null;
    var n = 0;
    final now = DateTime.now().microsecondsSinceEpoch;
    for (final f in files) {
      final bytes = await f.readAsBytes();
      final ext = (f.extension ?? 'mp3').toLowerCase();
      final base = f.name.replaceAll(RegExp(r'\.[^.]+$'), '');
      final parts = base.split(RegExp(r'\s+-\s+'));
      final artist = parts.length > 1 ? parts.first.trim() : 'Unknown artist';
      final title = parts.length > 1 ? parts.sublist(1).join(' - ').trim() : base.trim();
      final id = 'local:$now-$n';
      final key = 'import_$now-$n.$ext';
      await _library.files.save(key, bytes);
      await _library.add(Track(
        id: id,
        title: title.isEmpty ? f.name : title,
        artist: artist,
        album: 'Imported',
        duration: Duration.zero, // filled in the first time the track plays
        artSeed: f.name,
        origin: TrackOrigin.import,
        fileKey: key,
        fileName: f.name,
        sizeBytes: bytes.lengthInBytes,
        mimeType: _mime[ext] ?? 'audio/$ext',
        addedAt: DateTime.now(),
      ));
      n++;
    }
    return n;
  }
}
