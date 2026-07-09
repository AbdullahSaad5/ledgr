import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The accent palette offered for accounts and categories.
abstract final class AppColors {
  static const swatches = <int>[
    0xFF00696D, // teal (brand)
    0xFF2E7D32, // green
    0xFF1565C0, // blue
    0xFF6A1B9A, // purple
    0xFFAD1457, // pink
    0xFFD84315, // deep orange
    0xFFF9A825, // amber
    0xFF00838F, // cyan
    0xFF4E342E, // brown
    0xFF455A64, // blue grey
  ];
}

/// A horizontal row of selectable colour swatches.
class ColorSwatchPicker extends StatelessWidget {
  const ColorSwatchPicker({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: AppColors.swatches.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final value = AppColors.swatches[i];
          final isSelected = value == selected;
          return GestureDetector(
            onTap: () => onSelected(value),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color(value),
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(
                        color: Theme.of(context).colorScheme.onSurface,
                        width: 3,
                      )
                    : null,
              ),
              child: isSelected
                  ? const Icon(LucideIcons.check, color: Colors.white, size: 20)
                  : null,
            ),
          );
        },
      ),
    );
  }
}
