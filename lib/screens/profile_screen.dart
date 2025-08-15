import 'package:flutter/material.dart';

// 프로필 화면 UI
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const int dailyGoalMinutes = 60;

  String roleLabel(String role) {
    switch (role) {
      case 'GRANDMA':
        return '할머니';
      case 'GRANDPA':
        return '할아버지';
      case 'MOM':
        return '엄마';
      case 'DAD':
        return '아빠';
      case 'DAUGHTER':
        return '딸';
      case 'SON':
        return '아들';
      default:
        return role;
    }
  }

  final String familyName = '행복한가족';

  final _Member _me = const _Member(
    userId: 1,
    name: '김하늘',
    role: 'MOM',
    imageUrl: null,
    segments: [
      RingSegment('걷기', 25, Colors.blue),
      RingSegment('요가', 10, Colors.teal),
    ],
  );

  final List<_Member> _family = const [
    _Member(
      userId: 1,
      name: '김하늘',
      role: 'MOM',
      imageUrl: null,
      segments: [
        RingSegment('걷기', 25, Colors.blue),
        RingSegment('요가', 10, Colors.teal),
      ],
    ),
    _Member(
      userId: 2,
      name: '박민수',
      role: 'DAD',
      imageUrl: null,
      segments: [
        RingSegment('자전거', 25, Colors.orange),
        RingSegment('근력', 15, Colors.purple),
      ],
    ),
    _Member(
      userId: 3,
      name: '박소윤',
      role: 'DAUGHTER',
      imageUrl: null,
      segments: [RingSegment('줄넘기', 30, Colors.red)],
    ),
    _Member(
      userId: 4,
      name: '박도윤',
      role: 'SON',
      imageUrl: null,
      segments: [
        RingSegment('축구', 40, Colors.green),
        RingSegment('스트레칭', 5, Colors.indigo),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final others = _family.where((m) => m.userId != _me.userId).toList();
    final myTotal = _me.segments.fold<int>(0, (s, e) => s + e.minutes);

    return Scaffold(
      appBar: AppBar(title: const Text('가족 / 내정보')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '$familyName (${_family.length}명)',
            style:
            theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // 내 프로필 카드 (운동명+시간 표시 + 총 시간 추가)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  RingAvatar(
                    segments: _me.segments,
                    goalMinutes: dailyGoalMinutes,
                    imageUrl: _me.imageUrl,
                    size: 120,
                    stroke: 12,
                    border: const BorderSide(color: Color(0x11000000)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_me.name, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(roleLabel(_me.role), style: theme.textTheme.bodySmall),
                        const SizedBox(height: 8),
                        _Legend(segments: _me.segments),
                        const SizedBox(height: 8),
                        Text('$myTotal분', style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () {},
                          child: const Text('내 기록'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          Text('오늘 가족 운동 현황', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),

          // 가족 리스트 (본인 제외)
          ...others.map(
                (m) => _FamilyTile(
              member: m,
              goalMinutes: dailyGoalMinutes,
              roleText: roleLabel(m.role),
            ),
          ),
        ],
      ),
    );
  }
}

class _FamilyTile extends StatelessWidget {
  final _Member member;
  final int goalMinutes;
  final String roleText;

  const _FamilyTile({
    required this.member,
    required this.goalMinutes,
    required this.roleText,
  });

  @override
  Widget build(BuildContext context) {
    final total = member.segments.fold<int>(0, (s, e) => s + e.minutes);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              RingAvatar(
                segments: member.segments,
                goalMinutes: goalMinutes,
                imageUrl: member.imageUrl,
                size: 96,
                stroke: 10,
                border: const BorderSide(color: Color(0x11000000)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(roleText, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 8),
                    _Legend(segments: member.segments),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text('$total분', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final List<RingSegment> segments;
  const _Legend({required this.segments});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: -6,
      children: segments
          .map(
            (s) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration:
              BoxDecoration(color: s.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text('${s.label} ${s.minutes}분',
                style: const TextStyle(fontSize: 12)),
          ],
        ),
      )
          .toList(),
    );
  }
}

class RingSegment {
  final String label;
  final int minutes;
  final Color color;
  const RingSegment(this.label, this.minutes, this.color);
}

class RingAvatar extends StatelessWidget {
  final List<RingSegment> segments;
  final int goalMinutes;
  final String? imageUrl;
  final double size;
  final double stroke;
  final BorderSide? border;

  const RingAvatar({
    super.key,
    required this.segments,
    required this.goalMinutes,
    this.imageUrl,
    this.size = 110,
    this.stroke = 12,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final inner = size - (stroke * 2.4);
    return RingProgress(
      segments: segments,
      goalMinutes: goalMinutes,
      size: size,
      stroke: stroke,
      centerBuilder: (_) => Container(
        width: inner,
        height: inner,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: border == null ? null : Border.fromBorderSide(border!),
        ),
        clipBehavior: Clip.antiAlias,
        child: imageUrl != null && imageUrl!.trim().isNotEmpty
            ? Image.network(imageUrl!, fit: BoxFit.cover)
            : const _AvatarFallback(),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback();
  @override
  Widget build(BuildContext context) =>
      const Center(child: Icon(Icons.person, size: 36));
}

class RingProgress extends StatelessWidget {
  final List<RingSegment> segments;
  final int goalMinutes;
  final double size;
  final double stroke;
  final WidgetBuilder? centerBuilder;
  final Color backgroundColor;

  const RingProgress({
    super.key,
    required this.segments,
    required this.goalMinutes,
    this.size = 90,
    this.stroke = 10,
    this.centerBuilder,
    this.backgroundColor = const Color(0xFFDADCE0),
  });

  @override
  Widget build(BuildContext context) {
    final maxForDraw = goalMinutes > 0 ? goalMinutes : 1;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MultiSegmentRingPainter(
          segments: segments,
          goalMinutes: maxForDraw,
          strokeWidth: stroke,
          background: backgroundColor,
        ),
        child: centerBuilder == null ? null : Center(child: centerBuilder!(context)),
      ),
    );
  }
}

class _MultiSegmentRingPainter extends CustomPainter {
  final List<RingSegment> segments;
  final int goalMinutes;
  final double strokeWidth;
  final Color background;

  _MultiSegmentRingPainter({
    required this.segments,
    required this.goalMinutes,
    required this.strokeWidth,
    required this.background,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    paint.color = background;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _deg(-90),
      _deg(360),
      false,
      paint,
    );

    double startAngle = _deg(-90);
    for (final s in segments) {
      final part = s.minutes.clamp(0, goalMinutes);
      if (part <= 0) continue;

      final sweep = (part / goalMinutes) * 360;
      if (sweep <= 0) continue;

      paint.color = s.color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        _deg(sweep),
        false,
        paint,
      );
      startAngle += _deg(sweep);
    }
  }

  @override
  bool shouldRepaint(covariant _MultiSegmentRingPainter old) =>
      old.segments != segments ||
          old.goalMinutes != goalMinutes ||
          old.strokeWidth != strokeWidth ||
          old.background != background;

  double _deg(double d) => d * 3.1415926535897932 / 180.0;
}

class _Member {
  final int userId;
  final String name;
  final String role;
  final String? imageUrl;
  final List<RingSegment> segments;
  const _Member({
    required this.userId,
    required this.name,
    required this.role,
    this.imageUrl,
    required this.segments,
  });
}
