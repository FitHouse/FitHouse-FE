import 'package:flutter/material.dart';

class LevelInfoPopup extends StatelessWidget {
  const LevelInfoPopup({super.key});

  @override
  Widget build(BuildContext context) {
    final levels = [
      {"img": "assets/images/level1.png", "text": "주간 목표 누적 0~2회 달성"},
      {"img": "assets/images/level2.png", "text": "주간 목표 누적 3회 달성"},
      {"img": "assets/images/level3.png", "text": "주간 목표 누적 4회 달성"},
      {"img": "assets/images/level4.png", "text": "주간 목표 누적 5회 이상 달성"},
    ];

    return AlertDialog(
      title: const Text("레벨업 조건"),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: levels.length,
          itemBuilder: (context, index) {
            return Row(
              children: [
                Image.asset(
                  index + 1 > 1 // 현재 레벨보다 높으면 ? 이미지 처리 가능
                      ? 'assets/images/question.png'
                      : levels[index]["img"]!,
                  height: 60,
                ),
                const SizedBox(width: 8),
                Text(levels[index]["text"]!),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          child: const Text("닫기"),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
