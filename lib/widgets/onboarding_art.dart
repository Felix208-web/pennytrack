import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A small floating label on an onboarding illustration.
class ArtChip {
  const ArtChip({
    required this.icon,
    required this.text,
    required this.color,
    required this.alignment,
  });

  final IconData icon;
  final String text;
  final Color color;

  /// Where the chip sits over the orb, e.g. Alignment(-1, -0.6).
  final Alignment alignment;
}

/// Illustration for a welcome slide: a glowing orange orb with an icon,
/// and chips that gently float around it.
class OnboardingArt extends StatefulWidget {
  const OnboardingArt({
    super.key,
    required this.icon,
    required this.chips,
  });

  final IconData icon;
  final List<ArtChip> chips;

  @override
  State<OnboardingArt> createState() => _OnboardingArtState();
}

class _OnboardingArtState extends State<OnboardingArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.maxWidth;

          return AnimatedBuilder(
            animation: _float,
            builder: (context, _) {
              final t = _float.value * 2 * math.pi;

              return Stack(
                alignment: Alignment.center,
                children: [
                  // Soft glow.
                  Container(
                    width: size * 0.95,
                    height: size * 0.95,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.orange.withValues(alpha: 0.28),
                          AppColors.orange.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                  // Orbit ring.
                  Container(
                    width: size * 0.78,
                    height: size * 0.78,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.orange.withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                  // Orb.
                  Transform.translate(
                    offset: Offset(0, math.sin(t) * 6),
                    child: Container(
                      width: size * 0.5,
                      height: size * 0.5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.orangeGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.orangeDeep.withValues(alpha: 0.5),
                            blurRadius: 40,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: size * 0.3,
                        height: size * 0.3,
                        decoration: const BoxDecoration(
                          color: AppColors.background,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.icon,
                          color: AppColors.orange,
                          size: size * 0.14,
                        ),
                      ),
                    ),
                  ),
                  for (var i = 0; i < widget.chips.length; i++)
                    Align(
                      alignment: widget.chips[i].alignment,
                      child: Transform.translate(
                        // Each chip floats out of step with the others.
                        offset: Offset(0, math.sin(t + i * 2.1) * 8),
                        child: _Chip(chip: widget.chips[i]),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.chip});

  final ArtChip chip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: chip.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(chip.icon, size: 16, color: chip.color),
          ),
          const SizedBox(width: 8),
          Text(
            chip.text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
