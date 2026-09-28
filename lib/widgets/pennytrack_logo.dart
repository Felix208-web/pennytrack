import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class PennyTrackLogo extends StatelessWidget {
  const PennyTrackLogo({
    super.key,
    this.size = 48,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.orangeGradient,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Center(
        child: Text(
          'P',
          style: TextStyle(
            color: Colors.black,
            fontSize: size * 0.55,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
