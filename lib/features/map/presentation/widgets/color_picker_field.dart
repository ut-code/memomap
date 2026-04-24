import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

const List<Color> kTagPresetColors = [
  Color(0xFFEF5350), // red
  Color(0xFFFF9800), // orange
  Color(0xFFFFEB3B), // yellow
  Color(0xFF66BB6A), // green
  Color(0xFF26C6DA), // cyan
  Color(0xFF42A5F5), // blue
  Color(0xFFAB47BC), // purple
  Color(0xFF8D6E63), // brown
];

class ColorPickerField extends StatelessWidget {
  const ColorPickerField({
    super.key,
    required this.selectedColor,
    required this.onChanged,
  });

  final Color selectedColor;
  final ValueChanged<Color> onChanged;

  Future<void> _openCustomPicker(BuildContext context) async {
    Color temp = selectedColor;
    final picked = await showDialog<Color>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('色を選択'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: temp,
              onColorChanged: (c) => temp = c,
              enableAlpha: false,
              labelTypes: const [],
              pickerAreaHeightPercent: 0.7,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(temp),
              child: const Text('決定'),
            ),
          ],
        );
      },
    );
    if (picked != null) {
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in kTagPresetColors)
          _ColorDot(
            color: c,
            selected: _sameRgb(c, selectedColor),
            onTap: () => onChanged(c),
          ),
        _CustomButton(
          selectedColor: selectedColor,
          isCustom: !kTagPresetColors.any((c) => _sameRgb(c, selectedColor)),
          onTap: () => _openCustomPicker(context),
        ),
      ],
    );
  }

  static bool _sameRgb(Color a, Color b) {
    return a.toARGB32() == b.toARGB32();
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, size: 20, color: Colors.white)
            : null,
      ),
    );
  }
}

class _CustomButton extends StatelessWidget {
  const _CustomButton({
    required this.selectedColor,
    required this.isCustom,
    required this.onTap,
  });

  final Color selectedColor;
  final bool isCustom;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue, Colors.purple],
          ),
          shape: BoxShape.circle,
          border: Border.all(
            color: isCustom
                ? Theme.of(context).colorScheme.onSurface
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: isCustom
            ? Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: selectedColor,
                  shape: BoxShape.circle,
                ),
              )
            : const Icon(Icons.colorize, size: 18, color: Colors.white),
      ),
    );
  }
}
