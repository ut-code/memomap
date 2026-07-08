import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memomap/features/map/providers/drawing_provider.dart';
import 'package:memomap/icons/my_flutter_app_icons.dart';

class Controls extends ConsumerWidget {
  const Controls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drawingStateAsync = ref.watch(drawingProvider);
    final drawingState = drawingStateAsync.valueOrNull;
    final isDrawingMode = drawingState?.isDrawingMode ?? false;
    final isEraserMode = drawingState?.isEraserMode ?? false;
    final selectedColor = drawingState?.selectedColor ?? Colors.red;
    final strokeWidth = drawingState?.strokeWidth ?? 3;
    final drawingNotifier = ref.read(drawingProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.22),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: Row(
          children: [
            // ピンモードボタン
            GestureDetector(
              onTap: () => drawingNotifier.setDrawingMode(false),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      Icons.explore,
                      size: 60,
                      color: !isDrawingMode ? colorScheme.primary : Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
            // 描画モードコントロール（展開・折りたたみ）
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      axis: Axis.horizontal,
                      axisAlignment: -1,
                      child: child,
                    ),
                  );
                },
                child: isDrawingMode
                    ? Container(
                        key: const ValueKey('expanded_controls'),
                        padding: const EdgeInsets.only(bottom: 24, top: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // UndoButtonBar
                            OverflowBar(
                              alignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.undo_rounded),
                                  tooltip: '元に戻す',
                                  onPressed: () => drawingNotifier.undo(),
                                ),
                                IconButton(
                                  icon: Icon(
                                    MyFlutterApp.eraser_1,
                                    color: isEraserMode
                                        ? colorScheme.primary
                                        : colorScheme.onSurface,
                                  ),
                                  tooltip: '消しゴム',
                                  onPressed: () => drawingNotifier
                                      .setEraserMode(!isEraserMode),
                                ),
                              ],
                            ),
                            // ColorSelectionWidget
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children:
                                      [
                                            Colors.red,
                                            Colors.yellow,
                                            Colors.green,
                                            Colors.blue,
                                            Colors.purple,
                                            Colors.black,
                                          ]
                                          .asMap()
                                          .entries
                                          .map(
                                            (entry) => _ColorCircle(
                                              index: entry.key,
                                              isSelected:
                                                  !isEraserMode &&
                                                  selectedColor == entry.value,
                                              color: entry.value,
                                              onTap: () => drawingNotifier
                                                  .selectColor(entry.value),
                                            ),
                                          )
                                          .toList(),
                                ),
                                const SizedBox(height: 10),
                                _StrokeWidthSlider(
                                  color: isEraserMode
                                      ? Colors.grey
                                      : selectedColor,
                                  width: strokeWidth,
                                  setWidth: (newWidth) => drawingNotifier
                                      .changeStrokeWidth(newWidth),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    : GestureDetector(
                        key: const ValueKey('collapsed_icon'),
                        onTap: () => drawingNotifier.setDrawingMode(true),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.brush, size: 60, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorCircle extends StatelessWidget {
  final int index;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _ColorCircle({
    required this.index,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 30,
        height: 30,
        transform: isSelected
            ? Matrix4.diagonal3Values(1.2, 1.2, 1.0)
            : Matrix4.identity(),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
                : Theme.of(context).colorScheme.outlineVariant,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    blurRadius: 4,
                    color: Theme.of(
                      context,
                    ).colorScheme.shadow.withValues(alpha: 0.25),
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

class _StrokeWidthSlider extends StatelessWidget {
  final Color color;
  final double width;
  final ValueChanged<double> setWidth;

  const _StrokeWidthSlider({
    required this.color,
    required this.width,
    required this.setWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // 線の太さを視覚的に示す背景
              Container(
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withValues(alpha: 0.25),
                      Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
                    ],
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CustomPaint(
                    size: const Size(double.infinity, 12),
                    painter: _TaperedBarPainter(color),
                  ),
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                  thumbColor: Theme.of(context).colorScheme.surface,
                  overlayColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  trackHeight: 12,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                    elevation: 2,
                  ),
                ),
                child: Slider(
                  value: width,
                  min: 1,
                  max: 15,
                  onChanged: (value) => setWidth(value),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaperedBarPainter extends CustomPainter {
  final Color color;

  _TaperedBarPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height * 0.4)
      ..lineTo(size.width, size.height * 0.1)
      ..lineTo(size.width, size.height * 0.9)
      ..lineTo(0, size.height * 0.6)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
