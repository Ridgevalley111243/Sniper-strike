import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/util/format.dart';
import '../../services/app_services.dart';
import '../../sources/music_source.dart';
import '../actions.dart';
import '../widgets/artwork.dart';
import '../widgets/controls.dart';
import '../widgets/page.dart';
import '../widgets/states.dart';
import 'library_screens.dart';

// ------------------------------------------------------------------- Queue

class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.services.player;
    return DetailScaffold(
      showPlayer: false,
      child: ListenableBuilder(
        listenable: p,
        builder: (context, _) {
          final current = p.current;
          final next = p.upNext;
          return PageBody(
            title: 'Up Next',
            back: true,
            actions: [
              if (next.isNotEmpty)
                TextButton(
                  onPressed: p.clearUpNext,
                  style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary, minimumSize: const Size(44, 44)),
                  child: const Text('Clear'),
                ),
            ],
            slivers: [
              if (current == null)
                box(const EmptyState(icon: LucideIcons.listMusic, title: 'Nothing queued', message: 'Play a song from your library to start a queue.'))
              else ...[
                box(Text('NOW PLAYING', style: AppText.metadata.muted)),
                gap(Space.sm),
                box(AppCard(
                  borderColor: AppColors.borderStrong,
                  opacity: 0.9,
                  padding: const EdgeInsets.all(Space.md),
                  child: Row(children: [
                    Artwork(seed: current.artSeed, size: 56, radius: 14),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(current.title, style: AppText.bodyMedium.tint(AppColors.accent), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(current.artist, style: AppText.caption.muted),
                      ]),
                    ),
                    CircleIconButton(
                      icon: p.isPlaying ? LucideIcons.pause : LucideIcons.play,
                      tooltip: p.isPlaying ? 'Pause' : 'Play',
                      onPressed: p.togglePlay,
                    ),
                  ]),
                )),
                gap(Space.lg),
                box(Row(children: [
                  Expanded(child: Text('NEXT · ${next.length} ${next.length == 1 ? 'TRACK' : 'TRACKS'}', style: AppText.metadata.muted)),
                  if (p.shuffle) const AppTag('Shuffle on', icon: LucideIcons.shuffle),
                ])),
                gap(Space.sm),
                if (next.isEmpty)
                  box(Text('Nothing else is queued. Use “Play next” or “Add to queue” on any song.', style: AppText.secondary.muted))
                else if (p.shuffle)
                  // Shuffled order is chosen by the player, so manual reordering is disabled.
                  SliverList.list(children: [for (final (i, t) in next) _QueueRow(index: i, title: t.title, artist: t.artist, seed: t.artSeed)])
                else
                  SliverReorderableList(
                    itemCount: next.length,
                    onReorderItem: (a, b) => p.move(next[a].$1, next[b].$1),
                    itemBuilder: (context, k) {
                      final (i, t) = next[k];
                      return ReorderableDelayedDragStartListener(
                        key: ValueKey('q-$i-${t.id}'),
                        index: k,
                        child: _QueueRow(
                          index: i,
                          title: t.title,
                          artist: t.artist,
                          seed: t.artSeed,
                          dragIndex: k,
                          onUp: k > 0 ? () => p.move(i, next[k - 1].$1) : null,
                          onDown: k < next.length - 1 ? () => p.move(i, next[k + 1].$1) : null,
                        ),
                      );
                    },
                  ),
                gap(Space.md),
                box(Text('Drag to reorder, or use the menu on each song to move it up or down.', style: AppText.caption.muted)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.index, required this.title, required this.artist, required this.seed, this.dragIndex, this.onUp, this.onDown});
  final int index;
  final String title;
  final String artist;
  final String seed;
  final int? dragIndex;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  @override
  Widget build(BuildContext context) {
    final p = context.services.player;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: () => p.seekToIndex(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            if (dragIndex != null)
              ReorderableDragStartListener(
                index: dragIndex!,
                child: const Padding(
                  padding: EdgeInsets.all(Space.sm),
                  child: Icon(LucideIcons.gripVertical, size: 18, color: AppColors.textMuted, semanticLabel: 'Drag to reorder'),
                ),
              ),
            Artwork(seed: seed, size: 44, radius: 10),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: AppText.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(artist, style: AppText.caption.muted),
              ]),
            ),
            PopupMenuButton<String>(
              tooltip: 'Queue options for $title',
              color: AppColors.surfaceSecondary,
              icon: const Icon(LucideIcons.ellipsis, size: 18, color: AppColors.textMuted),
              onSelected: (v) {
                if (v == 'up') onUp?.call();
                if (v == 'down') onDown?.call();
                if (v == 'remove') p.removeAt(index);
              },
              itemBuilder: (_) => [
                if (onUp != null) const PopupMenuItem(value: 'up', child: Text('Move up')),
                if (onDown != null) const PopupMenuItem(value: 'down', child: Text('Move down')),
                const PopupMenuItem(value: 'remove', child: Text('Remove from queue')),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------- Source manager

class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key});

  Future<void> _connectBackend(BuildContext context) async {
    final sm = context.services.sources;
    final url = await promptText(
      context,
      title: 'Connect a TRUHive backend',
      initial: sm.backendUrl ?? '',
      hint: 'https://api.example.com',
      confirmLabel: 'Connect',
    );
    if (url == null) return;
    await sm.setBackendUrl(url);
    if (context.mounted) showToast(context, url.trim().isEmpty ? 'Backend disconnected' : 'Backend added');
  }

  @override
  Widget build(BuildContext context) {
    final sm = context.services.sources;
    return DetailScaffold(
      child: ListenableBuilder(
        listenable: sm,
        builder: (context, _) => PageBody(
          title: 'Music Sources',
          back: true,
          actions: [
            CircleIconButton(icon: LucideIcons.rotateCw, tooltip: 'Check all sources', onPressed: sm.checkAll),
          ],
          slivers: [
            box(Text(
              'Choose which authorized sources TRUHive searches. Features appear only where a source supports them.',
              style: AppText.secondary.muted,
            )),
            gap(Space.lg),
            SliverList.separated(
              itemCount: sm.all.length,
              separatorBuilder: (_, _) => const SizedBox(height: Space.md),
              itemBuilder: (context, i) => _SourceCard(source: sm.all[i]),
            ),
            gap(Space.xl),
            box(AppCard(
              onTap: () => _connectBackend(context),
              child: Row(children: [
                const Icon(LucideIcons.globe, color: AppColors.accent),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(sm.backendUrl == null ? 'Connect a backend' : 'Backend: ${sm.backendUrl}', style: AppText.bodyMedium),
                    Text('Real providers run through your TRUHive server, which keeps their API keys private.',
                        style: AppText.caption.muted),
                  ]),
                ),
                const Icon(LucideIcons.chevronRight, color: AppColors.textMuted, size: 18),
              ]),
            )),
          ],
        ),
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.source});
  final MusicSource source;

  @override
  Widget build(BuildContext context) {
    final sm = context.services.sources;
    final health = sm.health(source.id);
    final on = sm.isEnabled(source.id);
    final checked = sm.checkedAt(source.id);
    final (dot, label) = switch (health) {
      SourceHealth.available => (AppColors.success, 'Available'),
      SourceHealth.unavailable => (AppColors.error, 'Unavailable'),
      SourceHealth.checking => (AppColors.warning, 'Checking…'),
      SourceHealth.unknown => (AppColors.textMuted, 'Not checked yet'),
    };
    final ago = checked == null ? '' : ' · checked ${_ago(checked)}';
    final caps = source.capabilities;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(12)),
            child: Text(source.monogram, style: AppText.caption.secondaryColor),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(source.name, style: AppText.bodyMedium)),
                if (source.isDemo) ...[const SizedBox(width: 6), const AppTag('Demo', muted: true)],
              ]),
              const SizedBox(height: 2),
              Row(children: [
                Container(width: 7, height: 7, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Flexible(child: Text('$label$ago', style: AppText.caption.tint(dot == AppColors.textMuted ? AppColors.textMuted : dot))),
              ]),
            ]),
          ),
          Semantics(
            label: '${source.name} ${on ? 'enabled' : 'disabled'}',
            child: Switch(value: on, onChanged: (v) => sm.setEnabled(source.id, v)),
          ),
        ]),
        const SizedBox(height: Space.sm),
        Text(source.description, style: AppText.caption.muted),
        const SizedBox(height: Space.md),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _Cap('Search', caps.search),
          _Cap('Preview', caps.preview),
          _Cap('Download', caps.download),
          _Cap('Lyrics', caps.lyrics),
        ]),
        if (health == SourceHealth.unavailable) ...[
          const SizedBox(height: Space.sm),
          TextButton.icon(
            onPressed: () => sm.check(source.id),
            icon: const Icon(LucideIcons.rotateCw, size: 14),
            label: const Text('Retry connection'),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent, padding: EdgeInsets.zero, minimumSize: const Size(44, 36)),
          ),
        ],
      ]),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    return '${d.inHours} h ago';
  }
}

class _Cap extends StatelessWidget {
  const _Cap(this.label, this.on);
  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$label ${on ? 'supported' : 'not supported'}',
        child: ExcludeSemantics(
          child: AppTag(label, icon: on ? LucideIcons.check : LucideIcons.x, color: on ? AppColors.success : AppColors.textMuted, muted: !on),
        ),
      );
}

// ---------------------------------------------------------------- Settings

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final st = s.settings;
    return DetailScaffold(
      child: ListenableBuilder(
        listenable: Listenable.merge([st, s.library, s.sources]),
        builder: (context, _) => PageBody(title: 'Settings', back: true, slivers: [
          _group('General', [
            _row(LucideIcons.monitorPlay, 'Theme', trailing: Text('Dark', style: AppText.caption.muted)),
          ]),
          _group('Playback', [
            _toggle(LucideIcons.play, 'Autoplay', st.autoplay, (v) => st.autoplay = v,
                subtitle: 'Keep playing from your library when the queue ends'),
            _row(LucideIcons.audioLines, 'Gapless playback',
                subtitle: 'Automatic between songs in a queue, where the platform supports it'),
            _row(LucideIcons.shuffle, 'Shuffle & repeat', trailing: Text('In the player', style: AppText.caption.muted)),
          ]),
          _group('Downloads', [
            _toggle(LucideIcons.library, 'Automatically add downloads to library', st.autoAddDownloads, (v) => st.autoAddDownloads = v),
            _toggle(LucideIcons.wifiOff, 'Download on Wi-Fi only', st.wifiOnlyDownloads, (v) => st.wifiOnlyDownloads = v),
          ]),
          _group('Lyrics & Ads', [
            _toggle(LucideIcons.textQuote, 'Lyrics preview', st.lyricsPreview, (v) => st.lyricsPreview = v),
            _toggle(LucideIcons.tv, 'Unlock lyrics with rewarded ads', st.rewardedAds, (v) => st.rewardedAds = v,
                subtitle: s.lyrics.ads.isDemo ? 'No ad network connected — a demo ad slot is used' : s.lyrics.ads.name),
          ]),
          _group('Storage', [
            _row(LucideIcons.hardDrive, 'Music on this device', trailing: Text(formatBytes(s.library.totalBytes), style: AppText.caption.muted)),
            _row(LucideIcons.folder, s.library.files.isBrowserStorage ? 'Stored in this browser' : 'Download location',
                subtitle: s.library.files.isBrowserStorage
                    ? 'Browsers can’t write to device folders. Use “Save a copy to device” on any song to export it.'
                    : s.library.files.locationDescription),
            _row(LucideIcons.folderOpen, 'Import local music', onTap: () => importMusic(context)),
            if (s.library.files.isBrowserStorage)
              _row(LucideIcons.shieldCheck, 'Keep my music if storage runs low', onTap: () async {
                final ok = await s.library.files.requestPersistence();
                if (context.mounted) showToast(context, ok ? 'This browser will keep your music' : 'The browser declined — it may clear data under pressure');
              }),
            _row(LucideIcons.trash2, 'Clear downloaded music', destructive: true, onTap: () async {
              if (await confirm(context, title: 'Clear all music?', message: 'Every downloaded and imported file will be deleted from this device.', confirmLabel: 'Clear')) {
                await s.player.pause();
                await s.library.clearAll();
                if (context.mounted) showToast(context, 'All music removed from this device');
              }
            }),
          ]),
          _group('About', [
            _row(LucideIcons.globe, 'Music sources',
                trailing: Text('${s.sources.enabled.length} active', style: AppText.caption.muted), onTap: () => context.push('/sources')),
            _row(LucideIcons.info, 'About TRUHive', onTap: () => _about(context)),
            _row(LucideIcons.shieldCheck, 'Privacy & legal', onTap: () => _legal(context)),
          ]),
          gap(Space.lg),
          box(Text('TRUHive 1.0.0 · No account needed. Your music stays on this device.', style: AppText.caption.muted)),
        ]),
      ),
    );
  }

  static void _about(BuildContext context) => showAboutDialog(
        context: context,
        applicationName: 'TRUHive',
        applicationVersion: '1.0.0',
        applicationLegalese: 'Search it. Preview it. Download it. Keep it on your device. Play it offline.',
      );

  static void _legal(BuildContext context) => showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Privacy & legal'),
          content: const Text(
            'TRUHive has no accounts and no cloud library. Your music, playlists and settings are stored only on this device.\n\n'
            'TRUHive only integrates sources that authorize search, preview, download and lyrics display, and never bypasses DRM. '
            'Built-in demo sources serve original music generated on your device.',
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))],
        ),
      );

  static Widget _group(String title, List<Widget> rows) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(bottom: Space.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(left: 4, bottom: Space.sm), child: Text(title.toUpperCase(), style: AppText.metadata.muted)),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(children: [
                for (var i = 0; i < rows.length; i++) ...[if (i > 0) const Divider(), rows[i]],
              ]),
            ),
          ]),
        ),
      );

  static Widget _toggle(IconData icon, String label, bool value, ValueChanged<bool> onChanged, {String? subtitle}) =>
      MergeSemantics(
        child: _row(icon, label, subtitle: subtitle, trailing: Switch(value: value, onChanged: onChanged), onTap: () => onChanged(!value)),
      );

  static Widget _row(IconData icon, String label, {String? subtitle, Widget? trailing, VoidCallback? onTap, bool destructive = false}) =>
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            Icon(icon, size: 20, color: destructive ? AppColors.error : AppColors.accent),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: AppText.body.copyWith(color: destructive ? AppColors.error : AppColors.textPrimary)),
                if (subtitle != null) Text(subtitle, style: AppText.caption.muted),
              ]),
            ),
            ?trailing,
            if (trailing == null && onTap != null) const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textMuted),
          ]),
        ),
      );
}
