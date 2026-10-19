import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/models/models.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/util/format.dart';
import '../../data/storage/file_store.dart';
import '../../services/app_services.dart';
import '../../services/download_manager.dart';
import '../../services/library_repository.dart';
import '../widgets/artwork.dart';
import '../widgets/controls.dart';
import '../widgets/page.dart';
import '../widgets/progress.dart';
import '../widgets/rows.dart';
import '../widgets/states.dart';

enum _View { all, songs, albums, artists }

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});
  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  _View _view = _View.all;
  LibrarySort _sort = LibrarySort.recent;
  bool _searching = false;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    return ListenableBuilder(
      listenable: Listenable.merge([s.library, s.downloads]),
      builder: (context, _) {
        final active = s.downloads.active;
        var items = s.library.tracks.where((t) => t.origin == TrackOrigin.download).toList();
        if (_sort == LibrarySort.title) items.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        if (_sort == LibrarySort.artist) items.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
        if (_q.isNotEmpty) {
          final q = _q.toLowerCase();
          items = items.where((t) => '${t.title} ${t.artist} ${t.album}'.toLowerCase().contains(q)).toList();
        }
        final empty = items.isEmpty && active.isEmpty && _q.isEmpty;
        return PageBody(
          title: 'Downloads',
          actions: [
            CircleIconButton(
              icon: _searching ? LucideIcons.x : LucideIcons.search,
              tooltip: _searching ? 'Close search' : 'Search downloads',
              onPressed: () => setState(() {
                _searching = !_searching;
                if (!_searching) _q = '';
              }),
            ),
            PopupMenuButton<LibrarySort>(
              tooltip: 'Sort',
              initialValue: _sort,
              onSelected: (v) => setState(() => _sort = v),
              color: AppColors.surfaceSecondary,
              itemBuilder: (_) => const [
                PopupMenuItem(value: LibrarySort.recent, child: Text('Recently added')),
                PopupMenuItem(value: LibrarySort.title, child: Text('Title')),
                PopupMenuItem(value: LibrarySort.artist, child: Text('Artist')),
              ],
              child: const CircleIconButton(icon: LucideIcons.arrowUpDown, tooltip: 'Sort', onPressed: null, color: AppColors.textPrimary),
            ),
          ],
          slivers: [
            if (_searching) ...[
              box(AppSearchField(autofocus: true, hint: 'Search your downloads', onChanged: (v) => setState(() => _q = v))),
              gap(Space.lg),
            ],
            box(const _StorageCard()),
            gap(Space.xl),
            if (active.isNotEmpty) ...[
              box(SectionHeader('Downloading', action: 'Pause all', onAction: s.downloads.pauseAll)),
              gap(Space.sm),
              SliverList.separated(
                itemCount: active.length,
                separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                itemBuilder: (_, i) => _DownloadTile(task: active[i]),
              ),
              gap(Space.xl),
            ],
            if (empty)
              box(EmptyState(
                icon: LucideIcons.arrowDownToLine,
                title: 'No downloads yet',
                message: 'Search for music and download available tracks.',
                primary: 'Search music',
                onPrimary: () => context.go('/search'),
              ))
            else ...[
              box(Wrap(spacing: Space.sm, children: [
                for (final v in _View.values)
                  AppChip(
                    label: switch (v) { _View.all => 'All', _View.songs => 'Songs', _View.albums => 'Albums', _View.artists => 'Artists' },
                    selected: _view == v,
                    onTap: () => setState(() => _view = v),
                  ),
              ])),
              gap(Space.md),
              if (items.isEmpty && _q.isEmpty)
                box(Text('Finished downloads will appear here.', textAlign: TextAlign.center, style: AppText.secondary.muted))
              else if (items.isEmpty)
                box(Padding(
                  padding: const EdgeInsets.all(Space.xl),
                  child: Text('No downloads match “$_q”.', textAlign: TextAlign.center, style: AppText.secondary.muted),
                ))
              else if (_view == _View.albums || _view == _View.artists)
                ..._grouped(context, items, _view == _View.albums)
              else
                SliverList.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) => TrackRow(
                    track: items[i],
                    showFavorite: true,
                    onTap: () => s.player.playTrack(items[i], context: items),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  List<Widget> _grouped(BuildContext context, List<Track> items, bool albums) {
    final m = <String, List<Track>>{};
    for (final t in items) {
      (m[albums ? (t.album.isEmpty ? 'Unknown album' : t.album) : t.artist] ??= []).add(t);
    }
    final keys = m.keys.toList()..sort();
    return [
      for (final k in keys) ...[
        box(Padding(
          padding: const EdgeInsets.only(top: Space.md, bottom: Space.xs),
          child: Row(children: [
            Artwork(seed: m[k]!.first.artSeed, size: 36, radius: 10),
            const SizedBox(width: Space.md),
            Expanded(child: Text(k, style: AppText.h3)),
            Text('${m[k]!.length}', style: AppText.caption.muted),
          ]),
        )),
        SliverList.list(children: [
          for (final t in m[k]!) TrackRow(track: t, onTap: () => context.services.player.playTrack(t, context: m[k])),
        ]),
      ],
    ];
  }
}

class _StorageCard extends StatefulWidget {
  const _StorageCard();
  @override
  State<_StorageCard> createState() => _StorageCardState();
}

class _StorageCardState extends State<_StorageCard> {
  Future<StorageInfo>? _info;
  int _lastBytes = -1;

  @override
  Widget build(BuildContext context) {
    final lib = context.services.library;
    return ListenableBuilder(listenable: lib, builder: (context, _) => _build(context));
  }

  Widget _build(BuildContext context) {
    final lib = context.services.library;
    if (_lastBytes != lib.totalBytes) {
      _lastBytes = lib.totalBytes;
      _info = lib.files.info();
    }
    return FutureBuilder<StorageInfo>(
      future: _info,
      builder: (context, snap) {
        final info = snap.data;
        final used = info?.usedByApp ?? lib.totalBytes;
        final avail = info?.available;
        final browser = lib.files.isBrowserStorage;
        return AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(LucideIcons.hardDrive, color: AppColors.accent, size: 20),
              const SizedBox(width: Space.md),
              Expanded(child: Text(browser ? 'Saved in this browser' : 'Saved on this device', style: AppText.bodyMedium)),
              Text(formatBytes(used), style: AppText.bodyMedium.secondaryColor),
            ]),
            const SizedBox(height: Space.md),
            ThinProgress(value: avail == null ? (used > 0 ? 0.06 : 0) : (used / (used + avail)).clamp(0.02, 1)),
            const SizedBox(height: Space.sm),
            Text(
              avail != null
                  ? 'About ${formatBytes(avail)} more available to TRUHive'
                  : browser
                      ? 'Browser storage space is managed by your browser.'
                      : 'Files live in TRUHive’s music folder on this device.',
              style: AppText.caption.muted,
            ),
          ]),
        );
      },
    );
  }
}

class _DownloadTile extends StatelessWidget {
  const _DownloadTile({required this.task});
  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final dm = context.services.downloads;
    final t = task;
    final pct = '${(t.progress * 100).round()}%';
    final String info;
    switch (t.status) {
      case DownloadStatus.queued:
        info = t.waitingReason ?? 'Waiting · ${t.total > 0 ? formatBytes(t.total) : ''}';
      case DownloadStatus.downloading:
        info = '${formatBytes(t.received)} of ${formatBytes(t.total)}'
            '${t.bytesPerSecond > 0 ? ' · ${formatBytes(t.bytesPerSecond)}/s' : ''}';
      case DownloadStatus.paused:
        info = 'Paused · ${formatBytes(t.received)} of ${formatBytes(t.total)}';
      case DownloadStatus.saving:
        info = 'Saving locally…';
      case DownloadStatus.failed:
        info = t.error ?? 'Download failed';
      default:
        info = '';
    }
    return Semantics(
      label: '${t.group.title}, ${t.status.name}, $pct',
      child: AppCard(
        padding: const EdgeInsets.all(Space.md),
        borderColor: t.status == DownloadStatus.failed ? AppColors.error.withValues(alpha: 0.6) : null,
        child: Row(children: [
          Artwork(seed: t.group.artSeed, size: 52, radius: 12),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.group.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyMedium),
                    Text('${t.group.artist} · ${t.source.sourceName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.muted),
                  ]),
                ),
                Text(t.status == DownloadStatus.queued ? 'Queued' : pct,
                    style: AppText.caption.copyWith(color: t.status == DownloadStatus.downloading ? AppColors.accent : AppColors.textMuted)),
              ]),
              const SizedBox(height: Space.sm),
              ThinProgress(value: t.progress),
              const SizedBox(height: 6),
              Text(info,
                  style: AppText.caption.copyWith(color: t.status == DownloadStatus.failed ? AppColors.error : AppColors.textMuted)),
            ]),
          ),
          const SizedBox(width: Space.xs),
          if (t.status == DownloadStatus.downloading || t.status == DownloadStatus.queued)
            CircleIconButton(icon: LucideIcons.pause, tooltip: 'Pause', onPressed: () => dm.pause(t), size: 38, iconSize: 16)
          else if (t.status == DownloadStatus.paused || t.status == DownloadStatus.failed)
            CircleIconButton(
              icon: t.status == DownloadStatus.failed ? LucideIcons.rotateCw : LucideIcons.play,
              tooltip: t.status == DownloadStatus.failed ? 'Retry' : 'Resume',
              onPressed: () => dm.resume(t),
              size: 38,
              iconSize: 16,
            ),
          CircleIconButton(
            icon: LucideIcons.x,
            tooltip: 'Cancel download',
            filled: false,
            color: AppColors.textMuted,
            onPressed: t.status == DownloadStatus.saving ? null : () => dm.cancel(t),
          ),
        ]),
      ),
    );
  }
}
