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

  final int selectedWeek;
  final Function(int) onWeekChange;

  final DateTime? from;
  final DateTime? to;

  const FamilyProgressCard({
    super.key,
    required this.steppedWeeklyProgress,
    required this.levelImage,
    required this.weeklySteps,
    required this.weeklyGoal,
    required this.totalTodaySteps,
    required this.todayGoalWithFamily,

    required this.selectedWeek,
    required this.onWeekChange,

    this.from,
    this.to,
  });

  String weekLabel(int week) {
    if (week == 0) return "이번 주";
    if (week == 1) return "지난 주";
    return "${week}주 전";
  }

  String formatDate(DateTime d) {
    return "${d.year}.${d.month.toString().padLeft(2,'0')}.${d.day.toString().padLeft(2,'0')}";
  }


  @override
  Widget build(BuildContext context) {

    String range = "";
    if (from != null && to != null) {
      range = "(${formatDate(from!)} ~ ${formatDate(to!)})";
    }

    final bool isSuccess = weeklySteps >= weeklyGoal;
    final bool showOverlay = selectedWeek != 0;

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

                Row(
                  children: [
                    DropdownButton<int>(
                      value: selectedWeek,
                      underline: SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text("이번 주")),
                        DropdownMenuItem(value: 1, child: Text("지난 주")),
                        DropdownMenuItem(value: 2, child: Text("2주 전")),
                      ],
                      onChanged: (v) {
                        if (v != null) onWeekChange(v);
                      },
                    ),

                    IconButton(
                      icon: const Icon(Icons.info_outline),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => const LevelInfoPopup(),
                      ),
                    ),
                  ],
                )
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
                  // 1) PROGRESS PAINTER (맨 뒤)
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
                        );
                      },
                    ),
                  ),

                  // 2) LEVEL IMAGE (중간 레이어)
                  SizedBox(
                    height: 140,
                    width: 140,
                    child: Image.asset(
                      levelImage,
                      fit: BoxFit.contain,
                    ),
                  ),

                  // 3) TEXT (맨 위 → 이미지 위를 덮어버림)
                  if (selectedWeek != 0)
                    Positioned.fill(
                      child: Center(
                        child: Text(
                          isSuccess
                              ? "🎉 목표 달성!\n너무 잘했어요!"
                              : "🌧️ 목표 달성 실패..\n우리 더 힘내볼까요?",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.3,
                            shadows: [
                              Shadow(
                                blurRadius: 8,
                                color: Colors.black.withOpacity(0.6),
                                offset: Offset(1, 1),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),


            const SizedBox(height: 8),


            // 주간 합계 텍스트
            selectedWeek == 0
                ? Text(
              "${weekLabel(selectedWeek)} $weeklySteps / $weeklyGoal 걸음",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            )
                : Column(
              children: [
                Text(
                  "${weekLabel(selectedWeek)} $range",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                // 여기부터 전체 교체된 부분
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87, // 기본색
                    ),
                    children: [
                      TextSpan(
                        text: "$weeklySteps",     // 성공/실패 색 적용되는 숫자
                        style: TextStyle(
                          color: isSuccess
                              ? Colors.green[700]    // 성공: 초록색
                              : Colors.redAccent,    // 실패: 빨간색
                        ),
                      ),
                      TextSpan(
                        text: " / $weeklyGoal 걸음",  // 🔥 나머지는 기본색
                        style: const TextStyle(
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),


            const SizedBox(height: 12),

            if (selectedWeek == 0) ...[
              WaveProgressBar(
                progress: (totalTodaySteps / todayGoalWithFamily).clamp(0.0, 1.0),
                color: Colors.green,
                height: 20,
              ),
              const SizedBox(height: 4),

              Text(
                "오늘 $totalTodaySteps / $todayGoalWithFamily 걸음",
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
