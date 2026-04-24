import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memomap/features/map/presentation/widgets/pin_edit_dialog.dart';
import 'package:memomap/features/map/providers/pin_filter_provider.dart';
import 'package:memomap/features/map/providers/pin_provider.dart';
import 'package:memomap/features/map/providers/tag_provider.dart';

class PinList extends ConsumerWidget {
  const PinList({super.key, this.onSheetSizeChanged});

  final ValueChanged<double>? onSheetSizeChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinsAsync = ref.watch(filteredPinsProvider);
    final pinsNotifier = ref.watch(pinsProvider.notifier);
    final tagsAsync = ref.watch(tagsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final tagsById = <String, TagData>{
      for (final t in (tagsAsync.valueOrNull ?? <TagData>[])) t.id: t,
    };

    return DraggableScrollableSheet(
      initialChildSize: 0.2,
      minChildSize: 0.05,
      maxChildSize: 1,
      snap: true,
      snapSizes: const [0.05, 0.2, 0.4, 0.7, 1],
      builder: (BuildContext context, ScrollController scrollController) {
        return NotificationListener<DraggableScrollableNotification>(
          onNotification: (notification) {
            onSheetSizeChanged?.call(notification.extent);
            return false;
          },
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: pinsAsync.when(
                    data: (pins) => ListView.builder(
                      controller: scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 44),
                      itemCount: pins.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _FilterSection(
                            allTags: tagsAsync.valueOrNull ?? const [],
                          );
                        }
                        final pin = pins[index - 1];
                        return Dismissible(
                          key: ValueKey(pin.id),
                          onDismissed: (direction) {
                            pinsNotifier.deletePin(pin.id);
                          },
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red,
                            child: const Align(
                              alignment: Alignment.centerRight,
                              child: Icon(
                                Icons.delete,
                                color: Colors.white,
                                size: 48,
                              ),
                            ),
                          ),
                          dismissThresholds: const {
                            DismissDirection.startToEnd: 0.7,
                          },
                          child: ListTile(
                            leading: Image.asset('assets/pin.png'),
                            title: const Text('ピン'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '緯度: ${pin.position.latitude.toStringAsFixed(4)}, 経度: ${pin.position.longitude.toStringAsFixed(4)}',
                                ),
                                if (pin.tagIds.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: _PinTagChips(
                                      tagIds: pin.tagIds,
                                      tagsById: tagsById,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  tooltip: '編集',
                                  onPressed: () {
                                    PinEditDialog.show(context, pin);
                                  },
                                ),
                                pin.isLocal
                                    ? const Icon(Icons.cloud_off)
                                    : const Icon(Icons.cloud_outlined),
                              ],
                            ),
                            onTap: () {
                              PinEditDialog.show(context, pin);
                            },
                          ),
                        );
                      },
                    ),
                    loading: () => LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        controller: scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(
                          height: constraints.maxHeight,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ),
                    ),
                    error: (e, st) => LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        controller: scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(
                          height: constraints.maxHeight,
                          child: const Center(child: Text('エラーが発生しました')),
                        ),
                      ),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      child: Center(
                        child: Container(
                          height: 5,
                          width: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PinTagChips extends StatelessWidget {
  const _PinTagChips({required this.tagIds, required this.tagsById});

  final List<String> tagIds;
  final Map<String, TagData> tagsById;

  @override
  Widget build(BuildContext context) {
    const maxChips = 3;
    final visible = tagIds.take(maxChips).toList();
    final extra = tagIds.length - visible.length;
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: [
        for (final id in visible)
          if (tagsById[id] != null)
            _MiniTagChip(tag: tagsById[id]!)
          else
            const SizedBox.shrink(),
        if (extra > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '+$extra',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
      ],
    );
  }
}

class _MiniTagChip extends StatelessWidget {
  const _MiniTagChip({required this.tag});

  final TagData tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Color(tag.color).withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        tag.name,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class _FilterSection extends ConsumerWidget {
  const _FilterSection({required this.allTags});

  final List<TagData> allTags;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(pinFilterProvider);
    final filterNotifier = ref.read(pinFilterProvider.notifier);
    final selectedCount = filter.selectedTagIds.length;

    return ExpansionTile(
      leading: const Icon(Icons.filter_list),
      title: Row(
        children: [
          const Text('タグで絞り込み'),
          const SizedBox(width: 8),
          if (selectedCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$selectedCount',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              SegmentedButton<TagFilterMode>(
                segments: const [
                  ButtonSegment(
                    value: TagFilterMode.or,
                    label: Text('いずれか'),
                  ),
                  ButtonSegment(
                    value: TagFilterMode.and,
                    label: Text('すべて'),
                  ),
                ],
                selected: {filter.mode},
                onSelectionChanged: (set) {
                  filterNotifier.setMode(set.first);
                },
              ),
              const Spacer(),
              if (selectedCount > 0)
                TextButton(
                  onPressed: filterNotifier.clear,
                  child: const Text('クリア'),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: allTags.isEmpty
              ? const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('タグがまだありません'),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final t in allTags)
                      FilterChip(
                        label: Text(t.name),
                        selected: filter.selectedTagIds.contains(t.id),
                        onSelected: (_) => filterNotifier.toggleTag(t.id),
                        backgroundColor: Color(t.color).withValues(alpha: 0.15),
                        selectedColor: Color(t.color).withValues(alpha: 0.5),
                      ),
                  ],
                ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
