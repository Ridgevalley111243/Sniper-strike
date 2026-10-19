import 'dart:async';

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
import '../widgets/backgrounds.dart';
import '../widgets/progress.dart';
import 'player_chrome.dart';

class _Dest {
  const _Dest(this.label, this.icon);
  final String label;
  final IconData icon;
}

const _dests = [
  _Dest('Home', LucideIcons.house),
  _Dest('Search', LucideIcons.search),
  _Dest('Library', LucideIcons.library),
  _Dest('Downloads', LucideIcons.arrowDownToLine),
];

/// Responsive application shell.
/// * < 1024px: content + mini player + bottom navigation.
/// * ≥ 1024px: sidebar + content + full-width player bar.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  StreamSubscription<Track>? _done;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _done ??= context.services.downloads.completions.listen((t) {
      if (mounted) showDownloadComplete(context, t);
    });
  }

  @override
  void dispose() {
    _done?.cancel();
    super.dispose();
  }

  void _go(int i) => widget.shell.goBranch(i, initialLocation: i == widget.shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.desktop;
    final body = AmbientBackground(child: widget.shell);
    if (wide) {
      return Scaffold(
        body: Column(children: [
          Expanded(
            child: Row(children: [
              _Sidebar(index: widget.shell.currentIndex, onSelect: _go),
              Expanded(child: body),
            ]),
          ),
          const PlayerBar(),
        ]),
      );
    }
    return Scaffold(
      extendBody: true,
      body: body,
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(padding: EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm), child: MiniPlayer()),
        _BottomNav(index: widget.shell.currentIndex, onSelect: _go),
      ]),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onSelect});
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgPrimary.withValues(alpha: 0.96),
        border: const Border(top: BorderSide(color: AppColors.borderSoft)),
      ),
      padding: EdgeInsets.only(top: 6, bottom: bottom > 0 ? bottom : 8),
      child: Row(children: [
        for (var i = 0; i < _dests.length; i++)
          Expanded(
            child: Semantics(
              selected: i == index,
              button: true,
              label: _dests[i].label,
              child: InkResponse(
                onTap: () => onSelect(i),
                radius: 36,
                child: SizedBox(
                  height: 56,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(_dests[i].icon, size: 24, color: i == index ? AppColors.accent : AppColors.textMuted),
                    const SizedBox(height: 4),
                    Text(_dests[i].label,
                        style: AppText.nav.copyWith(color: i == index ? AppColors.textPrimary : AppColors.textMuted)),
                    const SizedBox(height: 3),
                    AnimatedOpacity(
                      duration: Motion.fast,
                      opacity: i == index ? 1 : 0,
                      child: Container(
                          width: 4, height: 4, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
                    ),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.index, required this.onSelect});
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: AppColors.bgPrimary.withValues(alpha: 0.85),
        border: const Border(right: BorderSide(color: AppColors.borderSoft)),
      ),
      padding: const EdgeInsets.fromLTRB(Space.xl, 28, Space.xl, Space.xxl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: Space.sm, bottom: 22),
          child: Row(children: [
            const _LogoMark(size: 34),
            const SizedBox(width: 10),
            Text('TRUHive', style: AppText.h2),
          ]),
        ),
        for (var i = 0; i < _dests.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: i == index ? AppColors.accent.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onSelect(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 11),
                  child: Row(children: [
                    Icon(_dests[i].icon, size: 20, color: i == index ? AppColors.accent : AppColors.textMuted),
                    const SizedBox(width: Space.md),
                    Text(_dests[i].label,
                        style: AppText.bodyMedium.copyWith(color: i == index ? AppColors.textPrimary : AppColors.textMuted)),
                  ]),
                ),
              ),
            ),
          ),
        const Padding(padding: EdgeInsets.symmetric(vertical: Space.md), child: Divider()),
        Padding(
          padding: const EdgeInsets.only(left: Space.md),
          child: Row(children: [
            Expanded(child: Text('PLAYLISTS', style: AppText.metadata.muted)),
            IconButton(
              tooltip: 'New playlist',
              icon: const Icon(LucideIcons.plus, size: 18, color: AppColors.textMuted),
              onPressed: () async {
                final name = await promptText(context, title: 'New playlist', hint: 'Playlist name', confirmLabel: 'Create');
                if (name != null) await s.playlists.create(name);
              },
            ),
          ]),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: Listenable.merge([s.playlists, s.library]),
            builder: (context, _) => ListView(children: [
              _SideLink(
                leading: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(LucideIcons.heart, size: 16, color: AppColors.navy),
                ),
                label: 'Favorites',
                onTap: () => context.push('/favorites'),
              ),
              for (final p in s.playlists.all)
                _SideLink(
                  leading: Artwork(seed: p.trackIds.isEmpty ? p.id : (s.library.byId(p.trackIds.first)?.artSeed ?? p.id), size: 30, radius: 8),
                  label: p.name,
                  onTap: () => context.push('/playlist/${p.id}'),
                ),
            ]),
          ),
        ),
        const _StorageCard(),
        const SizedBox(height: Space.sm),
        _SideLink(
          leading: const Icon(LucideIcons.settings, size: 20, color: AppColors.textMuted),
          label: 'Settings',
          onTap: () => context.push('/settings'),
        ),
      ]),
    );
  }
}

class _SideLink extends StatelessWidget {
  const _SideLink({required this.leading, required this.label, required this.onTap});
  final Widget leading;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 7),
        child: Row(children: [
          leading,
          const SizedBox(width: Space.md),
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.secondary.secondaryColor)),
        ]),
      ),
    );
  }
}

class _StorageCard extends StatelessWidget {
  const _StorageCard();

  @override
  Widget build(BuildContext context) {
    final lib = context.services.library;
    return ListenableBuilder(
      listenable: lib,
      builder: (context, _) => Container(
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(
          color: AppColors.surfacePrimary.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(LucideIcons.hardDrive, size: 16, color: AppColors.accent),
            const SizedBox(width: Space.sm),
            Expanded(child: Text('On this device', style: AppText.caption)),
            Text(formatBytes(lib.totalBytes), style: AppText.caption.muted),
          ]),
          const SizedBox(height: Space.sm),
          ThinProgress(value: (lib.totalBytes / (2 * 1024 * 1024 * 1024)).clamp(0.02, 1)),
        ]),
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) => LogoMark(size: size, glow: false);
}

/// The TRUHive headphone + waveform mark.
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 96, this.glow = true});
  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'TRUHive',
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _LogoPainter(glow)),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.glow);
  final bool glow;

  @override
  void paint(Canvas c, Size s) {
    final k = s.width / 96;
    c.scale(k);
    if (glow) {
      c.drawCircle(const Offset(48, 56), 46,
          Paint()..color = AppColors.lightBlue.withValues(alpha: 0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26));
    }
    final stroke = Paint()
      ..color = AppColors.offWhite
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.5
      ..strokeCap = StrokeCap.round;
    final band = Path()
      ..moveTo(15, 60)
      ..lineTo(15, 50)
      ..arcToPoint(const Offset(81, 50), radius: const Radius.circular(33))
      ..lineTo(81, 60);
    c.drawPath(band, stroke);
    final fill = Paint()..color = AppColors.offWhite;
    c.drawRRect(RRect.fromLTRBR(8, 54, 25, 82, const Radius.circular(8.5)), fill);
    c.drawRRect(RRect.fromLTRBR(71, 54, 88, 82, const Radius.circular(8.5)), fill);
    for (final (x, y, h) in [(33.0, 56.0, 16.0), (40.0, 48.0, 30.0), (47.0, 38.0, 54.0), (54.0, 48.0, 30.0), (61.0, 56.0, 16.0)]) {
      c.drawRRect(RRect.fromLTRBR(x, y, x + 4, y + h, const Radius.circular(2)), fill);
    }
  }

  @override
  bool shouldRepaint(_LogoPainter o) => o.glow != glow;
}
