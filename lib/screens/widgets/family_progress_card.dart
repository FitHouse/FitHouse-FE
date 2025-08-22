import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:fithouse/screens/widgets/level_info_popup.dart';
import 'wave_progress_bar.dart'; // WaveProgressBar 있는 파일 import

class FamilyProgressCard extends StatelessWidget {
  final double steppedWeeklyProgress;
  final String levelImage;
  final int weeklySteps;
  final int weeklyGoal;
  final int totalTodaySteps;
  final int todayGoalWithFamily;

  const FamilyProgressCard({
    super.key,
    required this.steppedWeeklyProgress,
    required this.levelImage,
    required this.weeklySteps,
    required this.weeklyGoal,
    required this.totalTodaySteps,
    required this.todayGoalWithFamily,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 상단 타이틀 + Info 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "주간 진행률",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline, size: 24),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const LevelInfoPopup(),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 원형 프로그레스 + 레벨 이미지
            SizedBox(
              height: 180,
              width: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 180,
                    width: 180,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: steppedWeeklyProgress),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return CustomPaint(
                          painter: GradientCirclePainter(progress: value),
                          child: Center(
                            child: SizedBox(
                              height: 140,
                              width: 140,
                              child: Image.asset(
                                levelImage,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    height: 140,
                    width: 140,
                    child: Image.asset(
                      levelImage,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 주간 합계 텍스트
            Text(
              "이번 주 $weeklySteps / $weeklyGoal 걸음",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            // 물결 프로그레스 바
            WaveProgressBar(
              progress: (totalTodaySteps / todayGoalWithFamily).clamp(0.0, 1.0),
              color: Colors.green,
              height: 20,
            ),
            const SizedBox(height: 4),

            // 오늘 합계 텍스트
            Text(
              "오늘 $totalTodaySteps / $todayGoalWithFamily 걸음",
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ✅ 기존 GradientCirclePainter도 같이 포함
class GradientCirclePainter extends CustomPainter {
  final double progress;

  GradientCirclePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 14.0;
    final rect = Offset.zero & size;

    final gradient = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: 1.5 * math.pi,
      colors: [
        Colors.green.shade300,
        Colors.green.shade500,
        Colors.green.shade700,
      ],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // 배경 원
    canvas.drawCircle(center, radius, bgPaint);

    // 진행률 원호
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant GradientCirclePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
