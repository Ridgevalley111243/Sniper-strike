import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/tokens.dart';
import 'router.dart';
import 'services/app_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Background playback with a media notification + lock-screen controls.
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.truhive.playback',
    androidNotificationChannelName: 'Playback',
    androidNotificationOngoing: true,
    notificationColor: AppColors.navy,
  );
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.navy,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  final services = await AppServices.create();
  runApp(TruHiveApp(services: services));
}

class TruHiveApp extends StatefulWidget {
  const TruHiveApp({super.key, required this.services});
  final AppServices services;

  @override
  State<TruHiveApp> createState() => _TruHiveAppState();
}

class _TruHiveAppState extends State<TruHiveApp> {
  late final GoRouter _router = buildRouter();
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  late final StreamSubscription<String> _notices = widget.services.player.notices.listen((message) {
    _messenger.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 3)));
  });

  @override
  void initState() {
    super.initState();
    _notices; // start listening
  }

  @override
  void dispose() {
    _notices.cancel();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: widget.services,
      child: MaterialApp.router(
        title: 'TRUHive',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        darkTheme: buildAppTheme(),
        themeMode: ThemeMode.dark,
        routerConfig: _router,
        scaffoldMessengerKey: _messenger,
        builder: (context, child) => _KeyboardShortcuts(child: child ?? const SizedBox()),
      ),
    );
  }
}

/// Space = play/pause, ←/→ = seek on desktop and web.
class _KeyboardShortcuts extends StatelessWidget {
  const _KeyboardShortcuts({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.services.player;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.mediaPlayPause): p.togglePlay,
        const SingleActivator(LogicalKeyboardKey.mediaTrackNext): p.next,
        const SingleActivator(LogicalKeyboardKey.mediaTrackPrevious): p.previous,
        const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true): () => p.seek(p.positionNow + const Duration(seconds: 10)),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): () => p.seek(p.positionNow - const Duration(seconds: 10)),
      },
      child: child,
    );
  }
}
