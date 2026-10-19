import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/models/models.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/util/format.dart';
import '../../services/app_services.dart';
import '../actions.dart';
import 'artwork.dart';
import 'controls.dart';
import 'progress.dart';

/// Animated "now playing" equalizer glyph.
class EqualizerIcon extends StatefulWidget {
  const EqualizerIcon({super.key, this.playing = true, this.size = 18});
  final bool playing;
  final double size;
  @override
  State<EqualizerIcon> createState() => _EqualizerIconState();
}

class _EqualizerIconState extends State<EqualizerIcon> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(EqualizerIcon old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final reduce = MediaQuery.of(context).disableAnimations;
    if (widget.playing && !reduce) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Now playing',
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final v = _c.value;
          final hs = [0.55 + 0.45 * v, 1 - 0.5 * v, 0.7 + 0.3 * (1 - v), 0.45 + 0.5 * v];
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final h in hs)
                  Container(
                    width: widget.size / 6,
                    height: widget.size * h,
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(2)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A track that lives on this device.
class TrackRow extends StatelessWidget {
  const TrackRow({super.key, required this.track, this.onTap, this.index, this.trailing, this.showFavorite = false});

  final Track track;
  final VoidCallback? onTap;
  final int? index;
  final Widget? trailing;
  final bool showFavorite;

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    return ListenableBuilder(
      listenable: Listenable.merge([s.player, s.library, s.network]),
      builder: (context, _) {
        final current = s.player.current?.id == track.id;
        // Online songs can't play without the internet: show them dimmed.
        final unreachable = s.player.needsInternet(track) && !s.network.isOnline;
        final meta = [track.artist, if (track.duration > Duration.zero) formatDuration(track.duration)].join(' · ');
        final row = Material(
          color: current ? AppColors.accent.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.md),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            onLongPress: () => showTrackActions(context, track),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.sm, horizontal: Space.xs),
              child: Row(children: [
                if (index != null)
                  SizedBox(
                    width: 28,
                    child: Center(
                      child: current
                          ? EqualizerIcon(playing: s.player.isPlaying)
                          : Text(index!.toString().padLeft(2, '0'), style: AppText.caption.muted),
                    ),
                  ),
                if (index != null) const SizedBox(width: Space.sm),
                if (index == null) Artwork(seed: track.artSeed, size: 52),
                if (index == null) const SizedBox(width: Space.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodyMedium.copyWith(color: current ? AppColors.accent : AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Row(children: [
                      if (s.player.needsInternet(track)) ...[
                        const Icon(LucideIcons.cloud, size: 13, color: AppColors.textMuted, semanticLabel: 'Streams online'),
                        const SizedBox(width: 4),
                      ],
                      Flexible(child: Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.secondary.muted)),
                    ]),
                  ]),
                ),
                if (showFavorite && s.library.isFavorite(track.id))
                  const Padding(
                    padding: EdgeInsets.only(right: Space.xs),
                    child: Icon(LucideIcons.heart, size: 16, color: AppColors.accent, semanticLabel: 'Favorite'),
                  ),
                ?trailing,
                CircleIconButton(
                  icon: LucideIcons.ellipsis,
                  tooltip: 'More options for ${track.title}',
                  filled: false,
                  color: AppColors.textMuted,
                  onPressed: () => showTrackActions(context, track),
                ),
              ]),
            ),
          ),
        );
        return unreachable ? Opacity(opacity: 0.45, child: row) : row;
      },
    );
  }
}

/// A unified search result (possibly from several sources).
class ResultRow extends StatelessWidget {
  const ResultRow({super.key, required this.group});
  final TrackGroup group;

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final g = group;
    return ListenableBuilder(
      listenable: Listenable.merge([s.player, s.downloads, s.library]),
      builder: (context, _) {
        // Whole song when a source allows streaming; otherwise the preview.
        final full = g.canStream;
        final active = full ? s.player.isCurrent(g) : s.player.isPreviewing(g);
        final meta = '${g.artist} · ${formatDuration(g.duration)}';
        return InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: () => context.push('/track', extra: g),
          onLongPress: () => showGroupActions(context, g),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.sm, horizontal: Space.xs),
            child: Row(children: [
              Artwork(seed: g.artSeed, size: 52),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(g.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyMedium),
                  const SizedBox(height: 2),
                  Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.secondary.muted),
                  if (g.sources.length > 1) ...[
                    const SizedBox(height: 2),
                    Text('Available from ${g.sources.length} sources', style: AppText.caption.secondaryColor),
                  ] else ...[
                    const SizedBox(height: 2),
                    Text([g.primary.sourceName, if (!g.canDownload) full ? 'Stream only' : 'Preview only'].join(' · '),
                        style: AppText.caption.muted),
                  ],
                ]),
              ),
              if (full || g.canPreview)
                CircleIconButton(
                  icon: active && s.player.isPlaying ? LucideIcons.pause : LucideIcons.play,
                  tooltip: active && s.player.isPlaying ? 'Pause' : (full ? 'Play ${g.title}' : 'Preview ${g.title}'),
                  size: 38,
                  iconSize: 16,
                  background: active ? AppColors.accent : AppColors.surfaceSecondary,
                  color: active ? AppColors.textOnAccent : AppColors.textPrimary,
                  onPressed: () => full ? s.player.playStream(g) : s.player.playPreview(g),
                ),
              if (g.canDownload) DownloadControl(group: g),
              CircleIconButton(
                icon: LucideIcons.ellipsis,
                tooltip: 'More options for ${g.title}',
                filled: false,
                color: AppColors.textMuted,
                onPressed: () => showGroupActions(context, g),
              ),
            ]),
          ),
        );
      },
    );
  }
}

/// Download button that becomes a progress ring and then a "saved" check.
class DownloadControl extends StatelessWidget {
  const DownloadControl({super.key, required this.group, this.source});
  final TrackGroup group;
  final SourceTrack? source;

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final src = source ?? group.downloadSource;
    if (src == null) return const SizedBox.shrink();
    if (s.downloads.isDownloaded(src)) {
      return CircleIconButton(
        icon: LucideIcons.circleCheck,
        tooltip: 'Saved on this device — play',
        filled: false,
        color: AppColors.success,
        onPressed: () {
          final t = s.library.byId(src.localId);
          if (t != null) s.player.playTrack(t);
        },
      );
    }
    final task = s.downloads.taskFor(src.localId);
    if (task != null && task.status != DownloadStatus.failed) {
      final paused = task.status == DownloadStatus.paused;
      return Tooltip(
        message: paused ? 'Resume download' : 'Pause download (${(task.progress * 100).round()}%)',
        child: InkResponse(
          onTap: () => paused ? s.downloads.resume(task) : s.downloads.pause(task),
          radius: 22,
          child: SizedBox.square(
            dimension: 44,
            child: Center(
              child: ProgressRing(
                value: task.progress,
                child: Icon(paused ? LucideIcons.download : LucideIcons.pause, size: 14, color: AppColors.accent),
              ),
            ),
          ),
        ),
      );
    }
    return CircleIconButton(
      icon: LucideIcons.download,
      tooltip: task?.status == DownloadStatus.failed ? 'Retry download' : 'Download ${group.title}',
      filled: false,
      color: task?.status == DownloadStatus.failed ? AppColors.error : AppColors.textSecondary,
      onPressed: () => startDownload(context, group, from: src),
    );
  }
}
