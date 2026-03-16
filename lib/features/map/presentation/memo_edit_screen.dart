import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memomap/features/map/providers/pin_provider.dart';

class MemoEditScreen extends ConsumerStatefulWidget {
  const MemoEditScreen({super.key, required this.pinId});

  final String pinId;

  @override
  ConsumerState<MemoEditScreen> createState() => _MemoEditScreenState();
}

class _MemoEditScreenState extends ConsumerState<MemoEditScreen> {
  late final TextEditingController _controller;
  String? _initialMemo;

  @override
  void initState() {
    super.initState();
    final pins = ref.read(pinsProvider).valueOrNull ?? [];
    final pin = pins.where((p) => p.id == widget.pinId).firstOrNull;
    _initialMemo = pin?.memo;
    _controller = TextEditingController(text: _initialMemo ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _saveMemo() {
    final text = _controller.text.trim();
    final memo = text.isEmpty ? null : text;
    ref.read(pinsProvider.notifier).updatePinMemo(widget.pinId, memo);
    context.pop();
  }

  void _deleteMemo() {
    ref.read(pinsProvider.notifier).updatePinMemo(widget.pinId, null);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final hasMemo = _initialMemo != null && _initialMemo!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(hasMemo ? 'メモを編集' : 'メモを追加'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              maxLines: null,
              decoration: const InputDecoration(
                hintText: 'ここにメモを入力',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (hasMemo)
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    onPressed: _deleteMemo,
                    child: const Text('削除'),
                  ),
                ElevatedButton(
                  onPressed: _saveMemo,
                  child: const Text('保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}