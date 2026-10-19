import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/models/models.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/util/format.dart';
import '../../services/app_services.dart';
import '../shell/app_shell.dart';
import '../widgets/artwork.dart';
import '../widgets/controls.dart';
import '../widgets/page.dart';
import '../widgets/rows.dart';
import '../widgets/states.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    return ListenableBuilder(
      listenable: Listenable.merge([s.library, s.playlists, s.network]),
      builder: (context, _) {
        final lib = s.library;
        final recentDl = lib.tracks.where((t) => t.origin == TrackOrigin.download).take(10).toList();
        final played = lib.recentlyPlayed.take(5).toList();
        final count = lib.tracks.length;
        return PageBody(slivers: [
          box(Row(children: [
            // The sidebar already carries the brand on wide screens.
            if (MediaQuery.sizeOf(context).width < Breakpoints.desktop) ...[
              const LogoMark(size: 30, glow: false),
              const SizedBox(width: 10),
              Text('TRUHive', style: AppText.h2),
            ],
            const Spacer(),
            CircleIconButton(icon: LucideIcons.settings, tooltip: 'Settings', onPressed: () => context.push('/settings')),
          ])),
          gap(Space.xl),
          box(Semantics(header: true, child: Text(greetingFor(DateTime.now()), style: AppText.h1))),
          gap(Space.xs),
          box(Text(
            count == 0 ? 'Your music. Your device.' : '$count ${count == 1 ? 'song' : 'songs'} saved on this device',
            style: AppText.secondary.muted,
          )),
          gap(Space.xl),
          if (!s.network.isOnline) ...[
            box(const OfflineBanner(message: 'Your downloaded music is still available.')),
            gap(Space.lg),
          ],
          box(AppSearchField(readOnly: true, onTap: () => context.go('/search'))),
          gap(Space.xl),
          box(_QuickAccess(
            items: [
              (LucideIcons.search, 'Search', 'Find new music', () => context.go('/search')),
              (LucideIcons.arrowDownToLine, 'Downloads', '${lib.tracks.length} tracks', () => context.go('/downloads')),
              (LucideIcons.listMusic, 'Playlists', '${s.playlists.all.length} playlists', () => context.go('/library?tab=playlists')),
              (LucideIcons.heart, 'Favorites', '${lib.favorites.length} songs', () => context.push('/favorites')),
            ],
          )),
          gap(Space.xxl),
          box(SectionHeader('Recently Downloaded', action: recentDl.isEmpty ? null : 'See all', onAction: () => context.go('/downloads'))),
          gap(Space.sm),
          if (recentDl.isEmpty)
            box(AppCard(
              onTap: () => context.go('/search'),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(LucideIcons.download, color: AppColors.accent, size: 20),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('No downloads yet', style: AppText.bodyMedium),
                    Text('Search for music and download available tracks.', style: AppText.caption.muted),
                  ]),
                ),
                const Icon(LucideIcons.chevronRight, color: AppColors.textMuted, size: 18),
              ]),
            ))
          else
            box(SizedBox(
              height: 194,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recentDl.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, i) => _AlbumCard(track: recentDl[i], context: recentDl),
              ),
            )),
          gap(Space.xxl),
          box(const SectionHeader('Recently Played')),
          gap(Space.xs),
          if (played.isEmpty)
            box(Text('Songs you play will show up here.', style: AppText.secondary.muted))
          else
            SliverList.list(children: [
              for (final t in played) TrackRow(track: t, onTap: () => s.player.playTrack(t, context: played)),
            ]),
        ]);
      },
    );
  }
}

class _QuickAccess extends StatelessWidget {
  const _QuickAccess({required this.items});
  final List<(IconData, String, String, VoidCallback)> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 720 ? 4 : 2;
      final w = (c.maxWidth - (cols - 1) * Space.md) / cols;
      return Wrap(spacing: Space.md, runSpacing: Space.md, children: [
        for (final (icon, label, sub, onTap) in items)
          SizedBox(
            width: w,
            child: AppCard(
              onTap: onTap,
              padding: const EdgeInsets.all(Space.md),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: AppColors.accent, size: 20),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, style: AppText.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(sub, style: AppText.caption.muted, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
              ]),
            ),
          ),
      ]);
    });
  }
}

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({required this.track, required this.context});
  final Track track;
  final List<Track> context;

  @override
  Widget build(BuildContext ctx) {
    return Semantics(
      button: true,
      label: 'Play ${track.title} by ${track.artist}',
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => ctx.services.player.playTrack(track, context: context),
        child: SizedBox(
          width: 136,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Artwork(seed: track.artSeed, size: 136, radius: 18),
            const SizedBox(height: Space.sm),
            Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyMedium),
            Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.muted),
          ]),
        ),
      ),
    );
  }
}
