import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/models/models.dart';
import 'ui/screens/downloads_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/library_screens.dart';
import 'ui/screens/lyrics_screen.dart';
import 'ui/screens/manage_screens.dart';
import 'ui/screens/now_playing_screen.dart';
import 'ui/screens/onboarding_screens.dart';
import 'ui/screens/search_screen.dart';
import 'ui/screens/track_details_screen.dart';
import 'ui/shell/app_shell.dart';
import 'ui/widgets/page.dart';
import 'ui/widgets/states.dart';

final _rootKey = GlobalKey<NavigatorState>();

CustomTransitionPage<void> _fade(GoRouterState s, Widget child) => CustomTransitionPage<void>(
      key: s.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 240),
      transitionsBuilder: (context, a, _, c) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: c,
        ),
      ),
    );

CustomTransitionPage<void> _slideUp(GoRouterState s, Widget child) => CustomTransitionPage<void>(
      key: s.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      transitionsBuilder: (context, a, _, c) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
        child: c,
      ),
    );

Widget _missing(String what) => DetailScaffold(
      child: PageBody(back: true, slivers: [
        box(EmptyState(
          icon: Icons.music_off_outlined,
          title: '$what isn’t available',
          message: 'Open it again from Search or your Library.',
        )),
      ]),
    );

GoRouter buildRouter() => GoRouter(
      navigatorKey: _rootKey,
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', pageBuilder: (c, s) => _fade(s, const SplashScreen())),
        GoRoute(path: '/welcome', pageBuilder: (c, s) => _fade(s, const WelcomeScreen())),
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(shell: shell),
          branches: [
            StatefulShellBranch(routes: [GoRoute(path: '/home', pageBuilder: (c, s) => _fade(s, const HomeScreen()))]),
            StatefulShellBranch(routes: [GoRoute(path: '/search', pageBuilder: (c, s) => _fade(s, const SearchScreen()))]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/library',
                pageBuilder: (c, s) => _fade(s, LibraryScreen(initialTab: s.uri.queryParameters['tab'])),
              ),
            ]),
            StatefulShellBranch(routes: [GoRoute(path: '/downloads', pageBuilder: (c, s) => _fade(s, const DownloadsScreen()))]),
          ],
        ),
        GoRoute(
          path: '/track',
          parentNavigatorKey: _rootKey,
          pageBuilder: (c, s) => _fade(s, s.extra is TrackGroup ? TrackDetailsScreen(group: s.extra! as TrackGroup) : _missing('This song')),
        ),
        GoRoute(path: '/now-playing', parentNavigatorKey: _rootKey, pageBuilder: (c, s) => _slideUp(s, const NowPlayingScreen())),
        GoRoute(path: '/queue', parentNavigatorKey: _rootKey, pageBuilder: (c, s) => _slideUp(s, const QueueScreen())),
        GoRoute(
          path: '/lyrics',
          parentNavigatorKey: _rootKey,
          pageBuilder: (c, s) => _slideUp(s, s.extra is SourceTrack ? LyricsScreen(source: s.extra! as SourceTrack) : _missing('Lyrics')),
        ),
        GoRoute(
          path: '/playlist/:id',
          parentNavigatorKey: _rootKey,
          pageBuilder: (c, s) => _fade(s, PlaylistScreen(id: s.pathParameters['id']!)),
        ),
        GoRoute(path: '/favorites', parentNavigatorKey: _rootKey, pageBuilder: (c, s) => _fade(s, const FavoritesScreen())),
        GoRoute(path: '/sources', parentNavigatorKey: _rootKey, pageBuilder: (c, s) => _fade(s, const SourcesScreen())),
        GoRoute(path: '/settings', parentNavigatorKey: _rootKey, pageBuilder: (c, s) => _fade(s, const SettingsScreen())),
      ],
    );
