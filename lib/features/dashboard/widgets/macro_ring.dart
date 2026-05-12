import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final _fmt = NumberFormat('#,###');

class MacroRing extends StatelessWidget {
  final double consumed;
  final double target;
  final String label;
  final String unit;
  final Color color;
  final bool large;

  const MacroRing({
    super.key,
    required this.consumed,
    required this.target,
    required this.label,
    required this.unit,
    required this.color,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final isOver = target > 0 && consumed > target;
    final progress = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
    final remaining = target - consumed;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.maxWidth;
            final strokeWidth = large ? size * 0.08 : size * 0.1;
            final fontSize = large ? size * 0.14 : size * 0.12;
            final subFontSize = large ? size * 0.07 : size * 0.06;

            return SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOut,
                    builder: (context, value, _) => CustomPaint(
                      painter: _RingPainter(
                        progress: value,
                        color: color,
                        isOver: isOver,
                        strokeWidth: strokeWidth,
                      ),
                      size: Size(size, size),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _fmt.format(consumed.round()),
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '/ ${_fmt.format(target.round())} $unit',
                        style: TextStyle(
                          fontSize: subFontSize,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        if (large) ...[
          const SizedBox(height: 4),
          Text(
            remaining > 0
                ? '${_fmt.format(remaining.round())} remaining'
                : remaining < 0
                    ? '${_fmt.format((-remaining).round())} over'
                    : '0 remaining',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: remaining < 0 ? Colors.red : Colors.grey,
            ),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: large ? 16 : 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isOver;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.isOver,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    if (progress > 0) {
      final fillColor = isOver ? Colors.red : color;
      final fillPaint = Paint()
        ..color = fillColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, fillPaint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.isOver != isOver;
}
