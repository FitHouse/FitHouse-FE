import 'dart:convert';
import 'package:fithouse/screens/record_screen.dart'; // RecordScreen import
import 'package:flutter/material.dart';
import 'package:fithouse/api/http_client.dart'; // API 클라이언트 import
import 'package:fithouse/models/family_daily_record.dart'; // 모델 import

// 가족 / 내정보 화면
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  static const int dailyGoalMinutes = 60; // 일일 목표 운동 시간 (분)

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with RouteAware {
  List<FamilyDailyRecord> _family = []; // 가족 일일 기록 리스트
  bool _loading = true; // 데이터 로딩 중인지 여부

  // 색상 캐시: 운동 유형별 색상 저장
  final Map<String, Color> _colorCache = {};
  int _colorIndex = 0;

  // 파스텔톤 색상 리스트
  final pastelColors = const [
    Color(0xFFB3E5FC), // 연한 하늘색
    Color(0xFFFFCDD2), // 연한 핑크
    Color(0xFFC8E6C9), // 연한 초록
    Color(0xFFFFF9C4), // 연한 노랑
    Color(0xFFD1C4E9), // 연한 보라
    Color(0xFFFFE0B2), // 연한 주황
    Color(0xFFDCEDC8), // 연한 연두
  ];

  @override
  void initState() {
    super.initState();
    _loadFamily(); // 화면 초기화 시 가족 데이터 로드
  }

  // 다른 화면에서 돌아올 때 데이터 새로고침
  @override
  void didPopNext() {
    _loadFamily();
  }

  // 역할(role)을 한글 라벨로 변환
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

  // 가족 일일 기록 데이터를 불러오는 비동기 함수
  Future<void> _loadFamily() async {
    setState(() => _loading = true);
    try {
      final uri = Uri.parse('$baseUrl/family/daily-records');
      final res = await httpClient.get(uri, headers: await authHeaders());

      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        setState(() {
          _family = data.map((e) => FamilyDailyRecord.fromJson(e)).toList();
          _loading = false;
        });
      } else {
        // 가족 없음(404)이나 서버에러(500)도 같은 빈 상태로 처리
        setState(() {
          _family = [];     // <- 빈 리스트로 전환
          _loading = false; // <- 로딩 종료
        });
      }
    } catch (e) {
      setState(() {
        _family = [];      // <- 빈 리스트로 전환
        _loading = false;  // <- 로딩 종료
      });
    }
  }

  // 운동 이름에 해당하는 색상 반환 (캐시 사용)
  Color _colorFor(String workoutName) {
    if (_colorCache.containsKey(workoutName)) {
      return _colorCache[workoutName]!;
    }
    final color = pastelColors[_colorIndex % pastelColors.length];
    _colorCache[workoutName] = color;
    _colorIndex++;
    return color;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_family.isEmpty) {
      return Scaffold(
        body: RefreshIndicator(
          onRefresh: _loadFamily,
          child: ListView(
            children: const [
              SizedBox(height: 120),
              _NoFamilyView(),
            ],
          ),
        ),
      );
    }

    final me = _family.first; // 첫 번째 멤버를 본인으로 간주
    final others = _family.where((m) => m.userId != me.userId).toList(); // 본인 제외한 나머지 가족

    return Scaffold(
      //appBar: AppBar(title: const Text('가족 / 내정보')),
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
                        .map((e) =>
                        RingSegment(e.key, e.value, _colorFor(e.key)))
                        .toList(),
                    goalMinutes: me.totalMinutes > 0 ? me.totalMinutes : 1,
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
                              .map((e) =>
                              RingSegment(e.key, e.value, _colorFor(e.key)))
                              .toList(),
                        ),
                        const SizedBox(height: 8),
                        Text('${me.totalMinutes}분',
                            style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 12),
                        // "내 기록" 버튼 (강조된 스타일)
                        TextButton.icon(
                          onPressed: () async {
                            // 본인 기록이므로 userId를 전달하지 않습니다 (RecordScreen에서 기본값 사용).
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const RecordScreen()),
                            );
                            if (!mounted) return;
                            _loadFamily();
                          },
                          icon: const Icon(Icons.fitness_center), // 피트니스 아이콘
                          label: const Text('내 기록'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.green, // 테마의 기본 색상 사용
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20), // 더 둥근 모서리
                              side: BorderSide(color: Colors.green), // 연한 테두리
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
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
              colorFor: _colorFor,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoFamilyView extends StatelessWidget {
  const _NoFamilyView();

  @override
  Widget build(BuildContext context) {
    final subColor = Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7);
    return Center(
      child: Column(
        children: [
          const Icon(Icons.group_off_outlined, size: 56, color: Colors.black38),
          const SizedBox(height: 10),
          const Text(
            '소속된 가족이 없습니다.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            '가족 그룹을 생성하거나 초대 코드를 입력해 참여해 주세요.',
            style: TextStyle(fontSize: 13, color: subColor),
          ),
        ],
      ),
    );
  }
}


// 가족 구성원 타일 위젯
class _FamilyTile extends StatelessWidget {
  final FamilyDailyRecord member;
  final int goalMinutes;
  final String roleText;
  final Color Function(String) colorFor;

  const _FamilyTile({
    required this.member,
    required this.goalMinutes,
    required this.roleText,
    required this.colorFor,
  });

  @override
  Widget build(BuildContext context) {
    final total = member.totalMinutes;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          // 가족 구성원 프로필 클릭 시 해당 멤버의 기록 화면으로 이동
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RecordScreen(userId: member.userId), // 멤버의 userId를 전달
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              RingAvatar(
                segments: member.workoutMinutes.entries
                    .map((e) => RingSegment(e.key, e.value, colorFor(e.key)))
                    .toList(),
                goalMinutes: member.totalMinutes > 0 ? member.totalMinutes : 1,
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
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(roleText,
                        style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    _Legend(
                      segments: member.workoutMinutes.entries
                          .map((e) =>
                          RingSegment(e.key, e.value, colorFor(e.key)))
                          .toList(),
                    ),
                    const SizedBox(height: 8), // 새 버튼을 위한 공간
                    // "기록 보기" 버튼 (가족 구성원용)
                    TextButton.icon(
                      onPressed: () {
                        // "기록 보기" 버튼 클릭 시 해당 멤버의 기록 화면으로 이동
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecordScreen(userId: member.userId), // 멤버의 userId를 전달
                          ),
                        );
                      },
                      icon: const Icon(Icons.remove_red_eye_outlined, size: 18), // 눈 아이콘
                      label: const Text('기록 보기'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.green, // 보조 색상 사용
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.green),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
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
}

// 범례 위젯
class _Legend extends StatefulWidget {
  final List<RingSegment> segments;
  const _Legend({required this.segments});

  @override
  State<_Legend> createState() => _LegendState();
}

class _LegendState extends State<_Legend> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // 내림차순 정렬(많이 한 운동 먼저)
    final sorted = [...widget.segments]
      ..sort((a, b) => b.minutes.compareTo(a.minutes));

    // 접기 상태에서는 2개만
    final visible = _expanded ? sorted : sorted.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: visible.map((s) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Text('${s.label} ${s.minutes}분',
                    style: const TextStyle(fontSize: 12)),
              ],
            );
          }).toList(),
        ),

        // 항목이 2개 초과일 때만 토글 표시
        if (sorted.length > 2) ...[
          const SizedBox(height: 6),
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _expanded ? '접기' : '더보기',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 16, color: Colors.green,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// 링 세그먼트 데이터 모델
class RingSegment {
  final String label;
  final int minutes;
  final Color color;
  const RingSegment(this.label, this.minutes, this.color);
}

// 링 아바타 위젯 (프로필 이미지와 운동 진행률 링)
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
            : const _AvatarFallback(), // 이미지 없을 때 폴백
      ),
    );
  }
}

// 아바타 폴백 위젯 (이미지 없을 때 표시)
class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback();
  @override
  Widget build(BuildContext context) =>
      const Center(child: Icon(Icons.person, size: 36));
}

// 링 진행률 위젯 (다중 세그먼트)
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
    this.backgroundColor = const Color(0xFFDADCE0), // 배경 색상
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

// 다중 세그먼트 링을 그리는 커스텀 페인터
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

    // 배경 링 그리기
    paint.color = background;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _deg(-90), // 시작 각도 (상단)
      _deg(360), // 전체 원
      false,
      paint,
    );

    // 각 운동 세그먼트 그리기
    double startAngle = _deg(-90);
    for (final s in segments) {
      final part = s.minutes.clamp(0, goalMinutes);
      if (part <= 0) continue;

      final sweep = (part / goalMinutes) * 360; // 각도 계산
      if (sweep <= 0) continue;

      paint.color = s.color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        _deg(sweep),
        false,
        paint,
      );
      startAngle += _deg(sweep); // 다음 세그먼트의 시작 각도 업데이트
    }
  }

  @override
  bool shouldRepaint(covariant _MultiSegmentRingPainter old) =>
      old.segments != segments ||
          old.goalMinutes != goalMinutes ||
          old.strokeWidth != strokeWidth ||
          old.background != background;

  // 각도를 라디안으로 변환하는 헬퍼 함수
  double _deg(double d) => d * 3.1415926535897932 / 180.0;
}