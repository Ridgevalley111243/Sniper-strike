import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../services/app_services.dart';
import '../../services/search_controller.dart';
import '../../sources/music_source.dart';
import '../widgets/controls.dart';
import '../widgets/page.dart';
import '../widgets/rows.dart';
import '../widgets/states.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final _text = TextEditingController(text: context.services.search.query);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _text.text.isEmpty) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _openFilters(MusicSearchController search) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheet) => StatefulBuilder(builder: (sheet, setSheet) {
        final f = search.filters;
        return Padding(
          padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xxl),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Filter results', style: AppText.h2),
            const SizedBox(height: Space.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Downloadable only', style: AppText.body),
              subtitle: Text('Hide tracks no source lets you download', style: AppText.caption.muted),
              value: f.downloadableOnly,
              onChanged: (v) {
                search.setFilters(SearchFilters(downloadableOnly: v, genre: f.genre));
                setSheet(() {});
              },
            ),
            const SizedBox(height: Space.sm),
            Text('GENRE', style: AppText.metadata.muted),
            const SizedBox(height: Space.sm),
            Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
              AppChip(
                label: 'Any',
                selected: f.genre == null,
                onTap: () {
                  search.setFilters(SearchFilters(downloadableOnly: f.downloadableOnly));
                  setSheet(() {});
                },
              ),
              for (final g in search.genres.toList()..sort())
                AppChip(
                  label: g,
                  selected: f.genre == g,
                  onTap: () {
                    search.setFilters(SearchFilters(downloadableOnly: f.downloadableOnly, genre: g));
                    setSheet(() {});
                  },
                ),
            ]),
          ]),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final search = s.search;
    return ListenableBuilder(
      listenable: Listenable.merge([search, s.sources, s.network]),
      builder: (context, _) {
        final offline = !s.network.isOnline;
        final results = search.results;
        final enabled = s.sources.enabled;
        return PageBody(slivers: [
          box(Row(children: [
            Expanded(
              child: AppSearchField(
                controller: _text,
                focusNode: _focus,
                enabled: !offline,
                onChanged: search.onQueryChanged,
                onSubmitted: (_) => search.run(),
                onFilter: () => _openFilters(search),
                filterActive: search.filters.isActive,
              ),
            ),
          ])),
          gap(Space.md),
          box(SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              AppChip(label: 'All sources', icon: LucideIcons.globe, selected: search.sourceFilter == null, onTap: () => search.setSourceFilter(null)),
              for (final src in enabled) ...[
                const SizedBox(width: Space.sm),
                AppChip(label: src.name, selected: search.sourceFilter == src.id, onTap: () => search.setSourceFilter(src.id)),
              ],
              const SizedBox(width: Space.sm),
              AppChip(label: 'Manage', icon: LucideIcons.settings, selected: false, onTap: () => context.push('/sources')),
            ]),
          )),
          gap(Space.lg),
          if (offline)
            box(const OfflineBanner())
          else if (enabled.isEmpty)
            box(EmptyState(
              icon: LucideIcons.globe,
              title: 'No sources enabled',
              message: 'Turn on at least one music source to search.',
              primary: 'Manage Sources',
              onPrimary: () => context.push('/sources'),
            ))
          else if (!search.hasSearched)
            box(const EmptyState(
              icon: LucideIcons.search,
              title: 'Search for a song, artist or album',
              message: 'TRUHive searches all of your enabled sources at once and groups duplicates.',
            ))
          else ...[
            box(_SourceStatus(search: search)),
            gap(Space.lg),
            box(SectionHeader('Results', action: results.isEmpty ? null : '${results.length} tracks')),
            if (results.isEmpty && search.isLoading)
              SliverList.list(children: [for (var i = 0; i < 4; i++) SongRowSkeleton(index: i)])
            else if (results.isEmpty && search.failed.length == search.searchedSources.length)
              box(InlineError(
                title: "We couldn't reach your sources.",
                message: 'Check your connection, or try again in a moment.',
                onRetry: search.run,
                onManage: () => context.push('/sources'),
              ))
            else if (results.isEmpty)
              box(EmptyState(
                icon: LucideIcons.music,
                title: 'No matches',
                message: search.filters.isActive
                    ? 'Nothing matches your filters. Try clearing them.'
                    : 'Try a different spelling, or search by artist or album.',
              ))
            else
              SliverList.builder(
                itemCount: results.length,
                itemBuilder: (_, i) => ResultRow(key: ValueKey(results[i].key), group: results[i]),
              ),
          ],
        ]);
      },
    );
  }
}

/// "Searching 4 sources … ✓ OpenWave ○ IndieVault unavailable [Retry]".
class _SourceStatus extends StatelessWidget {
  const _SourceStatus({required this.search});
  final MusicSearchController search;

  @override
  Widget build(BuildContext context) {
    final sources = search.searchedSources;
    final done = search.responded.length;
    return Semantics(
      liveRegion: true,
      child: AppCard(
        padding: const EdgeInsets.all(Space.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (search.isLoading) ...[
              const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
              const SizedBox(width: Space.sm),
            ],
            Expanded(
              child: Text(search.isLoading ? 'Searching ${sources.length} sources…' : 'Searched ${sources.length} sources',
                  style: AppText.caption.secondaryColor),
            ),
            Text('$done of ${sources.length} responded', style: AppText.caption.muted),
          ]),
          const SizedBox(height: Space.sm),
          Wrap(spacing: Space.md, runSpacing: 6, children: [
            for (final src in sources) _StatusChip(source: src, search: search),
          ]),
          for (final e in search.failed.entries) ...[
            const SizedBox(height: Space.sm),
            Row(children: [
              Expanded(
                child: Text('${context.services.sources.byId(e.key)?.name ?? e.key} ${e.value}. Your other sources are still available.',
                    style: AppText.caption.muted),
              ),
              TextButton.icon(
                onPressed: () => search.retry(e.key),
                icon: const Icon(LucideIcons.rotateCw, size: 14),
                label: const Text('Retry'),
                style: TextButton.styleFrom(foregroundColor: AppColors.accent, minimumSize: const Size(44, 36)),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.source, required this.search});
  final MusicSource source;
  final MusicSearchController search;

  @override
  Widget build(BuildContext context) {
    final loading = search.loading.contains(source.id);
    final failed = search.failed.containsKey(source.id);
    final Widget lead = loading
        ? const SizedBox.square(dimension: 10, child: CircularProgressIndicator(strokeWidth: 1.6, color: AppColors.textMuted))
        : failed
            ? const Icon(LucideIcons.circle, size: 11, color: AppColors.textMuted)
            : const Icon(LucideIcons.check, size: 13, color: AppColors.success);
    final state = loading ? 'searching' : failed ? 'unavailable' : 'responded';
    return Semantics(
      label: '${source.name} $state',
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        lead,
        const SizedBox(width: 5),
        Text(source.name, style: AppText.caption.copyWith(color: failed ? AppColors.textMuted : AppColors.textPrimary)),
      ]),
    );
  }
}
