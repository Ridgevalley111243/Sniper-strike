import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/models/models.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../services/app_services.dart';
import '../actions.dart';
import '../shell/player_chrome.dart';
import '../widgets/artwork.dart';
import '../widgets/backgrounds.dart';
import '../widgets/controls.dart';
import '../widgets/states.dart';

class LyricsScreen extends StatelessWidget {
  const LyricsScreen({super.key, required this.source});
  final SourceTrack source;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.desktop;
    return Scaffold(
      extendBody: true,
      body: MarbleBackground(
        veil: 0.8,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xs),
                  child: Row(children: [
                    CircleIconButton(icon: LucideIcons.chevronDown, tooltip: 'Close lyrics', filled: false, onPressed: () => context.pop()),
                    Expanded(child: Text('Lyrics', textAlign: TextAlign.center, style: AppText.h3)),
                    const SizedBox(width: 44),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.sm),
                  child: Row(children: [
                    Artwork(seed: source.artSeed, size: 56, radius: 14),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(source.title, style: AppText.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(source.artist, style: AppText.secondary.muted),
                      ]),
                    ),
                  ]),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.xl, Space.md, Space.xl, 0),
                    child: LyricsPanel(source: source),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
      bottomNavigationBar: wide
          ? const PlayerBar()
          : const Column(mainAxisSize: MainAxisSize.min, children: [
              SafeArea(
                top: false,
                minimum: EdgeInsets.only(bottom: Space.sm),
                child: Padding(padding: EdgeInsets.symmetric(horizontal: Space.lg), child: MiniPlayer()),
              ),
            ]),
    );
  }
}

/// Locked (rewarded ad) → loading → synced/plain lyrics, or an error state.
class LyricsPanel extends StatefulWidget {
  const LyricsPanel({super.key, required this.source});
  final SourceTrack source;

  @override
  State<LyricsPanel> createState() => _LyricsPanelState();
}

class _LyricsPanelState extends State<LyricsPanel> {
  Future<Lyrics?>? _future;
  bool _unlocking = false;
  final _keys = <int, GlobalKey>{};
  int _lastActive = -1;

  void _load() => _future = context.services.lyrics.fetch(widget.source);

  @override
  void didUpdateWidget(LyricsPanel old) {
    super.didUpdateWidget(old);
    if (old.source.localId != widget.source.localId) {
      _future = null;
      _lastActive = -1;
    }
  }

  Future<void> _unlock() async {
    setState(() => _unlocking = true);
    final ok = await context.services.lyrics.unlock(context, widget.source);
    if (!mounted) return;
    setState(() => _unlocking = false);
    if (!ok) showToast(context, 'Lyrics stay locked — the ad was not completed.');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    return ListenableBuilder(
      listenable: s.library,
      builder: (context, _) {
        if (!s.lyrics.isUnlocked(widget.source)) return _locked(context);
        _future ??= (() {
          _load();
          return _future;
        })();
        return FutureBuilder<Lyrics?>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return ListView(children: [for (var i = 0; i < 6; i++) Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Skeleton(width: 220 + (i % 3) * 40.0, height: 18, radius: 9),
              )]);
            }
            if (snap.hasError) {
              return EmptyState(
                icon: LucideIcons.textQuote,
                title: "We couldn't load these lyrics",
                message: '${widget.source.sourceName} did not respond. Your music still plays normally.',
                primary: 'Retry',
                onPrimary: () => setState(_load),
              );
            }
            final lyrics = snap.data;
            if (lyrics == null || lyrics.lines.isEmpty) {
              return const EmptyState(
                icon: LucideIcons.textQuote,
                title: 'No lyrics for this song',
                message: 'The source does not provide lyrics for this track.',
              );
            }
            return _lines(context, lyrics);
          },
        );
      },
    );
  }

  Widget _lines(BuildContext context, Lyrics lyrics) {
    final p = context.services.player;
    final isCurrent = p.current?.id == widget.source.localId;
    return StreamBuilder<Duration>(
      stream: isCurrent && lyrics.synced ? p.position : const Stream.empty(),
      builder: (context, snap) {
        final pos = snap.data;
        var active = -1;
        if (pos != null) {
          for (var i = 0; i < lyrics.lines.length; i++) {
            final t = lyrics.lines[i].time;
            if (t != null && t <= pos) active = i;
          }
        }
        if (active != _lastActive && active >= 0) {
          _lastActive = active;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final c = _keys[active]?.currentContext;
            if (c != null) {
              Scrollable.ensureVisible(c,
                  alignment: 0.35,
                  duration: MediaQuery.of(context).disableAnimations ? Duration.zero : Motion.slow,
                  curve: Curves.easeOutCubic);
            }
          });
        }
        return ListView(padding: const EdgeInsets.only(bottom: 120), children: [
          for (var i = 0; i < lyrics.lines.length; i++)
            Padding(
              key: _keys.putIfAbsent(i, GlobalKey.new),
              padding: const EdgeInsets.only(bottom: 20),
              child: GestureDetector(
                onTap: isCurrent && lyrics.lines[i].time != null ? () => p.seek(lyrics.lines[i].time!) : null,
                child: AnimatedDefaultTextStyle(
                  duration: Motion.normal,
                  style: (i == active ? AppText.h1 : AppText.h2).copyWith(
                    color: i == active
                        ? AppColors.textPrimary
                        : i < active
                            ? AppColors.textMuted.withValues(alpha: 0.6)
                            : AppColors.textSecondary.withValues(alpha: active < 0 ? 0.95 : 0.75),
                    shadows: i == active ? [Shadow(color: AppColors.lightBlue.withValues(alpha: 0.45), blurRadius: 18)] : null,
                  ),
                  child: Text(lyrics.lines[i].text),
                ),
              ),
            ),
          Text(
            '${lyrics.synced ? 'Synced lyrics' : 'Lyrics'} · provided by ${lyrics.providerName}',
            style: AppText.caption.muted,
          ),
        ]);
      },
    );
  }

  Widget _locked(BuildContext context) {
    final ads = context.services.lyrics.ads;
    return Stack(children: [
      ExcludeSemantics(
        child: Opacity(
          opacity: 0.35,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final w in [260.0, 220.0, 280.0, 240.0, 200.0])
              Padding(padding: const EdgeInsets.only(bottom: 18), child: Skeleton(width: w, height: 20, radius: 10)),
          ]),
        ),
      ),
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: AppColors.borderStrong),
              boxShadow: Effects.elevation,
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accent.withValues(alpha: 0.14)),
                child: const Icon(LucideIcons.lock, color: AppColors.accent, size: 24),
              ),
              const SizedBox(height: Space.md),
              Text('Unlock Lyrics', style: AppText.h2),
              const SizedBox(height: Space.sm),
              Text('Watch a short advertisement to unlock the lyrics for this song.',
                  textAlign: TextAlign.center, style: AppText.secondary.secondaryColor),
              const SizedBox(height: Space.lg),
              AppButton(label: 'Watch Ad', icon: LucideIcons.tv, expand: true, loading: _unlocking, onPressed: _unlock),
              const SizedBox(height: Space.xs),
              AppButton.ghost(label: 'Not now', onPressed: () => context.pop()),
              const SizedBox(height: Space.xs),
              Text(
                'Lyrics licensed via ${widget.source.sourceName}${ads.isDemo ? ' · demo ad slot' : ''}',
                textAlign: TextAlign.center,
                style: AppText.caption.muted,
              ),
            ]),
          ),
        ),
      ),
    ]);
  }
}
