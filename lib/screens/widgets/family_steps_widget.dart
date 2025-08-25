// family_steps_widget.dart
import 'package:flutter/material.dart';
import 'package:fithouse/models/family_steps.dart';

class FamilyStepsWidget extends StatelessWidget {
  final List<FamilySteps> members;
  final String range; // 'today', 'week', 'month'
  final int goal;
  final int? myUserId;

  // ✅ 파스텔톤 색상 리스트
  final pastelColors = const [
    Color(0xFFB3E5FC), // 연한 하늘색
    Color(0xFFFFCDD2), // 연한 핑크
    Color(0xFFC8E6C9), // 연한 초록
    Color(0xFFFFF9C4), // 연한 노랑
    Color(0xFFD1C4E9), // 연한 보라
    Color(0xFFFFE0B2), // 연한 주황
    Color(0xFFDCEDC8), // 연한 연두
  ];

  const FamilyStepsWidget({
    super.key,
    required this.members,
    required this.range,
    required this.goal,
    this.myUserId,
  });

  int _valueByRange(FamilySteps m) {
    switch (range) {
      case 'week':
        return m.weekly;
      case 'month':
        return m.monthly;
      default:
        return m.today;
    }
  }

  String _labelByRange() {
    switch (range) {
      case 'week':
        return '주간';
      case 'month':
        return '월간';
      default:
        return '오늘';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const Center(child: Text('가족 데이터가 없습니다.'));
    }

    // 걸음수 기준 내림차순 정렬
    final sorted = [...members]
      ..sort((a, b) => _valueByRange(b).compareTo(_valueByRange(a)));

    return ListView.builder(
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final m = sorted[index];
        final steps = _valueByRange(m);
        final progress = goal > 0 ? (steps / goal).clamp(0.0, 1.0) : 0.0;
        final isMe = m.userId == myUserId;

        // ✅ 색상 가져오기 (index에 따라 파스텔톤 반복)
        final baseColor = pastelColors[index % pastelColors.length];

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          color: isMe ? const Color(0xfff4fced) : null,
          child: ListTile(
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: baseColor,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14, // ✅ 글씨 크기 살짝 키움
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
            ),
            title: Text(
              '${m.name}${isMe ? ' (나)' : ''}',
              style: TextStyle(
                fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_labelByRange()} $steps 보',
                    style: TextStyle(color: Colors.grey[800])),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LinearProgressIndicator(
                    value: progress,
                    color: baseColor,
                    backgroundColor: Colors.grey[200],
                    minHeight: 12, // 통통하게
                  ),
                ),
              ],
            ),
            trailing: Text('${(progress * 100).toStringAsFixed(0)}%'),
          ),
        );
      },
    );
  }
}
