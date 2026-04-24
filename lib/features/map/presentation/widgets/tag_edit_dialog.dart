import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memomap/features/map/presentation/widgets/color_picker_field.dart';
import 'package:memomap/features/map/providers/tag_provider.dart';

class TagEditDialog extends ConsumerStatefulWidget {
  const TagEditDialog({super.key, this.existing});

  /// When null, creates a new tag; otherwise edits the given tag.
  final TagData? existing;

  static Future<TagData?> show(BuildContext context, {TagData? existing}) {
    return showDialog<TagData>(
      context: context,
      builder: (_) => TagEditDialog(existing: existing),
    );
  }

  @override
  ConsumerState<TagEditDialog> createState() => _TagEditDialogState();
}

class _TagEditDialogState extends ConsumerState<TagEditDialog> {
  late final TextEditingController _nameController;
  late Color _selectedColor;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _selectedColor = widget.existing != null
        ? Color(widget.existing!.color)
        : kTagPresetColors.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'タグ名を入力してください');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final notifier = ref.read(tagsProvider.notifier);
    final colorInt = _selectedColor.toARGB32();
    try {
      TagData? result;
      if (widget.existing == null) {
        result = await notifier.createTag(name: name, color: colorInt);
      } else {
        result = await notifier.updateTag(
          widget.existing!,
          name: name,
          color: colorInt,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().contains('already exists')
            ? '同じ名前のタグが既に存在します'
            : '保存に失敗しました';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'タグを編集' : '新しいタグ'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'タグ名',
                border: OutlineInputBorder(),
              ),
              maxLength: 50,
            ),
            const SizedBox(height: 12),
            const Text('色'),
            const SizedBox(height: 8),
            ColorPickerField(
              selectedColor: _selectedColor,
              onChanged: (c) => setState(() => _selectedColor = c),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
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
