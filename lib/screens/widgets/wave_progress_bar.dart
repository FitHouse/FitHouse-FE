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
    final paint = Paint()..color = color.withOpacity(0.7);

    final waveHeight = 6.0;
    final baseHeight = size.height * (1 - progress);

    final path = Path()..moveTo(0, size.height);

    for (double x = 0; x <= size.width; x++) {
      final y = waveHeight *
          math.sin((2 * math.pi / size.width) * x + wavePhase) +
          baseHeight;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) => true;
}
