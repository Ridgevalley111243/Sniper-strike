// Core TRUHive data models. Provider-specific data never leaves the source
// adapters: everything the UI sees is one of these normalized shapes.

/// What a music source is able to do. The UI only offers an action when the
/// source that would perform it declares the capability.
class SourceCapabilities {
  const SourceCapabilities({this.search = true, this.preview = false, this.download = false, this.lyrics = false});
  final bool search;
  final bool preview;
  final bool download;
  final bool lyrics;
}

/// One search hit from one source (the normalized TRUHive result model).
class SourceTrack {
  const SourceTrack({
    required this.sourceId,
    required this.sourceName,
    required this.sourceTrackId,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.artSeed,
    this.genre,
    this.year,
    this.previewAvailable = false,
    this.downloadAvailable = false,
    this.lyricsAvailable = false,
    this.format,
    this.sizeBytes,
  });

  final String sourceId;
  final String sourceName;
  final String sourceTrackId;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final String artSeed;
  final String? genre;
  final int? year;
  final bool previewAvailable;
  final bool downloadAvailable;
  final bool lyricsAvailable;
  final String? format;
  final int? sizeBytes;

  /// Stable id of the local copy if this result is downloaded.
  String get localId => '$sourceId:$sourceTrackId';
}

/// Several [SourceTrack]s that represent the same recording, grouped so the
/// user sees one result with "Available from N sources".
class TrackGroup {
  TrackGroup(this.key, List<SourceTrack> sources) : sources = List.of(sources);

  final String key;
  final List<SourceTrack> sources;

  SourceTrack get primary => sources.first;
  String get title => primary.title;
  String get artist => primary.artist;
  String get album => primary.album;
  Duration get duration => primary.duration;
  String get artSeed => primary.artSeed;
  String? get genre => sources.map((s) => s.genre).firstWhere((g) => g != null, orElse: () => null);
  int? get year => sources.map((s) => s.year).firstWhere((y) => y != null, orElse: () => null);

  bool get canPreview => sources.any((s) => s.previewAvailable);
  bool get canDownload => sources.any((s) => s.downloadAvailable);
  bool get hasLyrics => sources.any((s) => s.lyricsAvailable);

  SourceTrack? get previewSource => _first((s) => s.previewAvailable);
  SourceTrack? get downloadSource => _first((s) => s.downloadAvailable);

  SourceTrack? _first(bool Function(SourceTrack) test) {
    for (final s in sources) {
      if (test(s)) return s;
    }
    return null;
  }
}

enum TrackOrigin { download, import }

/// A track that physically lives on this device.
class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.artSeed,
    required this.origin,
    required this.fileKey,
    required this.fileName,
    required this.sizeBytes,
    required this.mimeType,
    required this.addedAt,
    this.genre,
    this.year,
    this.sourceId,
    this.sourceName,
    this.sourceTrackId,
    this.lyricsAvailable = false,
    this.inLibrary = true,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final String artSeed;
  final TrackOrigin origin;
  final String fileKey;
  final String fileName;
  final int sizeBytes;
  final String mimeType;
  final DateTime addedAt;
  final String? genre;
  final int? year;
  final String? sourceId;
  final String? sourceName;
  final String? sourceTrackId;
  final bool lyricsAvailable;

  /// False when "Automatically add downloads to library" is off: the file is
  /// kept in Downloads but not listed in Library until the user adds it.
  final bool inLibrary;

  Track copyWith({Duration? duration, String? title, String? artist, bool? inLibrary}) => Track(
        id: id,
        title: title ?? this.title,
        artist: artist ?? this.artist,
        album: album,
        duration: duration ?? this.duration,
        artSeed: artSeed,
        origin: origin,
        fileKey: fileKey,
        fileName: fileName,
        sizeBytes: sizeBytes,
        mimeType: mimeType,
        addedAt: addedAt,
        genre: genre,
        year: year,
        sourceId: sourceId,
        sourceName: sourceName,
        sourceTrackId: sourceTrackId,
        lyricsAvailable: lyricsAvailable,
        inLibrary: inLibrary ?? this.inLibrary,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'durationMs': duration.inMilliseconds,
        'artSeed': artSeed,
        'origin': origin.name,
        'fileKey': fileKey,
        'fileName': fileName,
        'sizeBytes': sizeBytes,
        'mimeType': mimeType,
        'addedAt': addedAt.millisecondsSinceEpoch,
        'genre': genre,
        'year': year,
        'sourceId': sourceId,
        'sourceName': sourceName,
        'sourceTrackId': sourceTrackId,
        'lyricsAvailable': lyricsAvailable,
        'inLibrary': inLibrary,
      };

  factory Track.fromJson(Map<dynamic, dynamic> j) => Track(
        id: j['id'] as String,
        title: j['title'] as String,
        artist: j['artist'] as String,
        album: (j['album'] as String?) ?? '',
        duration: Duration(milliseconds: (j['durationMs'] as num?)?.toInt() ?? 0),
        artSeed: j['artSeed'] as String,
        origin: TrackOrigin.values.byName(j['origin'] as String),
        fileKey: j['fileKey'] as String,
        fileName: j['fileName'] as String,
        sizeBytes: (j['sizeBytes'] as num).toInt(),
        mimeType: j['mimeType'] as String,
        addedAt: DateTime.fromMillisecondsSinceEpoch((j['addedAt'] as num).toInt()),
        genre: j['genre'] as String?,
        year: (j['year'] as num?)?.toInt(),
        sourceId: j['sourceId'] as String?,
        sourceName: j['sourceName'] as String?,
        sourceTrackId: j['sourceTrackId'] as String?,
        lyricsAvailable: (j['lyricsAvailable'] as bool?) ?? false,
        inLibrary: (j['inLibrary'] as bool?) ?? true,
      );
}

class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.trackIds,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final List<String> trackIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  Playlist copyWith({String? name, List<String>? trackIds}) => Playlist(
        id: id,
        name: name ?? this.name,
        trackIds: trackIds ?? this.trackIds,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'trackIds': trackIds,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  factory Playlist.fromJson(Map<dynamic, dynamic> j) => Playlist(
        id: j['id'] as String,
        name: j['name'] as String,
        trackIds: List<String>.from(j['trackIds'] as List),
        createdAt: DateTime.fromMillisecondsSinceEpoch((j['createdAt'] as num).toInt()),
        updatedAt: DateTime.fromMillisecondsSinceEpoch((j['updatedAt'] as num).toInt()),
      );
}

enum DownloadStatus { queued, downloading, paused, saving, completed, failed, canceled }

class LyricLine {
  const LyricLine(this.time, this.text);
  final Duration? time;
  final String text;
}

class Lyrics {
  const Lyrics({required this.lines, required this.providerName, required this.synced});
  final List<LyricLine> lines;
  final String providerName;
  final bool synced;
}
