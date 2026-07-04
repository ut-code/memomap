import 'package:flutter/material.dart';
import 'package:memomap/features/map/data/pin_repository.dart';

class PinLabelsOverlay extends StatelessWidget {
  final List<PinData> pins;
  final Map<String, Offset> pinScreenPositions;

  const PinLabelsOverlay({
    super.key,
    required this.pins,
    required this.pinScreenPositions,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          for (final pin in pins)
            if (pin.name.isNotEmpty && pinScreenPositions.containsKey(pin.id))
              Positioned(
                left: pinScreenPositions[pin.id]!.dx - 30,
                top: pinScreenPositions[pin.id]!.dy - 40,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    pin.name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
