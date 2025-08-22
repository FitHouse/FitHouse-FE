import 'dart:math' as math;
import 'package:flutter/material.dart';

class WaveProgressBar extends StatefulWidget {
  final double progress; // 0.0 ~ 1.0
  final Color color;
  final double height;

  const WaveProgressBar({
    super.key,
    required this.progress,
    this.color = Colors.blue,
    this.height = 20,
  });

  @override
  State<WaveProgressBar> createState() => _WaveProgressBarState();
}

class _WaveProgressBarState extends State<WaveProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CustomPaint(
            size: Size(double.infinity, widget.height),
            painter: _WavePainter(
              progress: widget.progress,
              wavePhase: _controller.value * 2 * math.pi,
              color: widget.color,
            ),
          ),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final double progress;
  final double wavePhase;
  final Color color;

  _WavePainter({
    required this.progress,
    required this.wavePhase,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fillWidth = size.width * progress;
    final baseHeight = size.height - (size.height * progress);

    final waveHeight = 8.0;
    final waveLength = size.width / 1.5;

    // ✅ 1. 회색 테두리 먼저 그림
    final borderPaint = Paint()
      ..color = Colors.grey
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final borderRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );
    canvas.drawRRect(borderRect, borderPaint);

    // ✅ 2. 파도 물결 그림
    final paint1 = Paint()..color = color.withOpacity(0.6);
    final path1 = Path()..moveTo(0, size.height);

    for (double x = 0; x <= fillWidth; x++) {
      final y = baseHeight +
          waveHeight * math.sin((2 * math.pi / waveLength) * x + wavePhase);
      path1.lineTo(x, y);
    }
    path1.lineTo(fillWidth, size.height);
    path1.close();

    final paint2 = Paint()..color = color.withOpacity(0.3);
    final path2 = Path()..moveTo(0, size.height);

    for (double x = 0; x <= fillWidth; x++) {
      final y = baseHeight +
          waveHeight *
              0.6 *
              math.sin((2 * math.pi / waveLength) * x + wavePhase + math.pi / 2);
      path2.lineTo(x, y);
    }
    path2.lineTo(fillWidth, size.height);
    path2.close();

    canvas.drawPath(path1, paint1);
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) => true;
}
