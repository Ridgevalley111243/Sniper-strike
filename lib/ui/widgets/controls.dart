import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

enum ButtonKind { primary, secondary, ghost }

/// The pale-blue pill from the Welcome screen, plus its supporting variants.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.kind = ButtonKind.primary,
    this.compact = false,
    this.expand = false,
    this.loading = false,
  });

  const AppButton.secondary({super.key, required this.label, required this.onPressed, this.icon, this.compact = true, this.expand = false, this.loading = false})
      : kind = ButtonKind.secondary;

  const AppButton.ghost({super.key, required this.label, required this.onPressed, this.icon, this.compact = true, this.expand = false, this.loading = false})
      : kind = ButtonKind.ghost;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonKind kind;
  final bool compact;
  final bool expand;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final (bg, fg, border) = switch (kind) {
      ButtonKind.primary => (AppColors.accent, AppColors.textOnAccent, Colors.transparent),
      ButtonKind.secondary => (AppColors.surfaceSecondary, AppColors.textPrimary, AppColors.borderSoft),
      ButtonKind.ghost => (Colors.transparent, AppColors.textSecondary, Colors.transparent),
    };
    final height = compact ? 46.0 : 56.0;
    final radius = compact ? Radii.md : Radii.pill;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
        else if (icon != null)
          Icon(icon, size: 18, color: fg),
        if (loading || icon != null) const SizedBox(width: Space.sm),
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis, style: (compact ? AppText.bodyMedium : AppText.button).copyWith(color: fg)),
        ),
      ],
    );
    return Semantics(
      button: true,
      enabled: enabled,
      child: AnimatedOpacity(
        duration: Motion.fast,
        opacity: enabled ? 1 : 0.45,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: kind == ButtonKind.primary && enabled
                ? [BoxShadow(color: AppColors.lightBlue.withValues(alpha: 0.28), offset: const Offset(0, 6), blurRadius: 24, spreadRadius: -6)]
                : null,
          ),
          child: Material(
            color: bg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius), side: BorderSide(color: border)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? onPressed : null,
              child: Padding(padding: EdgeInsets.symmetric(horizontal: compact ? Space.xl : 28), child: content),
            ),
          ),
        ),
      ),
    );
  }
}

/// 44px circular icon button (minimum touch target) with an accessible label.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = true,
    this.color = AppColors.textPrimary,
    this.background,
    this.size = 44,
    this.iconSize = 20,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool filled;
  final Color color;
  final Color? background;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: background ?? (filled ? AppColors.surfaceSecondary.withValues(alpha: 0.7) : Colors.transparent),
          shape: CircleBorder(side: filled && background == null ? const BorderSide(color: AppColors.borderSoft) : BorderSide.none),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox.square(dimension: size, child: Icon(icon, size: iconSize, color: onPressed == null ? AppColors.textMuted : color)),
          ),
        ),
      ),
    );
  }
}

class AppChip extends StatelessWidget {
  const AppChip({super.key, required this.label, required this.selected, required this.onTap, this.icon});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.accent : AppColors.surfacePrimary,
        shape: StadiumBorder(side: BorderSide(color: selected ? Colors.transparent : AppColors.borderSoft)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 9),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: selected ? AppColors.textOnAccent : AppColors.textSecondary),
                const SizedBox(width: 6),
              ],
              Text(label, style: AppText.caption.copyWith(color: selected ? AppColors.textOnAccent : AppColors.textSecondary)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Small capability / metadata tag ("Preview", "Download", "Afrobeats").
class AppTag extends StatelessWidget {
  const AppTag(this.label, {super.key, this.icon, this.color = AppColors.textSecondary, this.muted = false});
  final String label;
  final IconData? icon;
  final Color color;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: muted ? AppColors.surfaceSecondary.withValues(alpha: 0.6) : AppColors.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
        Text(label, style: AppText.caption.copyWith(color: muted ? AppColors.textMuted : color)),
      ]),
    );
  }
}

/// Bordered translucent surface used for grouped content.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.borderColor, this.opacity = 0.82, this.onTap, this.radius = Radii.card});
  final Widget child;
  final EdgeInsets padding;
  final Color? borderColor;
  final double opacity;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfacePrimary.withValues(alpha: opacity),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: borderColor ?? AppColors.borderSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Semantics(header: true, child: Text(title, style: AppText.h3))),
      if (action != null)
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(minimumSize: const Size(44, 36), foregroundColor: AppColors.textSecondary),
          child: Text(action!, style: AppText.caption.secondaryColor),
        ),
    ]);
  }
}

class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.onFilter,
    this.filterActive = false,
    this.autofocus = false,
    this.enabled = true,
    this.readOnly = false,
    this.hint = 'Search songs, artists, albums',
    this.focusNode,
  });

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final VoidCallback? onFilter;
  final bool filterActive;
  final bool autofocus;
  final bool enabled;
  final bool readOnly;
  final String hint;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.only(left: Space.lg, right: Space.sm),
      decoration: BoxDecoration(
        color: AppColors.surfacePrimary.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(children: [
        const Icon(LucideIcons.search, size: 20, color: AppColors.textMuted),
        const SizedBox(width: Space.md),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            onTap: onTap,
            readOnly: readOnly,
            enabled: enabled,
            autofocus: autofocus,
            textInputAction: TextInputAction.search,
            style: AppText.body.primary,
            decoration: InputDecoration(
              isCollapsed: true,
              hintText: hint,
              hintStyle: AppText.body.muted,
              border: InputBorder.none,
            ),
          ),
        ),
        if (controller != null)
          ValueListenableBuilder(
            valueListenable: controller!,
            builder: (_, v, _) => v.text.isEmpty
                ? const SizedBox.shrink()
                : CircleIconButton(
                    icon: LucideIcons.x,
                    tooltip: 'Clear search',
                    filled: false,
                    size: 36,
                    iconSize: 18,
                    color: AppColors.textMuted,
                    onPressed: () {
                      controller!.clear();
                      onChanged?.call('');
                    },
                  ),
          ),
        if (onFilter != null)
          CircleIconButton(
            icon: LucideIcons.slidersHorizontal,
            tooltip: 'Filters',
            size: 36,
            iconSize: 18,
            color: filterActive ? AppColors.textOnAccent : AppColors.textSecondary,
            background: filterActive ? AppColors.accent : AppColors.surfaceSecondary,
            onPressed: onFilter,
          ),
      ]),
    );
  }
}
