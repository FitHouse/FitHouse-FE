// family_steps_widget.dart
import 'package:flutter/material.dart';
import 'package:fithouse/models/family_steps.dart';

class FamilyStepsWidget extends StatelessWidget {
  final List<FamilySteps> members;
  final String range; // 'today', 'week', 'month'
  final int goal;
  final int? myUserId;

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
        return m.week;
      case 'month':
        return m.month;
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
    final sorted = [...members]..sort((a, b) => _valueByRange(b).compareTo(_valueByRange(a)));

    return ListView.builder(
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final m = sorted[index];
        final steps = _valueByRange(m);
        final progress = goal > 0 ? (steps / goal).clamp(0.0, 1.0) : 0.0;
        final isMe = m.userId == myUserId;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          color: isMe ? Colors.green.withOpacity(0.1) : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.primaries[index % Colors.primaries.length],
              child: Text('${index + 1}'),
            ),
            title: Text(
              '${m.name}${isMe ? ' (나)' : ''}',
              style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.normal),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_labelByRange()} $steps 보'),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: progress,
                  color: Colors.primaries[index % Colors.primaries.length],
                  backgroundColor: Colors.grey[200],
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
