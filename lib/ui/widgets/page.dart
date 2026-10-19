import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../shell/player_chrome.dart';
import 'backgrounds.dart';
import 'controls.dart';

/// Scrollable page body with a title row. Keeps content readable on wide
/// screens and clears the mini player / navigation bar at the bottom.
class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    this.title,
    this.actions = const [],
    this.back = false,
    required this.slivers,
    this.maxWidth = Breakpoints.contentMax,
    this.titleStyle,
  });

  final String? title;
  final List<Widget> actions;
  final bool back;
  final List<Widget> slivers;
  final double maxWidth;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final width = mq.size.width;
    final wide = width >= Breakpoints.desktop;
    final side = wide ? Space.x4 : (width >= Breakpoints.tablet ? Space.x3 : Space.lg);
    // Tab pages use the full desktop canvas; detail pages stay readable.
    final cap = wide ? (back ? 880.0 : double.infinity) : maxWidth;
    final hPad = width > cap + side * 2 ? (width - cap) / 2 : side;
    return CustomScrollView(slivers: [
      SliverPadding(
        padding: EdgeInsets.only(top: mq.padding.top + (wide ? Space.x3 : Space.sm)),
        sliver: const SliverToBoxAdapter(),
      ),
      if (title != null || back || actions.isNotEmpty)
        SliverPadding(
          padding: EdgeInsets.fromLTRB(back ? hPad - Space.sm : hPad, 0, hPad, Space.md),
          sliver: SliverToBoxAdapter(
            child: Row(children: [
              if (back)
                CircleIconButton(
                  icon: LucideIcons.chevronLeft,
                  tooltip: 'Back',
                  filled: false,
                  onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                ),
              if (title != null)
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title!, style: titleStyle ?? (back ? AppText.h2 : AppText.h1), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                )
              else
                const Spacer(),
              ...actions.expand((a) => [const SizedBox(width: Space.sm), a]),
            ]),
          ),
        ),
      for (final s in slivers) SliverPadding(padding: EdgeInsets.symmetric(horizontal: hPad), sliver: s),
      SliverToBoxAdapter(child: SizedBox(height: mq.padding.bottom + Space.x3)),
    ]);
  }
}

/// Full-screen route (outside the tab shell) that still shows the player.
class DetailScaffold extends StatelessWidget {
  const DetailScaffold({super.key, required this.child, this.showPlayer = true});
  final Widget child;
  final bool showPlayer;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.desktop;
    return Scaffold(
      extendBody: true,
      body: AmbientBackground(child: child),
      bottomNavigationBar: !showPlayer
          ? null
          : wide
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

SliverToBoxAdapter gap(double h) => SliverToBoxAdapter(child: SizedBox(height: h));
SliverToBoxAdapter box(Widget w) => SliverToBoxAdapter(child: w);
