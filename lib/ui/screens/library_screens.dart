import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/models/models.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/util/format.dart';
import '../../services/app_services.dart';
import '../../services/library_repository.dart';
import '../actions.dart';
import '../widgets/artwork.dart';
import '../widgets/controls.dart';
import '../widgets/page.dart';
import '../widgets/rows.dart';
import '../widgets/states.dart';

enum LibraryTab { songs, artists, albums, folders, playlists, favorites }

Future<void> importMusic(BuildContext context) async {
  final n = await context.services.importer.pickAndImport();
  if (!context.mounted || n == null) return;
  showToast(context, n == 1 ? 'Imported 1 file' : 'Imported $n files');
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, this.initialTab});
  final String? initialTab;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late LibraryTab _tab = LibraryTab.values.firstWhere((t) => t.name == widget.initialTab, orElse: () => LibraryTab.songs);
  String? _folder;

  @override
  void didUpdateWidget(LibraryScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialTab != null && widget.initialTab != old.initialTab) {
      _tab = LibraryTab.values.firstWhere((t) => t.name == widget.initialTab, orElse: () => _tab);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    return ListenableBuilder(
      listenable: Listenable.merge([s.library, s.playlists]),
      builder: (context, _) {
        return PageBody(
          title: 'Library',
          actions: [
            CircleIconButton(icon: LucideIcons.folderOpen, tooltip: 'Import music from this device', onPressed: () => importMusic(context)),
            CircleIconButton(
              icon: LucideIcons.plus,
              tooltip: 'New playlist',
              onPressed: () async {
                final name = await promptText(context, title: 'New playlist', hint: 'Playlist name', confirmLabel: 'Create');
                if (name != null) await s.playlists.create(name);
                if (mounted) setState(() => _tab = LibraryTab.playlists);
              },
            ),
          ],
          slivers: [
            box(SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final t in LibraryTab.values) ...[
                  AppChip(label: _label(t), selected: _tab == t, onTap: () => setState(() => _tab = t)),
                  const SizedBox(width: Space.sm),
                ],
              ]),
            )),
            gap(Space.lg),
            ..._body(context),
          ],
        );
      },
    );
  }

  static String _label(LibraryTab t) => switch (t) {
        LibraryTab.songs => 'Songs',
        LibraryTab.artists => 'Artists',
        LibraryTab.albums => 'Albums',
        LibraryTab.folders => 'Folders',
        LibraryTab.playlists => 'Playlists',
        LibraryTab.favorites => 'Favorites',
      };

  Widget _emptyLibrary(BuildContext context) => EmptyState(
        icon: LucideIcons.music,
        title: 'Your library is empty',
        message: 'Download songs from Search, or import music that is already on this device.',
        primary: 'Search music',
        onPrimary: () => context.go('/search'),
        secondary: 'Import from device',
        onSecondary: () => importMusic(context),
      );

  List<Widget> _body(BuildContext context) {
    final s = context.services;
    final lib = s.library;
    switch (_tab) {
      case LibraryTab.songs:
        final list = lib.sorted(LibrarySort.recent);
        if (list.isEmpty) return [box(_emptyLibrary(context))];
        return [
          box(PlayShuffleRow(tracks: list)),
          gap(Space.md),
          if (lib.recentlyPlayed.isNotEmpty) ...[
            box(const SectionHeader('Recently Played')),
            box(SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: lib.recentlyPlayed.take(10).length,
                separatorBuilder: (_, _) => const SizedBox(width: Space.md),
                itemBuilder: (_, i) {
                  final t = lib.recentlyPlayed[i];
                  return InkWell(
                    onTap: () => s.player.playTrack(t),
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 104,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Artwork(seed: t.artSeed, size: 104, radius: 16),
                        const SizedBox(height: 6),
                        Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
                      ]),
                    ),
                  );
                },
              ),
            )),
            gap(Space.md),
          ],
          box(SectionHeader('Recently Added', action: songCount(list.length))),
          SliverList.builder(
            itemCount: list.length,
            itemBuilder: (_, i) => TrackRow(track: list[i], showFavorite: true, onTap: () => s.player.playTrack(list[i], context: list)),
          ),
        ];
      case LibraryTab.artists:
      case LibraryTab.albums:
        final groups = _tab == LibraryTab.artists ? lib.byArtist : lib.byAlbum;
        if (groups.isEmpty) return [box(_emptyLibrary(context))];
        return [
          for (final e in groups.entries) ...[
            box(Padding(
              padding: const EdgeInsets.only(top: Space.md, bottom: Space.xs),
              child: Row(children: [
                Artwork(seed: e.value.first.artSeed, size: 44, radius: _tab == LibraryTab.artists ? 22 : 10),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.key, style: AppText.h3),
                    Text('${e.value.length} ${e.value.length == 1 ? 'song' : 'songs'}', style: AppText.caption.muted),
                  ]),
                ),
                CircleIconButton(icon: LucideIcons.play, tooltip: 'Play ${e.key}', onPressed: () => s.player.playTracks(e.value)),
              ]),
            )),
            SliverList.list(children: [
              for (final t in e.value) TrackRow(track: t, onTap: () => s.player.playTrack(t, context: e.value)),
            ]),
          ],
        ];
      case LibraryTab.folders:
        final downloads = lib.libraryTracks.where((t) => t.origin == TrackOrigin.download).toList();
        final imported = lib.libraryTracks.where((t) => t.origin == TrackOrigin.import).toList();
        final shown = _folder == 'imported' ? imported : _folder == 'downloads' ? downloads : null;
        return [
          box(Row(children: [
            Expanded(child: _FolderCard('TRUHive Downloads', downloads.length, _folder == 'downloads', () => setState(() => _folder = 'downloads'))),
            const SizedBox(width: Space.md),
            Expanded(child: _FolderCard('Imported', imported.length, _folder == 'imported', () => setState(() => _folder = 'imported'))),
          ])),
          gap(Space.md),
          box(Text(
            lib.files.isBrowserStorage
                ? 'Files are kept in this browser’s storage. Use “Save a copy to device” to export one.'
                : 'Location: ${lib.files.locationDescription}',
            style: AppText.caption.muted,
          )),
          gap(Space.md),
          box(AppButton.secondary(label: 'Import music from this device', icon: LucideIcons.folderOpen, expand: true, onPressed: () => importMusic(context))),
          gap(Space.lg),
          if (shown != null && shown.isEmpty)
            box(Text('This folder is empty.', textAlign: TextAlign.center, style: AppText.secondary.muted))
          else if (shown != null)
            SliverList.list(children: [for (final t in shown) TrackRow(track: t, onTap: () => s.player.playTrack(t, context: shown))]),
        ];
      case LibraryTab.playlists:
        final all = s.playlists.all;
        return [
          SliverLayoutBuilder(builder: (context, c) {
            final cols = (c.crossAxisExtent / 180).floor().clamp(2, 6);
            final tileW = (c.crossAxisExtent - (cols - 1) * Space.md) / cols;
            return SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: Space.lg,
                crossAxisSpacing: Space.md,
                mainAxisExtent: tileW + 60, // artwork + two lines of text
              ),
              delegate: SliverChildListDelegate([
                _PlaylistTile(
                  title: 'Favorites',
                  subtitle: songCount(lib.favorites.length),
                  favorite: true,
                  onTap: () => context.push('/favorites'),
                ),
                for (final p in all)
                  _PlaylistTile(
                    title: p.name,
                    subtitle: songCount(p.trackIds.length),
                    seed: p.trackIds.isEmpty ? p.id : (lib.byId(p.trackIds.first)?.artSeed ?? p.id),
                    onTap: () => context.push('/playlist/${p.id}'),
                  ),
              ]),
            );
          }),
          if (all.isEmpty)
            box(const EmptyState(icon: LucideIcons.listMusic, title: 'No playlists yet', message: 'Create your first playlist.')),
        ];
      case LibraryTab.favorites:
        return [box(FavoritesBody(embedded: true))];
    }
  }
}

class _FolderCard extends StatelessWidget {
  const _FolderCard(this.name, this.count, this.selected, this.onTap);
  final String name;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
        onTap: onTap,
        borderColor: selected ? AppColors.borderStrong : null,
        padding: const EdgeInsets.all(Space.md),
        child: Row(children: [
          const Icon(LucideIcons.folder, color: AppColors.accent, size: 22),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('$count files', style: AppText.caption.muted),
            ]),
          ),
        ]),
      );
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({required this.title, required this.subtitle, required this.onTap, this.seed, this.favorite = false});
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? seed;
  final bool favorite;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: LayoutBuilder(builder: (context, c) {
        final size = c.maxWidth;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (favorite)
            Container(
              width: size,
              height: size,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.lightBlue, AppColors.blue]),
              ),
              alignment: Alignment.topLeft,
              child: const Icon(LucideIcons.heart, color: AppColors.navy, size: 26),
            )
          else
            Artwork(seed: seed ?? title, size: size, radius: 18),
          const SizedBox(height: Space.sm),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyMedium),
          Text(subtitle, style: AppText.caption.muted),
        ]);
      }),
    );
  }
}

class PlayShuffleRow extends StatelessWidget {
  const PlayShuffleRow({super.key, required this.tracks});
  final List<Track> tracks;

  @override
  Widget build(BuildContext context) {
    final p = context.services.player;
    final row = Row(children: [
      Expanded(child: AppButton(label: 'Play', icon: LucideIcons.play, compact: true, expand: true, onPressed: tracks.isEmpty ? null : () => p.playTracks(tracks))),
      const SizedBox(width: Space.sm),
      Expanded(
        child: AppButton.secondary(
          label: 'Shuffle',
          icon: LucideIcons.shuffle,
          expand: true,
          onPressed: tracks.isEmpty ? null : () => p.playTracks(tracks, shuffle: true),
        ),
      ),
    ]);
    return Align(alignment: Alignment.centerLeft, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: row));
  }
}

// ---------------------------------------------------------------- Playlist

class PlaylistScreen extends StatelessWidget {
  const PlaylistScreen({super.key, required this.id});
  final String id;

  Future<void> _addSongs(BuildContext context, Playlist p) async {
    final s = context.services;
    final candidates = s.library.libraryTracks.where((t) => !p.trackIds.contains(t.id)).toList();
    if (candidates.isEmpty) {
      showToast(context, 'Everything in your library is already here.');
      return;
    }
    final picked = <String>{};
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, set) => SizedBox(
          height: MediaQuery.of(sheet).size.height * 0.75,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.sm),
              child: Row(children: [
                Expanded(child: Text('Add songs', style: AppText.h2)),
                FilledButton(
                  onPressed: picked.isEmpty
                      ? null
                      : () async {
                          for (final id in picked) {
                            await s.playlists.addTrack(p.id, id);
                          }
                          if (sheet.mounted) Navigator.pop(sheet);
                        },
                  child: Text(picked.isEmpty ? 'Add' : 'Add ${picked.length}'),
                ),
              ]),
            ),
            Expanded(
              child: ListView(children: [
                for (final t in candidates)
                  CheckboxListTile(
                    value: picked.contains(t.id),
                    onChanged: (v) => set(() => v! ? picked.add(t.id) : picked.remove(t.id)),
                    secondary: Artwork(seed: t.artSeed, size: 44),
                    title: Text(t.title, style: AppText.bodyMedium),
                    subtitle: Text(t.artist, style: AppText.caption.muted),
                    activeColor: AppColors.accent,
                    checkColor: AppColors.navy,
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    return DetailScaffold(
      child: ListenableBuilder(
        listenable: Listenable.merge([s.playlists, s.library]),
        builder: (context, _) {
          final p = s.playlists.byId(id);
          if (p == null) {
            return PageBody(back: true, slivers: [
              box(const EmptyState(icon: LucideIcons.listMusic, title: 'Playlist not found', message: 'It may have been deleted.')),
            ]);
          }
          final tracks = [for (final t in p.trackIds) ?s.library.byId(t)];
          final total = tracks.fold(Duration.zero, (a, t) => a + t.duration);
          return PageBody(
            back: true,
            actions: [
              CircleIconButton(icon: LucideIcons.listPlus, tooltip: 'Add songs', onPressed: () => _addSongs(context, p)),
              PopupMenuButton<String>(
                tooltip: 'Playlist options',
                color: AppColors.surfaceSecondary,
                onSelected: (v) async {
                  if (v == 'rename') {
                    final name = await promptText(context, title: 'Rename playlist', initial: p.name);
                    if (name != null) await s.playlists.rename(p.id, name);
                  } else if (v == 'delete') {
                    if (await confirm(context, title: 'Delete “${p.name}”?', message: 'Songs stay on your device.')) {
                      await s.playlists.delete(p.id);
                      if (context.mounted) context.pop();
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(value: 'delete', child: Text('Delete playlist')),
                ],
                child: const CircleIconButton(icon: LucideIcons.ellipsis, tooltip: 'Playlist options', onPressed: null, color: AppColors.textPrimary),
              ),
            ],
            slivers: [
              box(Row(children: [
                Artwork(seed: tracks.isEmpty ? p.id : tracks.first.artSeed, size: 112, radius: 20, shadow: Effects.soft),
                const SizedBox(width: Space.lg),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Playlist · ${songCount(tracks.length)}${total >= const Duration(minutes: 1) ? ' · ${total.inMinutes} min' : ''}', style: AppText.caption.muted),
                    const SizedBox(height: 4),
                    Text(p.name, style: AppText.h1, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('Created on this device', style: AppText.caption.secondaryColor),
                  ]),
                ),
              ])),
              gap(Space.xl),
              box(PlayShuffleRow(tracks: tracks)),
              gap(Space.lg),
              if (tracks.isEmpty)
                box(EmptyState(
                  icon: LucideIcons.listMusic,
                  title: 'No songs yet',
                  message: 'Add songs from your library to this playlist.',
                  primary: 'Add songs',
                  onPrimary: () => _addSongs(context, p),
                ))
              else
                SliverReorderableList(
                  itemCount: tracks.length,
                  onReorderItem: (a, b) => s.playlists.reorder(p.id, a, b),
                  itemBuilder: (context, i) {
                    final t = tracks[i];
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey('${p.id}-${t.id}'),
                      index: i,
                      child: Material(
                        color: Colors.transparent,
                        child: TrackRow(
                          track: t,
                          index: i + 1,
                          onTap: () => s.player.playTrack(t, context: tracks),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            PopupMenuButton<String>(
                              tooltip: 'Move or remove',
                              color: AppColors.surfaceSecondary,
                              icon: const Icon(LucideIcons.arrowUpDown, size: 18, color: AppColors.textMuted),
                              onSelected: (v) {
                                if (v == 'up' && i > 0) s.playlists.reorder(p.id, i, i - 1);
                                if (v == 'down' && i < tracks.length - 1) s.playlists.reorder(p.id, i, i + 1);
                                if (v == 'remove') s.playlists.removeTrack(p.id, t.id);
                              },
                              itemBuilder: (_) => [
                                if (i > 0) const PopupMenuItem(value: 'up', child: Text('Move up')),
                                if (i < tracks.length - 1) const PopupMenuItem(value: 'down', child: Text('Move down')),
                                const PopupMenuItem(value: 'remove', child: Text('Remove from playlist')),
                              ],
                            ),
                            ReorderableDragStartListener(
                              index: i,
                              child: const Padding(
                                padding: EdgeInsets.all(Space.sm),
                                child: Icon(LucideIcons.gripVertical, size: 18, color: AppColors.textMuted, semanticLabel: 'Drag to reorder'),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- Favorites

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) => const DetailScaffold(child: FavoritesBody());
}

class FavoritesBody extends StatefulWidget {
  const FavoritesBody({super.key, this.embedded = false});
  final bool embedded;
  @override
  State<FavoritesBody> createState() => _FavoritesBodyState();
}

class _FavoritesBodyState extends State<FavoritesBody> {
  String _q = '';
  LibrarySort _sort = LibrarySort.recent;

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    return ListenableBuilder(
      listenable: s.library,
      builder: (context, _) {
        var list = s.library.favorites;
        if (_sort == LibrarySort.title) list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        if (_sort == LibrarySort.artist) list.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
        if (_q.isNotEmpty) list = list.where((t) => '${t.title} ${t.artist}'.toLowerCase().contains(_q.toLowerCase())).toList();
        final empty = s.library.favorites.isEmpty;
        final content = <Widget>[
          if (empty)
            EmptyState(
              icon: LucideIcons.heart,
              title: 'No favorites yet',
              message: 'Songs you favorite will appear here.',
              primary: 'Browse downloads',
              onPrimary: () => context.go('/downloads'),
            )
          else ...[
            PlayShuffleRow(tracks: list),
            const SizedBox(height: Space.md),
            Row(children: [
              Expanded(child: AppSearchField(hint: 'Search favorites', onChanged: (v) => setState(() => _q = v))),
              const SizedBox(width: Space.sm),
              PopupMenuButton<LibrarySort>(
                tooltip: 'Sort',
                color: AppColors.surfaceSecondary,
                onSelected: (v) => setState(() => _sort = v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: LibrarySort.recent, child: Text('Recently added')),
                  PopupMenuItem(value: LibrarySort.title, child: Text('Title')),
                  PopupMenuItem(value: LibrarySort.artist, child: Text('Artist')),
                ],
                child: const CircleIconButton(icon: LucideIcons.arrowUpDown, tooltip: 'Sort', onPressed: null, color: AppColors.textPrimary),
              ),
            ]),
            const SizedBox(height: Space.sm),
            for (final t in list)
              TrackRow(
                track: t,
                onTap: () => s.player.playTrack(t, context: list),
                trailing: CircleIconButton(
                  icon: LucideIcons.heart,
                  tooltip: 'Remove from favorites',
                  filled: false,
                  color: AppColors.accent,
                  onPressed: () => s.library.toggleFavorite(t.id),
                ),
              ),
          ],
        ];
        if (widget.embedded) return Column(children: content);
        return PageBody(title: 'Favorites', back: true, slivers: [SliverList.list(children: content)]);
      },
    );
  }
}
