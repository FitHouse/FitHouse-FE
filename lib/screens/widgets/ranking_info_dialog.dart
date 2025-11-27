import 'package:flutter/material.dart';

class RankingInfoDialog extends StatelessWidget {
  const RankingInfoDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "랭킹 업데이트 안내",
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 18),

            // ------------------ 일간 랭킹 ------------------
            const Text(
              "📅 일간 랭킹",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              "• 매일 00:00에 ‘전날 걸음 수’를 기준으로 랭킹이 생성됩니다.\n"
                  "• 오늘 걸음 수는 일간 랭킹에 반영되지 않습니다.\n"
                  "• 어제의 데이터가 고정으로 보여집니다.",
              style: TextStyle(fontSize: 14, height: 1.45),
            ),

            const SizedBox(height: 22),

            // ------------------ 주간 랭킹 ------------------
            const Text(
              "📆 주간 랭킹",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              "• 매주 일요일 기준으로 지난주(월요일~일요일)의 데이터를 계산합니다.\n"
                  "• 이번 주의 걸음 수는 주간 랭킹에 반영되지 않습니다.\n"
                  "• 지난주의 누적 걸음 데이터가 고정으로 표시됩니다.",
              style: TextStyle(fontSize: 14, height: 1.45),
            ),

            const SizedBox(height: 28),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "확인",
                  style: TextStyle(fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
