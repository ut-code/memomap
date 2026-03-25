import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memomap/features/map/providers/pin_provider.dart';

class PinList extends ConsumerWidget {
  const PinList({super.key, this.onSheetSizeChanged});

  final ValueChanged<double>? onSheetSizeChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinsAsync = ref.watch(pinsProvider);
    final pinsNotifier = ref.watch(pinsProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;
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
                // ピン一覧
                Positioned.fill(
                  child: pinsAsync.when(
                    data: (pins) => ListView.builder(
                      controller: scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 44), // ハンドル分の余白
                      itemCount: pins.length,
                      itemBuilder: (context, index) {
                        final pin = pins[index];
                        return Dismissible(
                          key: ValueKey(pin),
                          onDismissed: (direction) {
                            pinsNotifier.deletePin(pin.id);
                          },
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red,
                            child: Align(
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
                            title: Text('ピン'),
                            subtitle: Text(
                              '緯度: ${pin.position.latitude.toStringAsFixed(4)}, 経度: ${pin.position.longitude.toStringAsFixed(4)}',
                            ),
                            trailing: pin.isLocal
                                ? const Icon(Icons.cloud_off)
                                : const Icon(Icons.cloud_outlined),
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
                // ドラッグハンドル
                IgnorePointer(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
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
