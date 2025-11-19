// File: lib/screens/profile_screen.dart

import 'dart:convert';
import 'package:fithouse/screens/record/record_screen.dart';
import 'package:flutter/material.dart';
import 'package:fithouse/api/http_client.dart';
import 'package:fithouse/models/family_daily_record.dart';
import 'package:fithouse/main.dart';
import 'package:printing/printing.dart';
import 'package:fithouse/services/pdf_report_service.dart';
import 'package:fithouse/constants/colors.dart';

// 가족 / 내정보 화면
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with RouteAware {
  List<FamilyDailyRecord> _family = [];
  bool _loading = true;

  final Map<String, Color> _colorCache = {};
  int _colorIndex = 0;

  final pastelColors = const [
    Color(0xFFB3E5FC),
    Color(0xFFFFCDD2),
    Color(0xFFC8E6C9),
    Color(0xFFFFF9C4),
    Color(0xFFD1C4E9),
    Color(0xFFFFE0B2),
    Color(0xFFDCEDC8),
  ];

  final PdfReportService _pdfService = PdfReportService();

  @override
  void initState() {
    super.initState();
    _loadFamily();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadFamily();
  }

  String roleLabel(String role) {
    switch (role) {
      case 'GRANDMA': return '할머니';
      case 'GRANDPA': return '할아버지';
      case 'MOM': return '엄마';
      case 'DAD': return '아빠';
      case 'DAUGHTER': return '딸';
      case 'SON': return '아들';
      default: return role;
    }
  }

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
        setState(() {
          _family = [];
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _family = [];
        _loading = false;
      });
    }
  }

  Color _colorFor(String workoutName) {
    if (_colorCache.containsKey(workoutName)) {
      return _colorCache[workoutName]!;
    }
    final color = pastelColors[_colorIndex % pastelColors.length];
    _colorCache[workoutName] = color;
    _colorIndex++;
    return color;
  }

  Future<void> _exportFamilyReport() async {
    if (_family.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('내보낼 가족 기록 데이터가 없습니다.')));
      return;
    }

    final scaffold = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    scaffold.showSnackBar(const SnackBar(content: Text('PDF 리포트를 준비 중입니다...'), duration: Duration(seconds: 1)));

    try {
      final pdfData = await _pdfService.generateFamilyReport(_family);

      await Printing.sharePdf(
        bytes: pdfData,
        filename: 'FitHouse_Weekly_Report.pdf',
      );

    } catch (e) {
      scaffold.showSnackBar(
          SnackBar(content: Text('PDF 생성 중 오류 발생: $e')));
    }
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

    final me = _family.first;
    final others = _family.where((m) => m.userId != me.userId).toList();
    final Color primaryColor = Theme.of(context).primaryColor;


    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadFamily,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '우리 가족 (${_family.length}명)',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

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
                          // ⭐️ [확인] 나의 프로필: '내 기록' 버튼
                          TextButton.icon(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const RecordScreen()),
                              );
                              if (!mounted) return;
                              _loadFamily();
                            },
                            icon: const Icon(Icons.fitness_center),
                            label: const Text('내 기록'),
                            style: TextButton.styleFrom(
                              foregroundColor: primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(color: primaryColor),
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

            ...others.map(
                  (m) => _FamilyTile(
                member: m,
                roleText: roleLabel(m.role),
                colorFor: _colorFor,
              ),
            ),

            // ⭐️ PDF 버튼을 ListView의 맨 마지막에 배치
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: _exportFamilyReport,
                icon: const Icon(Icons.picture_as_pdf, color: Colors.black),
                label: const Text('가족 운동 리포트 PDF 다운로드 (분석 포함)', style: TextStyle(fontSize: 16, color: Colors.black)),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _NoFamilyView extends StatelessWidget {
  const _NoFamilyView();

  @override
  Widget build(BuildContext context) {
    final subColor =
    Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7);
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

class _FamilyTile extends StatelessWidget {
  final FamilyDailyRecord member;
  final String roleText;
  final Color Function(String) colorFor;

  const _FamilyTile({
    required this.member,
    required this.roleText,
    required this.colorFor,
  });

  @override
  Widget build(BuildContext context) {
    final total = member.totalMinutes;
    final theme = Theme.of(context);
    final primaryColor = Theme.of(context).primaryColor;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      // ⭐️ [수정] InkWell 제거: 카드 전체를 누르는 기능을 비활성화합니다.
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
                  Text(member.name, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(roleText, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 8),
                  _Legend(
                    segments: member.workoutMinutes.entries
                        .map((e) =>
                        RingSegment(e.key, e.value, colorFor(e.key)))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  // ⭐️ [확인] 가족 멤버: '기록 보기' 버튼만 이동 기능 수행
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RecordScreen(userId: member.userId),
                        ),
                      );
                    },
                    icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                    label: const Text('기록 보기'),
                    style: TextButton.styleFrom(
                      foregroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: primaryColor),
                      ),
                      padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
    );
  }
}

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
    final sorted = [...widget.segments]
      ..sort((a, b) => b.minutes.compareTo(a.minutes));
    final Color primaryColor = Theme.of(context).primaryColor;

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
                  width: 10,
                  height: 10,
                  decoration:
                  BoxDecoration(color: s.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Text('${s.label} ${s.minutes}분',
                    style: const TextStyle(fontSize: 12)),
              ],
            );
          }).toList(),
        ),

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
                      // 오류 해결: Colors.green.shade700 사용
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 16,
                    color: primaryColor,
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