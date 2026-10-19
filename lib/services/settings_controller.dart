import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight preferences (shared_preferences = localStorage on the web).
class SettingsController extends ChangeNotifier {
  SettingsController(this._p);
  final SharedPreferences _p;

  bool _b(String k, bool d) => _p.getBool(k) ?? d;
  Future<void> _set(String k, bool v) async {
    await _p.setBool(k, v);
    notifyListeners();
  }

  bool get onboardingDone => _b('onboarding.done', false);
  Future<void> completeOnboarding() => _set('onboarding.done', true);

  bool get autoplay => _b('playback.autoplay', true);
  set autoplay(bool v) => _set('playback.autoplay', v);

  bool get autoAddDownloads => _b('downloads.autoAdd', true);
  set autoAddDownloads(bool v) => _set('downloads.autoAdd', v);

  bool get wifiOnlyDownloads => _b('downloads.wifiOnly', false);
  set wifiOnlyDownloads(bool v) => _set('downloads.wifiOnly', v);

  bool get lyricsPreview => _b('lyrics.enabled', true);
  set lyricsPreview(bool v) => _set('lyrics.enabled', v);

  bool get rewardedAds => _b('ads.rewarded', true);
  set rewardedAds(bool v) => _set('ads.rewarded', v);

  bool get starterPlaylistsCreated => _b('playlists.starter', false);
  Future<void> markStarterPlaylists() => _set('playlists.starter', true);
}
