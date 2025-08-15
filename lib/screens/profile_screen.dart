import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fithouse/api/http_client.dart';
import 'package:fithouse/models/family_daily_record.dart';

// API 연동 버전
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  static const int dailyGoalMinutes = 60;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<FamilyDailyRecord> _family = [];
  bool _loading = true;

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

  @override
  void initState() {
    super.initState();
    _loadFamily();
  }

  Future<void> _loadFamily() async {
    try {
      final uri = Uri.parse('$baseUrl/family/daily-records');
      final res = await httpClient.get(uri, headers: await authHeaders());
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        setState(() {
          _family =
              data.map((e) => FamilyDailyRecord.fromJson(e)).toList();
          _loading = false;
        });
      } else {
        throw Exception('가족 기록 불러오기 실패');
      }
    } catch (e) {
      debugPrint('Error: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_family.isEmpty) {
      return const Scaffold(body: Center(child: Text('데이터 없음')));
    }

    final me = _family.first;
    final others = _family.where((m) => m.userId != me.userId).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('가족 / 내정보')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '우리 가족 (${_family.length}명)',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // 내 프로필 카드
          Card(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  RingAvatar(
                    segments: me.workoutMinutes.entries
                        .map((e) => RingSegment(e.key, e.value, _colorFor(e.key)))
                        .toList(),
                    goalMinutes: ProfileScreen.dailyGoalMinutes,
                    imageUrl: me.profileImageUrl != null
                        ? '$assetBaseUrl${me.profileImageUrl}'
                        : null,
                    size: 120,
                    stroke: 12,
                    border: const BorderSide(color: Color(0x11000000)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(me.name, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(roleLabel(me.role),
                            style: theme.textTheme.bodySmall),
                        const SizedBox(height: 8),
                        _Legend(
                          segments: me.workoutMinutes.entries
                              .map((e) => RingSegment(
                              e.key, e.value, _colorFor(e.key)))
                              .toList(),
                        ),
                        const SizedBox(height: 8),
                        Text('${me.totalMinutes}분',
                            style: const TextStyle(fontSize: 12)),
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
              goalMinutes: ProfileScreen.dailyGoalMinutes,
              roleText: roleLabel(m.role),
            ),
          ),
        ],
      ),
    );
  }

  Color _colorFor(String workoutName) {
    final colors = [
      Colors.blue,
      Colors.teal,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.green,
      Colors.indigo,
    ];
    return colors[workoutName.hashCode % colors.length];
  }
}

class _FamilyTile extends StatelessWidget {
  final FamilyDailyRecord member;
  final int goalMinutes;
  final String roleText;

  const _FamilyTile({
    required this.member,
    required this.goalMinutes,
    required this.roleText,
  });

  @override
  Widget build(BuildContext context) {
    final total = member.totalMinutes;

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
                segments: member.workoutMinutes.entries
                    .map((e) => RingSegment(e.key, e.value, _colorFor(e.key)))
                    .toList(),
                goalMinutes: goalMinutes,
                imageUrl: member.profileImageUrl != null
                    ? '$assetBaseUrl${member.profileImageUrl}'
                    : null,
                size: 96,
                stroke: 10,
                border: const BorderSide(color: Color(0x11000000)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.name,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(roleText, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 8),
                    _Legend(
                      segments: member.workoutMinutes.entries
                          .map((e) =>
                          RingSegment(e.key, e.value, _colorFor(e.key)))
                          .toList(),
                    ),
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

  Color _colorFor(String workoutName) {
    final colors = [
      Colors.blue,
      Colors.teal,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.green,
      Colors.indigo,
    ];
    return colors[workoutName.hashCode % colors.length];
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
        child:
        centerBuilder == null ? null : Center(child: centerBuilder!(context)),
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
