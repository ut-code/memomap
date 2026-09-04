import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memomap/features/map/providers/pin_provider.dart';

class PinMemoScreen extends ConsumerStatefulWidget {
  final String pinId;
  const PinMemoScreen({required this.pinId, super.key});

  @override
  ConsumerState<PinMemoScreen> createState() => _PinMemoScreenState();
}

class _PinMemoScreenState extends ConsumerState<PinMemoScreen> {
  late final TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pinsAsync = ref.watch(pinsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('メモ'),
      ),
      body: pinsAsync.when(
        data: (pins) {
          PinData? pin;
          try {
            pin = pins.firstWhere((p) => p.id == widget.pinId);
          } catch (_) {
            pin = null;
          }

          if (pin == null) {
            return const Center(child: Text('ピンが見つかりません'));
          }

          // initialize controller value if empty
          if (_controller.text.isEmpty && pin.memo != null) {
            _controller.text = pin.memo!;
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    labelText: 'メモ',
                    hintText: 'このピンに関するメモを入力してください',
                  ),
                  maxLines: null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving
                            ? null
                            : () async {
                                setState(() => _isSaving = true);
                                final text = _controller.text.trim();
                                await ref
                                    .read(pinsProvider.notifier)
                                    .updatePinMemo(widget.pinId, text.isEmpty ? null : text);
                                if (!mounted) return;
                                setState(() => _isSaving = false);
                                context.pop();
                              },
                        child: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('保存'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () async {
                              // clear memo
                              setState(() => _isSaving = true);
                              await ref
                                  .read(pinsProvider.notifier)
                                  .updatePinMemo(widget.pinId, null);
                              if (!mounted) return;
                              setState(() => _isSaving = false);
                              context.pop();
                            },
                      child: const Text('削除'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('エラー: $e')),
      ),
    );
  }
}
