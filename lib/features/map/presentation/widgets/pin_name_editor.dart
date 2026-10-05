import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memomap/features/map/providers/pin_provider.dart';

Future<void> showPinNameEditor(
  BuildContext context,
  WidgetRef ref,
  PinData pin,
) async {
  final controller = TextEditingController(text: pin.name ?? 'ピン');

  try {
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ピンの名前を編集'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
          decoration: const InputDecoration(labelText: '名前'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (name != null) {
      await ref.read(pinsProvider.notifier).updatePinName(pin.id, name);
    }
  } finally {
    controller.dispose();
  }
}
