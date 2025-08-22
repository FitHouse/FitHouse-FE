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
      title: const Text(
        "레벨업 조건",
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "※ 주간 업데이트는 월요일 자정에 갱신됩니다.",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(levels.length, (index) {
            bool locked = index + 1 > 1; // 현재 레벨보다 높으면 ? 아이콘
            return ListTile(
              leading: Image.asset(
                locked ? 'assets/images/question.png' : levels[index]["img"]!,
                height: 40,
                width: 40,
                fit: BoxFit.contain,
              ),
              title: Text(
                levels[index]["text"]!,
                style: const TextStyle(fontSize: 15),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              dense: true,
            );
          }),
        ],
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
