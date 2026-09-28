import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class DonutSegment {
  const DonutSegment({
    required this.value,
    required this.color,
  });

  final double value;
  final Color color;
}

/// Ring chart with rounded, separated segments, drawn clockwise from the
/// top. Animates in whenever the segments change. [center] is shown in the
/// hole.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.segments,
    this.size = 220,
    this.strokeWidth = 26,
    this.center,
  });

  final List<DonutSegment> segments;
  final double size;
  final double strokeWidth;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // A new key restarts the animation when the data changes.
      key: ValueKey(segments.map((s) => '${s.value}:${s.color}').join('|')),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) {
        return CustomPaint(
          painter: _DonutPainter(
            segments: segments,
            strokeWidth: strokeWidth,
            progress: progress,
          ),
          child: child,
        );
      },
      child: SizedBox.square(
        dimension: size,
        child: Center(child: center),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.segments,
    required this.strokeWidth,
    required this.progress,
  });

  final List<DonutSegment> segments;
  final double strokeWidth;
  final double progress;

  static const _gap = 0.07;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      paint..color = AppColors.surfaceHigh,
    );

    final total = segments.fold<double>(0, (sum, s) => sum + s.value);

    if (total <= 0) return;

    paint.strokeCap = StrokeCap.round;

    final visible = segments.where((s) => s.value > 0).toList();

    if (visible.length == 1) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * progress * 0.9999,
        false,
        paint..color = visible.first.color,
      );
      return;
    }

    // Round caps stick out past the arc's ends by half the stroke width;
    // leave room for them so segments don't overlap.
    final capAngle = (strokeWidth / 2) / radius;
    var start = -math.pi / 2;

    for (final segment in visible) {
      final sweep = math.pi * 2 * (segment.value / total) * progress;
      final drawSweep = math.max(sweep - _gap - capAngle * 2, 0.0001);

      canvas.drawArc(
        rect,
        start + capAngle + _gap / 2,
        drawSweep,
        false,
        paint..color = segment.color,
      );

      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.segments != segments ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
