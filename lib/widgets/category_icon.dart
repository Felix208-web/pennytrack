import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/formatters.dart';

/// Rounded square with the category's icon on a tint of its colour.
class CategoryIcon extends StatelessWidget {
  const CategoryIcon({
    super.key,
    required this.category,
    this.size = 46,
  });

  final String category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.category(category);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(
        getCategoryIcon(category),
        color: color,
        size: size * 0.48,
      ),
    );
  }
}
