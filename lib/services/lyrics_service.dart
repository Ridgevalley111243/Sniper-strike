import 'package:flutter/widgets.dart';

import '../core/models/models.dart';
import '../sources/source_manager.dart';
import 'ads/rewarded_ads.dart';
import 'library_repository.dart';
import 'settings_controller.dart';

/// Lyrics from authorized sources only, unlocked per song with a rewarded ad.
class LyricsService {
  LyricsService(this._sources, this._library, this._settings, this.ads);

  final SourceManager _sources;
  final LibraryRepository _library;
  final SettingsController _settings;
  final RewardedAdProvider ads;
  final Map<String, Lyrics?> _cache = {};

  static SourceTrack sourceTrackOf(Track t) => SourceTrack(
        sourceId: t.sourceId ?? 'local',
        sourceName: t.sourceName ?? 'This device',
        sourceTrackId: t.sourceTrackId ?? t.id,
        title: t.title,
        artist: t.artist,
        album: t.album,
        duration: t.duration,
        artSeed: t.artSeed,
        lyricsAvailable: t.lyricsAvailable,
      );

  bool get enabled => _settings.lyricsPreview;

  /// True only when a source that permits lyrics display has them.
  bool available(SourceTrack s) {
    if (!enabled || !s.lyricsAvailable) return false;
    final src = _sources.byId(s.sourceId);
    return src != null && src.capabilities.lyrics;
  }

  bool isUnlocked(SourceTrack s) => _library.lyricsUnlocked(s.localId) || !_settings.rewardedAds;

  Future<bool> unlock(BuildContext context, SourceTrack s) async {
    final ok = await ads.showRewarded(context);
    if (ok) await _library.unlockLyrics(s.localId);
    return ok;
  }

  Future<Lyrics?> fetch(SourceTrack s) async {
    if (_cache.containsKey(s.localId)) return _cache[s.localId];
    final src = _sources.byId(s.sourceId);
    if (src == null) return null;
    final l = await src.getLyrics(s);
    _cache[s.localId] = l;
    return l;
  }
}
