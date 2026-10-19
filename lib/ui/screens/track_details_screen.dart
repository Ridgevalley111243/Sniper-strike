import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/models/models.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/util/format.dart';
import '../../services/app_services.dart';
import '../actions.dart';
import '../widgets/artwork.dart';
import '../widgets/controls.dart';
import '../widgets/page.dart';
import '../widgets/rows.dart';

/// Song details for a unified search result, including every source that
/// carries it and what each source allows.
class TrackDetailsScreen extends StatelessWidget {
  const TrackDetailsScreen({super.key, required this.group});
  final TrackGroup group;

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final g = group;
    return DetailScaffold(
      child: ListenableBuilder(
        listenable: Listenable.merge([s.library, s.downloads, s.player]),
        builder: (context, _) {
          final local = g.sources.map((x) => s.library.byId(x.localId)).whereType<Track>().firstOrNull;
          final lyricsSrc = g.sources.where(s.lyrics.available).firstOrNull;
          final wide = MediaQuery.sizeOf(context).width >= Breakpoints.tablet;
          final art = Artwork(seed: g.artSeed, size: wide ? 180 : 132, radius: 22, shadow: Effects.elevation);
          final meta = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(['SINGLE', if (g.year != null) '${g.year}'].join(' · '), style: AppText.metadata.muted),
            const SizedBox(height: 6),
            Text(g.title, style: AppText.h1, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(g.artist, style: AppText.bodyMedium.secondaryColor),
            if (g.album.isNotEmpty) Text(g.album, style: AppText.caption.muted),
            const SizedBox(height: Space.sm),
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (g.genre != null) AppTag(g.genre!),
              AppTag(formatDuration(g.duration)),
              if (local != null) const AppTag('On this device', icon: LucideIcons.circleCheck, color: AppColors.success),
            ]),
          ]);
          return PageBody(back: true, actions: [
            CircleIconButton(icon: LucideIcons.ellipsis, tooltip: 'More options', onPressed: () => showGroupActions(context, g)),
          ], slivers: [
            box(Row(crossAxisAlignment: CrossAxisAlignment.center, children: [art, const SizedBox(width: Space.lg), Expanded(child: meta)])),
            gap(Space.xl),
            box(Row(children: [
              Expanded(
                child: local != null
                    ? AppButton(label: 'Play', icon: LucideIcons.play, compact: true, expand: true, onPressed: () => s.player.playTrack(local))
                    : AppButton(
                        label: s.player.isPreviewing(g) && s.player.isPlaying ? 'Pause preview' : 'Preview',
                        icon: s.player.isPreviewing(g) && s.player.isPlaying ? LucideIcons.pause : LucideIcons.play,
                        compact: true,
                        expand: true,
                        loading: s.player.isPreviewing(g) && s.player.previewLoading,
                        onPressed: g.canPreview ? () => s.player.playPreview(g) : null,
                      ),
              ),
              if (g.canDownload && local == null) ...[
                const SizedBox(width: Space.sm),
                Expanded(child: _DownloadButton(group: g)),
              ],
            ])),
            gap(Space.lg),
            box(Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              if (local != null)
                _Quick(
                  icon: LucideIcons.heart,
                  label: s.library.isFavorite(local.id) ? 'Favorited' : 'Favorite',
                  active: s.library.isFavorite(local.id),
                  onTap: () => s.library.toggleFavorite(local.id),
                ),
              if (local != null) _Quick(icon: LucideIcons.listPlus, label: 'Playlist', onTap: () => showAddToPlaylist(context, local.id)),
              if (lyricsSrc != null) _Quick(icon: LucideIcons.textQuote, label: 'Lyrics', onTap: () => context.push('/lyrics', extra: lyricsSrc)),
              if (local != null) _Quick(icon: LucideIcons.share2, label: 'Share', onTap: () => shareTrack(context, local)),
            ])),
            if (local == null) ...[
              gap(Space.sm),
              box(Text('Download this song to add it to favorites and playlists, or to share the file.',
                  textAlign: TextAlign.center, style: AppText.caption.muted)),
            ],
            gap(Space.xl),
            box(SectionHeader('Available Sources', action: '${g.sources.length} found')),
            gap(Space.sm),
            box(AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(children: [
                for (var i = 0; i < g.sources.length; i++) ...[
                  if (i > 0) const Divider(),
                  _SourceLine(group: g, source: g.sources[i]),
                ],
              ]),
            )),
            gap(Space.md),
            box(Text('Downloads are offered only where the source licenses them.', style: AppText.caption.muted)),
          ]);
        },
      ),
    );
  }
}

class _DownloadButton extends StatelessWidget {
  const _DownloadButton({required this.group});
  final TrackGroup group;

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final task = s.downloads.taskFor(group.downloadSource!.localId);
    if (task != null && task.status != DownloadStatus.failed) {
      final paused = task.status == DownloadStatus.paused;
      return AppButton.secondary(
        label: paused ? 'Paused · ${(task.progress * 100).round()}%' : 'Downloading ${(task.progress * 100).round()}%',
        icon: paused ? LucideIcons.play : LucideIcons.pause,
        expand: true,
        onPressed: () => paused ? s.downloads.resume(task) : s.downloads.pause(task),
      );
    }
    return AppButton.secondary(
      label: task?.status == DownloadStatus.failed ? 'Retry download' : 'Download',
      icon: LucideIcons.download,
      expand: true,
      onPressed: () => startDownload(context, group),
    );
  }
}

class _Quick extends StatelessWidget {
  const _Quick({required this.icon, required this.label, required this.onTap, this.active = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) => Column(children: [
        CircleIconButton(icon: icon, tooltip: label, color: active ? AppColors.accent : AppColors.textSecondary, onPressed: onTap),
        const SizedBox(height: 6),
        Text(label, style: AppText.caption.muted),
      ]);
}

class _SourceLine extends StatelessWidget {
  const _SourceLine({required this.group, required this.source});
  final TrackGroup group;
  final SourceTrack source;

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final src = s.sources.byId(source.sourceId);
    final meta = source.downloadAvailable
        ? [source.format ?? 'Audio', if (source.sizeBytes != null) formatBytes(source.sizeBytes!)].join(' · ')
        : source.previewAvailable
            ? 'Preview only · 30 sec'
            : 'Search only';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.md),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(12)),
          child: Text(src?.monogram ?? '?', style: AppText.caption.secondaryColor),
        ),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(source.sourceName, style: AppText.bodyMedium),
            Text(meta, style: AppText.caption.muted),
            const SizedBox(height: 6),
            Wrap(spacing: 4, runSpacing: 4, children: [
              if (source.previewAvailable) const AppTag('Preview'),
              if (source.downloadAvailable) const AppTag('Download'),
              if (source.lyricsAvailable) const AppTag('Lyrics'),
              if (src?.isDemo ?? false) const AppTag('Demo', muted: true),
            ]),
          ]),
        ),
        if (source.downloadAvailable)
          DownloadControl(group: group, source: source)
        else if (source.previewAvailable)
          CircleIconButton(
            icon: s.player.previewSource?.localId == source.localId && s.player.isPlaying ? LucideIcons.pause : LucideIcons.play,
            tooltip: 'Preview on ${source.sourceName}',
            onPressed: () => s.player.playPreview(group, from: source),
          ),
      ]),
    );
  }
}
