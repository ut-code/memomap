import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memomap/features/map/presentation/widgets/tag_edit_dialog.dart';
import 'package:memomap/features/map/providers/pin_provider.dart';
import 'package:memomap/features/map/providers/tag_provider.dart';

class PinEditDialog extends ConsumerStatefulWidget {
  const PinEditDialog({super.key, required this.pin});

  final PinData pin;

  static Future<void> show(BuildContext context, PinData pin) {
    return showDialog<void>(
      context: context,
      builder: (_) => PinEditDialog(pin: pin),
    );
  }

  @override
  ConsumerState<PinEditDialog> createState() => _PinEditDialogState();
}

class _PinEditDialogState extends ConsumerState<PinEditDialog> {
  late Set<String> _selectedTagIds;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedTagIds = widget.pin.tagIds.toSet();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(pinsProvider.notifier)
          .updatePinTags(widget.pin.id, _selectedTagIds.toList());
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  Future<void> _onTagLongPress(TagData tag) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('タグを編集'),
                onTap: () => Navigator.of(ctx).pop('edit'),
              ),
              ListTile(
                leading: Icon(
                  Icons.delete,
                  color: Theme.of(ctx).colorScheme.error,
                ),
                title: Text(
                  'タグを削除',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
                onTap: () => Navigator.of(ctx).pop('delete'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted) return;
    if (action == 'edit') {
      await TagEditDialog.show(context, existing: tag);
    } else if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('タグを削除'),
          content: Text('「${tag.name}」を削除しますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('削除'),
            ),
          ],
        ),
      );
      if (ok == true) {
        await ref.read(tagsProvider.notifier).deleteTag(tag);
        if (!mounted) return;
        setState(() {
          _selectedTagIds.remove(tag.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagsProvider);

    return AlertDialog(
      title: const Text('ピンを編集'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '緯度: ${widget.pin.position.latitude.toStringAsFixed(5)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                '経度: ${widget.pin.position.longitude.toStringAsFixed(5)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Text('タグ', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              tagsAsync.when(
                data: (tags) {
                  if (tags.isEmpty) {
                    return const Text('タグがまだありません');
                  }
                  return Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final t in tags)
                        GestureDetector(
                          onLongPress: () => _onTagLongPress(t),
                          child: FilterChip(
                            label: Text(t.name),
                            selected: _selectedTagIds.contains(t.id),
                            onSelected: (sel) {
                              setState(() {
                                if (sel) {
                                  _selectedTagIds.add(t.id);
                                } else {
                                  _selectedTagIds.remove(t.id);
                                }
                              });
                            },
                            backgroundColor: Color(t.color).withValues(alpha: 0.15),
                            selectedColor: Color(t.color).withValues(alpha: 0.5),
                            checkmarkColor: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                    ],
                  );
                },
                loading: () => const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, _) => const Text('タグを読み込めませんでした'),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('新しいタグを作成'),
                onPressed: () async {
                  final created = await TagEditDialog.show(context);
                  if (created != null && mounted) {
                    setState(() {
                      _selectedTagIds.add(created.id);
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存'),
        ),
      ],
    );
  }
}
