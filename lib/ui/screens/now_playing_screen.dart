import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/util/format.dart';
import '../../services/app_services.dart';
import '../../services/lyrics_service.dart';
import '../actions.dart';
import '../shell/player_chrome.dart';
import '../widgets/artwork.dart';
import '../widgets/backgrounds.dart';
import '../widgets/controls.dart';
import '../widgets/progress.dart';
import 'lyrics_screen.dart';

/// The hero Now Playing experience. Two columns (artwork | lyrics) on wide
/// screens, a single column on phones.
class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final p = s.player;
    return Scaffold(
      body: MarbleBackground(
        veil: 0.78,
        child: SafeArea(
          child: ListenableBuilder(
            listenable: Listenable.merge([p, s.library]),
            builder: (context, _) {
              if (!p.hasMedia) {
                return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('Nothing is playing', style: AppText.h2),
                    const SizedBox(height: Space.md),
                    AppButton.secondary(label: 'Go back', onPressed: () => context.pop()),
                  ]),
                );
              }
              final wide = MediaQuery.sizeOf(context).width >= Breakpoints.desktop;
              final current = p.current;
              final lyricsSrc = current == null ? null : LyricsService.sourceTrackOf(current);
              final showLyrics = lyricsSrc != null && s.lyrics.available(lyricsSrc);
              final player = _PlayerColumn(wide: wide);
              if (wide && showLyrics) {
                return Column(children: [
                  _TopBar(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(Space.x5, Space.lg, Space.x5, Space.x4),
                      child: Row(children: [
                        Expanded(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: player))),
                        const SizedBox(width: Space.x4),
                        Expanded(
                          child: AppCard(
                            opacity: 0.55,
                            radius: Radii.xl,
                            padding: const EdgeInsets.all(Space.xxl),
                            child: LyricsPanel(source: lyricsSrc),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ]);
              }
              return Column(children: [
                _TopBar(),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: Space.xxl, vertical: Space.lg),
                      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: player),
                    ),
                  ),
                ),
              ]);
            },
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.services.player;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xs),
      child: Row(children: [
        CircleIconButton(icon: LucideIcons.chevronDown, tooltip: 'Close player', filled: false, onPressed: () => context.pop()),
        Expanded(
          child: Column(children: [
            Text(p.isPreview ? 'PREVIEW FROM ${p.previewSource!.sourceName.toUpperCase()}' : 'PLAYING FROM DEVICE',
                style: AppText.metadata.muted),
            Text(p.isPreview ? '30-second clip' : 'Your library', style: AppText.h3),
          ]),
        ),
        CircleIconButton(
          icon: LucideIcons.listMusic,
          tooltip: 'Up next',
          filled: false,
          onPressed: p.isPreview ? null : () => context.push('/queue'),
        ),
      ]),
    );
  }
}

class _PlayerColumn extends StatelessWidget {
  const _PlayerColumn({required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final p = s.player;
    final current = p.current;
    final fav = current != null && s.library.isFavorite(current.id);
    final lyricsSrc = current == null ? null : LyricsService.sourceTrackOf(current);
    final hasLyrics = lyricsSrc != null && s.lyrics.available(lyricsSrc);
    final artSize = (MediaQuery.sizeOf(context).width - 48).clamp(220.0, wide ? 440.0 : 340.0);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Hero(
        tag: 'now-playing-art',
        child: Artwork(
          seed: p.artSeed,
          size: artSize,
          radius: 30,
          shadow: [
            BoxShadow(color: AppColors.lightBlue.withValues(alpha: 0.28), offset: const Offset(0, 18), blurRadius: 50, spreadRadius: -10),
            const BoxShadow(color: Color(0x8C030A16), offset: Offset(0, 24), blurRadius: 40, spreadRadius: -12),
          ],
        ),
      ),
      const SizedBox(height: Space.x3),
      Row(children: [
        if (current != null)
          CircleIconButton(
            icon: LucideIcons.heart,
            tooltip: fav ? 'Remove from favorites' : 'Add to favorites',
            filled: false,
            color: fav ? AppColors.accent : AppColors.textSecondary,
            onPressed: () => s.library.toggleFavorite(current.id),
          )
        else
          const SizedBox(width: 44),
        Expanded(
          child: Column(children: [
            Text(p.title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.h1),
            const SizedBox(height: 4),
            Text(p.artist, textAlign: TextAlign.center, style: AppText.body.secondaryColor),
          ]),
        ),
        if (current != null)
          CircleIconButton(
            icon: LucideIcons.ellipsis,
            tooltip: 'More options',
            filled: false,
            color: AppColors.textSecondary,
            onPressed: () => showTrackActions(context, current),
          )
        else
          const SizedBox(width: 44),
      ]),
      const SizedBox(height: Space.xl),
      StreamBuilder<Duration>(
        stream: p.position,
        builder: (context, snap) {
          final pos = snap.data ?? Duration.zero;
          final dur = p.duration;
          return Column(children: [
            WaveformScrubber(seed: p.artSeed.hashCode, position: pos, duration: dur, onSeek: p.seek),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(formatDuration(pos), style: AppText.caption.secondaryColor),
              Text(dur > pos ? '-${formatDuration(dur - pos)}' : '0:00', style: AppText.caption.muted),
            ]),
          ]);
        },
      ),
      const SizedBox(height: Space.xl),
      const TransportControls(),
      const SizedBox(height: Space.x3),
      if (current != null)
        Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: Space.sm, children: [
          if (hasLyrics && !wide) _Pill(LucideIcons.textQuote, 'Lyrics', () => context.push('/lyrics', extra: lyricsSrc)),
          _Pill(LucideIcons.listPlus, 'Add', () => showAddToPlaylist(context, current.id)),
          _Pill(LucideIcons.share2, 'Share', () => shareTrack(context, current)),
          _Pill(LucideIcons.listMusic, 'Up Next', () => context.push('/queue')),
        ])
      else if (p.isPreview)
        Text('Previews are short clips from ${p.previewSource!.sourceName}. Download the song to keep it.',
            textAlign: TextAlign.center, style: AppText.caption.muted),
      if (p.lastError != null) ...[
        const SizedBox(height: Space.md),
        Text(p.lastError!, style: AppText.caption.tint(AppColors.error)),
      ],
    ]);
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surfacePrimary.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(label, style: AppText.caption.secondaryColor),
            ]),
          ),
        ),
      );
}
