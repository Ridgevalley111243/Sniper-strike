import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/util/format.dart';
import '../../services/app_services.dart';
import '../../services/player_controller.dart';
import '../widgets/artwork.dart';
import '../widgets/controls.dart';

/// Persistent mini player shown above the bottom navigation.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.services.player;
    final lib = context.services.library;
    return ListenableBuilder(
      listenable: Listenable.merge([p, lib]),
      builder: (context, _) {
        if (!p.hasMedia) return const SizedBox.shrink();
        final current = p.current;
        return Semantics(
          container: true,
          label: 'Now playing: ${p.title} by ${p.artist}. Opens the full player.',
          child: Material(
            color: AppColors.surfaceSecondary.withValues(alpha: 0.97),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.lg),
              side: const BorderSide(color: AppColors.borderSoft),
            ),
            clipBehavior: Clip.antiAlias,
            elevation: 0,
            child: InkWell(
              onTap: () => context.push('/now-playing'),
              child: Stack(children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(children: [
                    Artwork(seed: p.artSeed, size: 48, radius: 12),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyMedium),
                        Text(p.isPreview ? '${p.artist} · Preview' : p.artist,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.secondary.muted),
                      ]),
                    ),
                    if (current != null)
                      CircleIconButton(
                        icon: LucideIcons.heart,
                        tooltip: lib.isFavorite(current.id) ? 'Remove from favorites' : 'Add to favorites',
                        filled: false,
                        color: lib.isFavorite(current.id) ? AppColors.accent : AppColors.textSecondary,
                        onPressed: () => lib.toggleFavorite(current.id),
                      ),
                    const SizedBox(width: Space.xs),
                    PlayPauseButton(size: 44, radius: Radii.md),
                  ]),
                ),
                Positioned(left: 0, right: 0, bottom: 0, child: _MiniProgress(p)),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _MiniProgress extends StatelessWidget {
  const _MiniProgress(this.p);
  final PlayerController p;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: p.position,
      builder: (_, snap) {
        final d = p.duration.inMilliseconds;
        final v = d <= 0 ? 0.0 : ((snap.data ?? Duration.zero).inMilliseconds / d).clamp(0.0, 1.0);
        return Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: v,
            child: Container(height: 2.5, color: AppColors.accent),
          ),
        );
      },
    );
  }
}

/// The prominent play/pause control (light-blue on navy).
class PlayPauseButton extends StatelessWidget {
  const PlayPauseButton({super.key, this.size = 78, this.radius, this.glow = false});
  final double size;
  final double? radius;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final p = context.services.player;
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) {
        final playing = p.isPlaying;
        final r = radius ?? size / 2;
        return Tooltip(
          message: playing ? 'Pause' : 'Play',
          child: Semantics(
            button: true,
            label: playing ? 'Pause' : 'Play',
            child: AnimatedContainer(
              duration: Motion.normal,
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(r),
                boxShadow: glow ? Effects.glow(playing ? 0.5 : 0.3, 36) : null,
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(r),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: p.togglePlay,
                  child: Center(
                    child: p.isBuffering
                        ? SizedBox.square(
                            dimension: size * 0.34,
                            child: const CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.navy))
                        : AnimatedSwitcher(
                            duration: Motion.fast,
                            child: Icon(playing ? LucideIcons.pause : LucideIcons.play,
                                key: ValueKey(playing), size: size * 0.38, color: AppColors.navy),
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Desktop/tablet-wide player bar.
class PlayerBar extends StatelessWidget {
  const PlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.services.player;
    final lib = context.services.library;
    return ListenableBuilder(
      listenable: Listenable.merge([p, lib]),
      builder: (context, _) {
        if (!p.hasMedia) return const SizedBox.shrink();
        final current = p.current;
        return Container(
          height: 84,
          padding: const EdgeInsets.symmetric(horizontal: Space.xl),
          decoration: BoxDecoration(
            color: AppColors.surfacePrimary.withValues(alpha: 0.97),
            border: const Border(top: BorderSide(color: AppColors.borderSoft)),
          ),
          child: Row(children: [
            SizedBox(
              width: 320,
              child: InkWell(
                onTap: () => context.push('/now-playing'),
                borderRadius: BorderRadius.circular(Radii.md),
                child: Row(children: [
                  Artwork(seed: p.artSeed, size: 52, radius: 12),
                  const SizedBox(width: Space.md),
                  Flexible(
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyMedium),
                      Text(p.isPreview ? '${p.artist} · Preview' : p.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.muted),
                    ]),
                  ),
                  if (current != null)
                    CircleIconButton(
                      icon: LucideIcons.heart,
                      tooltip: 'Favorite',
                      filled: false,
                      size: 36,
                      iconSize: 18,
                      color: lib.isFavorite(current.id) ? AppColors.accent : AppColors.textMuted,
                      onPressed: () => lib.toggleFavorite(current.id),
                    ),
                ]),
              ),
            ),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                TransportControls(compact: true),
                const SizedBox(height: 4),
                ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: const SeekBar(dense: true)),
              ]),
            ),
            SizedBox(
              width: 320,
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (current != null && current.lyricsAvailable)
                  CircleIconButton(
                    icon: LucideIcons.textQuote,
                    tooltip: 'Lyrics',
                    filled: false,
                    color: AppColors.textMuted,
                    onPressed: () => context.push('/now-playing'),
                  ),
                CircleIconButton(
                  icon: LucideIcons.listMusic,
                  tooltip: 'Up next',
                  filled: false,
                  color: AppColors.textMuted,
                  onPressed: () => context.push('/queue'),
                ),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

class TransportControls extends StatelessWidget {
  const TransportControls({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.services.player;
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) {
        final repeatIcon = p.repeat == PlayerRepeat.one ? LucideIcons.repeat1 : LucideIcons.repeat;
        final repeatLabel = switch (p.repeat) { PlayerRepeat.off => 'Repeat off', PlayerRepeat.all => 'Repeat all', PlayerRepeat.one => 'Repeat one' };
        final small = compact ? 36.0 : 48.0;
        return Row(
          mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
          children: [
            CircleIconButton(
              icon: LucideIcons.shuffle,
              tooltip: p.shuffle ? 'Shuffle on' : 'Shuffle off',
              filled: false,
              size: small,
              iconSize: compact ? 18 : 22,
              color: p.shuffle ? AppColors.accent : AppColors.textMuted,
              onPressed: p.isPreview ? null : p.toggleShuffle,
            ),
            if (compact) const SizedBox(width: Space.lg),
            CircleIconButton(
              icon: LucideIcons.skipBack,
              tooltip: 'Previous',
              filled: false,
              size: small,
              iconSize: compact ? 20 : 28,
              onPressed: p.isPreview ? null : p.previous,
            ),
            if (compact) const SizedBox(width: Space.lg),
            PlayPauseButton(size: compact ? 40 : 78, glow: !compact),
            if (compact) const SizedBox(width: Space.lg),
            CircleIconButton(
              icon: LucideIcons.skipForward,
              tooltip: 'Next',
              filled: false,
              size: small,
              iconSize: compact ? 20 : 28,
              onPressed: p.isPreview ? null : p.next,
            ),
            if (compact) const SizedBox(width: Space.lg),
            CircleIconButton(
              icon: repeatIcon,
              tooltip: repeatLabel,
              filled: false,
              size: small,
              iconSize: compact ? 18 : 22,
              color: p.repeat == PlayerRepeat.off ? AppColors.textMuted : AppColors.accent,
              onPressed: p.isPreview ? null : p.cycleRepeat,
            ),
          ],
        );
      },
    );
  }
}

/// Slider + elapsed / remaining time.
class SeekBar extends StatelessWidget {
  const SeekBar({super.key, this.dense = false});
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final p = context.services.player;
    return StreamBuilder<Duration>(
      stream: p.position,
      builder: (context, snap) {
        final pos = snap.data ?? Duration.zero;
        final dur = p.duration;
        final max = dur.inMilliseconds.toDouble().clamp(1.0, double.infinity);
        final value = pos.inMilliseconds.toDouble().clamp(0.0, max);
        final slider = SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: dense ? 3 : 4,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: dense ? 5 : 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: value,
            max: max,
            semanticFormatterCallback: (_) => '${formatDuration(pos)} of ${formatDuration(dur)}',
            onChanged: (v) => p.seek(Duration(milliseconds: v.round())),
          ),
        );
        final remaining = dur - pos;
        if (dense) {
          return Row(children: [
            Text(formatDuration(pos), style: AppText.caption.muted),
            Expanded(child: slider),
            Text(formatDuration(dur), style: AppText.caption.muted),
          ]);
        }
        return Column(children: [
          slider,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.sm),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(formatDuration(pos), style: AppText.caption.secondaryColor),
              Text(remaining > Duration.zero ? '-${formatDuration(remaining)}' : '0:00', style: AppText.caption.muted),
            ]),
          ),
        ]);
      },
    );
  }
}
