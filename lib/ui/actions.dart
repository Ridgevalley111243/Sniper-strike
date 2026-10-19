import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/models/models.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import '../core/util/format.dart';
import '../services/app_services.dart';
import '../services/lyrics_service.dart';
import '../services/share_service.dart';
import 'widgets/artwork.dart';
import 'widgets/controls.dart';

// Shared user actions (sheets, dialogs, toasts) so every screen behaves the same.

void showToast(BuildContext context, String message, {String? action, VoidCallback? onAction}) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  final w = MediaQuery.sizeOf(context).width;
  // On desktop, float above the player bar on the right instead of covering it.
  final margin = w >= Breakpoints.desktop ? EdgeInsets.fromLTRB(w - 480, 0, Space.xxl, 100) : null;
  m
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      margin: margin,
      content: Text(message),
      duration: const Duration(seconds: 3),
      action: action == null ? null : SnackBarAction(label: action, textColor: AppColors.accent, onPressed: onAction ?? () {}),
    ));
}

Future<bool> confirm(BuildContext context, {required String title, required String message, String confirmLabel = 'Delete'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(confirmLabel)),
      ],
    ),
  );
  return ok ?? false;
}

Future<String?> promptText(BuildContext context, {required String title, String initial = '', String hint = '', String confirmLabel = 'Save'}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        style: AppText.body.primary,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: AppColors.surfacePrimary,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md), borderSide: BorderSide.none),
        ),
        onSubmitted: (v) => Navigator.pop(d, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(d, c.text), child: Text(confirmLabel)),
      ],
    ),
  );
}

class _SheetAction {
  const _SheetAction(this.icon, this.label, this.onTap, {this.destructive = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
}

Future<void> _actionSheet(BuildContext context, {required Widget header, required List<_SheetAction> actions}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheet) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(sheet).size.height * 0.8),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.lg),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            header,
            const SizedBox(height: Space.md),
            const Divider(),
            for (final a in actions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(a.icon, color: a.destructive ? AppColors.error : AppColors.accent, size: 22),
                title: Text(a.label, style: AppText.body.copyWith(color: a.destructive ? AppColors.error : AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(sheet);
                  a.onTap();
                },
              ),
          ]),
        ),
      ),
    ),
  );
}

Widget _sheetHeader(String seed, String title, String subtitle) => Row(children: [
      Artwork(seed: seed, size: 56),
      const SizedBox(width: Space.md),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.h3),
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.secondary.muted),
        ]),
      ),
    ]);

Future<void> showTrackActions(BuildContext context, Track t) {
  final s = context.services;
  final fav = s.library.isFavorite(t.id);
  final lyrics = s.lyrics.available(LyricsService.sourceTrackOf(t));
  return _actionSheet(context, header: _sheetHeader(t.artSeed, t.title, t.artist), actions: [
    _SheetAction(LucideIcons.play, 'Play', () => s.player.playTrack(t)),
    _SheetAction(LucideIcons.listPlus, 'Play next', () {
      s.player.playNext(t);
      showToast(context, 'Playing next');
    }),
    _SheetAction(LucideIcons.listMusic, 'Add to queue', () {
      s.player.addToQueue(t);
      showToast(context, 'Added to queue');
    }),
    _SheetAction(LucideIcons.plus, 'Add to playlist', () => showAddToPlaylist(context, t.id)),
    _SheetAction(LucideIcons.heart, fav ? 'Remove from favorites' : 'Add to favorites', () => s.library.toggleFavorite(t.id)),
    if (lyrics) _SheetAction(LucideIcons.textQuote, 'Lyrics', () => context.push('/lyrics', extra: LyricsService.sourceTrackOf(t))),
    _SheetAction(LucideIcons.share2, 'Share', () => shareTrack(context, t)),
    _SheetAction(LucideIcons.arrowDownToLine, 'Save a copy to device', () => exportTrack(context, t)),
    if (!t.inLibrary) _SheetAction(LucideIcons.library, 'Add to library', () => s.library.setInLibrary(t.id, true)),
    _SheetAction(LucideIcons.trash2, 'Delete from device', () async {
      if (await confirm(context, title: 'Delete “${t.title}”?', message: 'The file will be removed from this device.')) {
        await s.deleteTrack(t.id);
        if (context.mounted) showToast(context, 'Deleted from this device');
      }
    }, destructive: true),
  ]);
}


Future<void> showGroupActions(BuildContext context, TrackGroup g) {
  final s = context.services;
  final local = g.sources.map((x) => s.library.byId(x.localId)).whereType<Track>().firstOrNull;
  return _actionSheet(context, header: _sheetHeader(g.artSeed, g.title, g.artist), actions: [
    if (local != null) _SheetAction(LucideIcons.play, 'Play from device', () => s.player.playTrack(local)),
    if (g.canPreview) _SheetAction(LucideIcons.play, 'Preview', () => s.player.playPreview(g)),
    if (g.canDownload && local == null) _SheetAction(LucideIcons.download, 'Download', () => startDownload(context, g)),
    _SheetAction(LucideIcons.globe, 'View sources & details', () => context.push('/track', extra: g)),
  ]);
}

void startDownload(BuildContext context, TrackGroup g, {SourceTrack? from}) {
  final s = context.services;
  if (!s.network.isOnline) {
    showToast(context, "You're offline. Downloads resume when you reconnect.");
  }
  final task = s.downloads.start(g, from: from);
  if (task != null) showToast(context, 'Downloading “${g.title}” from ${task.source.sourceName}', action: 'View', onAction: () => context.go('/downloads'));
}

Future<void> showAddToPlaylist(BuildContext context, String trackId) {
  final s = context.services;
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (sheet) => SafeArea(
      child: ListenableBuilder(
        listenable: s.playlists,
        builder: (_, _) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.lg),
          children: [
            Text('Add to playlist', style: AppText.h2),
            const SizedBox(height: Space.md),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(backgroundColor: AppColors.surfaceElevated, child: Icon(LucideIcons.plus, color: AppColors.accent)),
              title: Text('New playlist', style: AppText.bodyMedium),
              onTap: () async {
                final name = await promptText(sheet, title: 'New playlist', hint: 'Playlist name', confirmLabel: 'Create');
                if (name == null) return;
                final p = await s.playlists.create(name, trackIds: [trackId]);
                if (sheet.mounted) Navigator.pop(sheet);
                if (context.mounted) showToast(context, 'Added to ${p.name}');
              },
            ),
            for (final p in s.playlists.all)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Artwork(seed: p.trackIds.isEmpty ? p.id : (s.library.byId(p.trackIds.first)?.artSeed ?? p.id), size: 44),
                title: Text(p.name, style: AppText.bodyMedium),
                subtitle: Text('${p.trackIds.length} songs', style: AppText.caption.muted),
                trailing: p.trackIds.contains(trackId) ? const Icon(LucideIcons.check, color: AppColors.success) : null,
                onTap: () async {
                  final added = await s.playlists.addTrack(p.id, trackId);
                  if (sheet.mounted) Navigator.pop(sheet);
                  if (context.mounted) showToast(context, added ? 'Added to ${p.name}' : 'Already in ${p.name}');
                },
              ),
          ],
        ),
      ),
    ),
  );
}

Future<void> shareTrack(BuildContext context, Track t) async {
  final outcome = await context.services.share.shareTrack(t);
  if (!context.mounted) return;
  switch (outcome) {
    case ShareOutcome.exported:
      showToast(context, 'Sharing files isn’t supported here, so a copy was saved instead.');
    case ShareOutcome.unavailable:
      showToast(context, 'Sharing isn’t available on this device.');
    case ShareOutcome.failed:
      showToast(context, 'This file could not be found on the device.');
    case ShareOutcome.shared || ShareOutcome.dismissed:
      break;
  }
}

Future<void> exportTrack(BuildContext context, Track t) async {
  final ok = await context.services.share.exportToDevice(t);
  if (context.mounted) showToast(context, ok ? 'Saved a copy of “${t.title}”' : 'Save cancelled');
}

/// "Download complete" bottom sheet.
Future<void> showDownloadComplete(BuildContext context, Track t) {
  final s = context.services;
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xxl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.success.withValues(alpha: 0.16),
              border: Border.all(color: AppColors.success, width: 1.5),
              boxShadow: [BoxShadow(color: AppColors.success.withValues(alpha: 0.35), blurRadius: 28)],
            ),
            child: const Icon(LucideIcons.check, color: AppColors.success, size: 30),
          ),
          const SizedBox(height: Space.md),
          Semantics(liveRegion: true, child: Text('Download complete', style: AppText.h2)),
          const SizedBox(height: 4),
          Text(s.library.files.isBrowserStorage ? 'Saved in this browser’s storage' : 'Saved locally on this device',
              style: AppText.secondary.muted),
          const SizedBox(height: Space.lg),
          AppCard(
            opacity: 0.9,
            child: Row(children: [
              Artwork(seed: t.artSeed, size: 48),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.title, style: AppText.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('${formatBytes(t.sizeBytes)} · via ${t.sourceName ?? 'source'}', style: AppText.caption.muted),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: Space.lg),
          AppButton(
            label: 'Play Now',
            icon: LucideIcons.play,
            expand: true,
            onPressed: () {
              Navigator.pop(sheet);
              s.player.playTrack(t);
            },
          ),
          const SizedBox(height: Space.sm),
          Row(children: [
            Expanded(
              child: AppButton.secondary(
                label: 'View Downloads',
                expand: true,
                onPressed: () {
                  Navigator.pop(sheet);
                  context.go('/downloads');
                },
              ),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: AppButton.secondary(
                label: 'Share',
                icon: LucideIcons.share2,
                expand: true,
                onPressed: () {
                  Navigator.pop(sheet);
                  shareTrack(context, t);
                },
              ),
            ),
          ]),
        ]),
      ),
    ),
  );
}
