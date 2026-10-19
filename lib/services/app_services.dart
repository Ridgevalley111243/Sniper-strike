import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/storage/file_store.dart';
import '../data/storage/local_store.dart';
import '../sources/source_manager.dart';
import 'ads/rewarded_ads.dart';
import 'connectivity_service.dart';
import 'download_manager.dart';
import 'import_service.dart';
import 'library_repository.dart';
import 'lyrics_service.dart';
import 'player_controller.dart';
import 'playlist_repository.dart';
import 'search_controller.dart';
import 'settings_controller.dart';
import 'share_service.dart';

/// Composition root: every long-lived service, created once at startup.
class AppServices {
  AppServices._({
    required this.settings,
    required this.sources,
    required this.library,
    required this.playlists,
    required this.search,
    required this.player,
    required this.downloads,
    required this.lyrics,
    required this.share,
    required this.importer,
    required this.network,
  });

  final SettingsController settings;
  final SourceManager sources;
  final LibraryRepository library;
  final PlaylistRepository playlists;
  final MusicSearchController search;
  final PlayerController player;
  final DownloadManager downloads;
  final LyricsService lyrics;
  final ShareService share;
  final ImportService importer;
  final ConnectivityService network;

  static Future<AppServices> create({RewardedAdProvider ads = const DemoRewardedAdProvider()}) async {
    final prefs = await SharedPreferences.getInstance();
    final store = await LocalStore.open();
    final files = await FileStore.open();
    final settings = SettingsController(prefs);
    final sources = SourceManager(prefs);
    final library = LibraryRepository(store, files);
    final playlists = PlaylistRepository(store);
    final network = ConnectivityService();
    final downloads = DownloadManager(sources, library, settings, network);
    network.addListener(downloads.onNetworkChanged);
    if (!settings.starterPlaylistsCreated) {
      for (final name in PlaylistRepository.starterNames) {
        await playlists.create(name);
      }
      await settings.markStarterPlaylists();
    }
    return AppServices._(
      settings: settings,
      sources: sources,
      library: library,
      playlists: playlists,
      search: MusicSearchController(sources),
      player: PlayerController(library, files, sources, autoplayEnabled: () => settings.autoplay, isOnline: () => network.isOnline),
      downloads: downloads,
      lyrics: LyricsService(sources, library, settings, ads),
      share: ShareService(files),
      importer: ImportService(library),
      network: network,
    );
  }

  /// Deletes a track everywhere it is referenced.
  Future<void> deleteTrack(String id) async {
    await player.forget(id);
    await playlists.forgetTrack(id);
    await library.remove(id);
  }
}

/// Makes [AppServices] available to the widget tree.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});
  final AppServices services;

  static AppServices of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.services;

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}

extension ServicesX on BuildContext {
  AppServices get services => AppScope.of(this);
}
