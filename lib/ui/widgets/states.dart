import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'controls.dart';

/// Haloed icon + message + actions, used for every empty and error state.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.primary,
    this.onPrimary,
    this.secondary,
    this.onSecondary,
    this.tone = AppColors.accent,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? primary;
  final VoidCallback? onPrimary;
  final String? secondary;
  final VoidCallback? onSecondary;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.xxl, vertical: Space.x4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tone.withValues(alpha: 0.08),
                border: Border.all(color: AppColors.borderSoft),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(shape: BoxShape.circle, color: tone.withValues(alpha: 0.14), boxShadow: [
                  BoxShadow(color: tone.withValues(alpha: 0.25), blurRadius: 30),
                ]),
                child: Icon(icon, size: 30, color: tone),
              ),
            ),
            const SizedBox(height: Space.lg),
            Text(title, textAlign: TextAlign.center, style: AppText.h2),
            const SizedBox(height: Space.sm),
            Text(message, textAlign: TextAlign.center, style: AppText.secondary.muted),
            if (primary != null) ...[
              const SizedBox(height: Space.xl),
              AppButton(label: primary!, onPressed: onPrimary, expand: true),
            ],
            if (secondary != null) ...[
              const SizedBox(height: Space.sm),
              AppButton.ghost(label: secondary!, onPressed: onSecondary),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Pulsing placeholder used instead of spinners while content loads.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, required this.width, required this.height, this.radius = 8, this.circle = false});
  final double width;
  final double height;
  final double radius;
  final bool circle;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    if (reduce) _c.stop();
    return FadeTransition(
      opacity: reduce ? const AlwaysStoppedAnimation(0.8) : Tween(begin: 0.45, end: 0.9).animate(_c),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: widget.circle ? null : BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

class SongRowSkeleton extends StatelessWidget {
  const SongRowSkeleton({super.key, this.index = 0});
  final int index;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.sm),
        child: Row(children: [
          const Skeleton(width: 52, height: 52, radius: 12),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Skeleton(width: 170 - index * 18.0, height: 12, radius: 6),
              const SizedBox(height: Space.sm),
              Skeleton(width: 100 + index * 12.0, height: 10, radius: 5),
            ]),
          ),
          const Skeleton(width: 36, height: 36, circle: true),
        ]),
      ),
    );
  }
}

/// Inline, human-readable error with recovery actions.
class InlineError extends StatelessWidget {
  const InlineError({super.key, required this.title, required this.message, this.onRetry, this.onManage});
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: AppColors.error.withValues(alpha: 0.6),
      padding: const EdgeInsets.all(Space.lg),
      child: Column(children: [
        const Icon(LucideIcons.globe, color: AppColors.error, size: 26),
        const SizedBox(height: Space.sm),
        Text(title, textAlign: TextAlign.center, style: AppText.h3),
        const SizedBox(height: Space.xs),
        Text(message, textAlign: TextAlign.center, style: AppText.secondary.muted),
        const SizedBox(height: Space.md),
        Row(children: [
          if (onRetry != null) Expanded(child: AppButton(label: 'Retry', compact: true, onPressed: onRetry)),
          if (onRetry != null && onManage != null) const SizedBox(width: Space.sm),
          if (onManage != null) Expanded(child: AppButton.secondary(label: 'Manage Sources', onPressed: onManage)),
        ]),
      ]),
    );
  }
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, this.message = 'Search needs an internet connection.'});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: AppCard(
        borderColor: AppColors.warning.withValues(alpha: 0.7),
        child: Row(children: [
          const Icon(LucideIcons.wifiOff, color: AppColors.warning, size: 22),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("You're offline", style: AppText.bodyMedium),
              Text(message, style: AppText.caption.muted),
            ]),
          ),
        ]),
      ),
    );
  }
}
