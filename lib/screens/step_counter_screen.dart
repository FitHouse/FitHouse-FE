import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fithouse/models/family_steps.dart';
import 'package:fithouse/screens/widgets/family_steps_widget.dart';
import 'package:fithouse/screens/widgets/level_info_popup.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class WaveProgressBar extends StatefulWidget {
  final double progress; // 0.0 ~ 1.0
  final Color color;
  final double height;

  const WaveProgressBar({
    super.key,
    required this.progress,
    this.color = Colors.blue,
    this.height = 20,
  });

  @override
  State<WaveProgressBar> createState() => _WaveProgressBarState();
}

class _WaveProgressBarState extends State<WaveProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CustomPaint(
            size: Size(double.infinity, widget.height),
            painter: _WavePainter(
              progress: widget.progress,
              wavePhase: _controller.value * 2 * math.pi,
              color: widget.color,
            ),
          ),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final double progress;
  final double wavePhase;
  final Color color;

  _WavePainter({
    required this.progress,
    required this.wavePhase,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fillWidth = size.width * progress;
    final baseHeight = size.height - (size.height * progress);

    // ✅ 첫 번째 물결
    final paint1 = Paint()..color = color.withOpacity(0.6);
    final path1 = Path()..moveTo(0, size.height);

    final waveHeight = 8.0; // 진폭
    final waveLength = size.width / 1.5; // 파장

    for (double x = 0; x <= fillWidth; x++) {
      final y = baseHeight +
          waveHeight * math.sin((2 * math.pi / waveLength) * x + wavePhase);
      path1.lineTo(x, y);
    }
    path1.lineTo(fillWidth, size.height);
    path1.close();

    // ✅ 두 번째 물결 (phase + π/2)
    final paint2 = Paint()..color = color.withOpacity(0.3);
    final path2 = Path()..moveTo(0, size.height);

    for (double x = 0; x <= fillWidth; x++) {
      final y = baseHeight +
          waveHeight *
              0.6 * // 두 번째는 살짝 작게
              math.sin((2 * math.pi / waveLength) * x + wavePhase + math.pi / 2);
      path2.lineTo(x, y);
    }
    path2.lineTo(fillWidth, size.height);
    path2.close();

    canvas.drawPath(path1, paint1);
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) => true;
}

class GradientCirclePainter extends CustomPainter {
  final double progress;

  GradientCirclePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 14.0;
    final rect = Offset.zero & size;

    // ✅ 초록 계열 gradient
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

    // 주간 누적 진행률
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(covariant GradientCirclePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

const String kBaseUrl = 'http://marketalert.iptime.org:8080';

class StepCounterRepo {
  final String baseUrl;
  final http.Client _client;
  StepCounterRepo({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();


  Future<Map<String, String>> _authHeaders({bool forceRefresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('로그인이 필요합니다.');
    final idToken = await user.getIdToken(forceRefresh);
    return {
      'Authorization': 'Bearer $idToken',
      'Accept': 'application/json',
    };
  }

  Future<List<FamilySteps>> fetchFamilySteps(int familyId,
      {String range = 'today'}) async {
    final uri = Uri.parse('$baseUrl/api/families/$familyId/steps/summary')
        .replace(queryParameters: {'range': range});
    final res = await _client.get(uri, headers: await _authHeaders());
    if (res.statusCode != 200) {
      throw Exception('/families steps summary ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body);
    if (data is Map && data['members'] is List) {
      return (data['members'] as List)
          .map((e) => FamilySteps.fromJson(e))
          .toList();
    }
    return [];
  }

  Future<Map<String, String>> authHeaders() => _authHeaders();
}

class FamilyMember {
  final int id;
  final String name;
  final String? avatarUrl;
  const FamilyMember({required this.id, required this.name, this.avatarUrl});

  factory FamilyMember.fromJson(Map<String, dynamic> j) => FamilyMember(
    id: j['id'] as int,
    name: j['name'] as String,
    avatarUrl: j['profileImageUrl'] as String?,
  );
}

class FamilySummary {
  final int familyId;
  final String familyName;
  final List<FamilyMember> members;
  const FamilySummary({
    required this.familyId,
    required this.familyName,
    required this.members,
  });

  factory FamilySummary.fromJson(Map<String, dynamic> j) => FamilySummary(
    familyId: j['familyId'] as int,
    familyName: j['familyName'] as String,
    members: (j['members'] as List)
        .map((e) => FamilyMember.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class CommunityRepo {
  final String baseUrl;
  final http.Client _client;
  CommunityRepo({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  Future<Map<String, String>> _authHeaders({bool forceRefresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }
    final idToken = await user.getIdToken(forceRefresh);
    return {
      'Authorization': 'Bearer $idToken',
      'Accept': 'application/json',
    };
  }

  Future<FamilySummary> fetchFamilySummary() async {
    final uri = Uri.parse('$baseUrl/api/community/family');
    final res = await _client.get(uri, headers: await _authHeaders());
    if (res.statusCode != 200) {
      throw Exception('summary ${res.statusCode}: ${res.body}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return FamilySummary.fromJson(json);
  }
}

class StepCounterScreen extends StatefulWidget {
  const StepCounterScreen({super.key});

  @override
  State<StepCounterScreen> createState() => _StepCounterScreenState();
}

class _StepCounterScreenState extends State<StepCounterScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  late final StepCounterRepo _repo = StepCounterRepo(baseUrl: kBaseUrl);
  late final CommunityRepo _communityRepo = CommunityRepo(baseUrl: kBaseUrl);

  int? _myUserId;
  int? _myFamilyId;
  int _myGoal = 10000;
  int todaySteps = 0;
  String range = 'today';
  List<FamilySteps> _family = [];

  static const _eventChannel = EventChannel('step_counter/events');
  StreamSubscription? _sub;
  Timer? _tick;
  Timer? _midnightTimer; // ✅ 자정 새로고침 타이머
  int _sensorStepsNow = 0;

  int _startServerSteps = 0;
  int _startSensorSteps = 0;

  static const int _stepChangeThreshold = 10;
  static const Duration _minSendInterval = Duration(minutes: 1);
  DateTime _lastSendTime = DateTime.fromMillisecondsSinceEpoch(0);
  int _lastSent = -1;

  bool _hasFlushedThisCycle = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _loadAll().then((_) {
      _startSensorListening();
      _startAutoTick();
      _scheduleMidnightRefresh(); // ✅ 자정 새로고침 예약
    });
  }

  @override
  void dispose() {
    if (!_hasFlushedThisCycle) {
      debugPrint("📌 화면 dispose → 서버 저장");
      _flush(sync: true);
      _hasFlushedThisCycle = true;
    }
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _sub?.cancel();
    _midnightTimer?.cancel(); // ✅ 타이머 정리
    super.dispose();
  }

  // ✅ 자정 새로고침 예약 함수
  void _scheduleMidnightRefresh() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final duration = tomorrow.difference(now);

    _midnightTimer?.cancel(); // 중복 예약 방지
    _midnightTimer = Timer(duration, () async {
      debugPrint("🌙 자정 도달 → 주간 데이터 새로고침");
      await _fetchSteps(); // 주간 합계 최신화
      _scheduleMidnightRefresh(); // 다음 자정도 예약
    });
  }

  Future<void> _loadAll() async {
    try {
      final summary = await _communityRepo.fetchFamilySummary();
      _myFamilyId = summary.familyId;
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final me = summary.members.firstWhere(
              (m) => m.name == currentUser.displayName,
          orElse: () => summary.members.first,
        );
        _myUserId = me.id;
      }
      await _fetchSteps();
    } catch (e) {
      debugPrint("❌ 초기 데이터 불러오기 실패: $e");
    }
  }

  Future<void> _fetchSteps() async {
    if (_myFamilyId == null) return;
    try {
      final familySteps =
      await _repo.fetchFamilySteps(_myFamilyId!, range: range);

      final me = familySteps.firstWhere(
            (f) => f.userId == _myUserId,
        orElse: () => familySteps.first,
      );

      _startServerSteps = me.today;

      setState(() {
        _family = familySteps;
      });

      if (_sensorStepsNow > 0 && _startSensorSteps > 0) {
        final adjusted = _startServerSteps +
            (_sensorStepsNow - _startSensorSteps).clamp(0, 999999);
        setState(() {
          todaySteps = adjusted;
          final idx = _family.indexWhere((f) => f.userId == _myUserId);
          if (idx != -1) {
            _family[idx] = _family[idx].copyWith(today: todaySteps);
          }
        });
        _flush(sync: true);
      } else {
        setState(() {
          todaySteps = _startServerSteps;
        });
      }
    } catch (e) {
      debugPrint("❌ 걸음 수 불러오기 실패: $e");
    }
  }

  void _startSensorListening() {
    _sub = _eventChannel.receiveBroadcastStream().listen((event) {
      final sensorNow = (event as num).toInt();

      if (_startSensorSteps == 0) {
        _startSensorSteps = sensorNow;
      }

      _sensorStepsNow = sensorNow;

      final adjusted = _startServerSteps +
          (sensorNow - _startSensorSteps).clamp(0, 999999);

      setState(() {
        todaySteps = adjusted;
        final idx = _family.indexWhere((f) => f.userId == _myUserId);
        if (idx != -1) {
          _family[idx] = _family[idx].copyWith(today: todaySteps);
        }
      });
    });
  }

  void _startAutoTick() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) => _flush());
  }

  Future<void> _flush({bool sync = false}) async {
    if (_myUserId == null) return;

    final adjustedSteps = _startServerSteps +
        (_sensorStepsNow - _startSensorSteps).clamp(0, 999999);

    // 변동 없으면 전송 안 함
    if (adjustedSteps == _lastSent) {
      debugPrint("⏩ 변동 없음, 전송 안 함 (steps=$adjustedSteps)");
      return;
    }

    final now = DateTime.now();
    if (!sync) {
      if (now.difference(_lastSendTime) < _minSendInterval) return;
      if ((adjustedSteps - _lastSent).abs() < _stepChangeThreshold) return;
    }

    try {
      final headers = await _repo.authHeaders();
      final body = jsonEncode({
        'steps': adjustedSteps,
        'clientAt': now.toIso8601String(),
      });

      final uri = Uri.parse('$kBaseUrl/api/steps/today');
      debugPrint("📤 PUT $uri steps=$adjustedSteps");

      final res = await http.put(
        uri,
        headers: {
          ...headers,
          'Content-Type': 'application/json',
          'X-User-Id': _myUserId.toString(),
        },
        body: body,
      );

      debugPrint("📥 Response ${res.statusCode}: ${res.body}");

      if (res.statusCode == 200) {
        _lastSent = adjustedSteps;
        _lastSendTime = now;
      }
    } catch (e) {
      debugPrint("❌ 서버 전송 실패: $e");
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _flush(sync: true);
    } else if (state == AppLifecycleState.resumed) {
      _startAutoTick();
    }
  }

  String _getLevelImagePath(double progress) {
    if (progress >= 0.75) return 'assets/images/level4.png';
    if (progress >= 0.5) return 'assets/images/level3.png';
    if (progress >= 0.25) return 'assets/images/level2.png';
    if (progress > 0) return 'assets/images/level1.png';
    return 'assets/images/level1.png';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final familyCount = _family.isNotEmpty ? _family.length : 1;

    // ✅ 가족 인원 수 반영한 주간 목표 & 걸음 수
    final weeklyGoal = _myGoal * familyCount * 7;
    final weeklySteps = _family.isNotEmpty
        ? _family.map((f) => f.week).reduce((a, b) => a + b)
        : todaySteps;

    // ✅ 가족 전체 오늘 걸음 합산
    final totalTodaySteps = _family.isNotEmpty
        ? _family.map((f) => f.today).reduce((a, b) => a + b)
        : todaySteps;

    const stepSize = 1000;
    final steppedWeeklyProgress =
    (weeklyGoal > 0 ? ((weeklySteps ~/ stepSize) * stepSize) / weeklyGoal : 0.0)
        .clamp(0.0, 1.0);

    Color getProgressColor(double progress) {
      if (progress >= 0.75) return Colors.orange;
      if (progress >= 0.5) return Colors.lightGreen;
      if (progress >= 0.25) return Colors.blueAccent;
      return Colors.grey;
    }

    final levelImage = _getLevelImagePath(steppedWeeklyProgress);

    // ✅ 하루 목표도 가족 인원 수 반영
    final todayGoalWithFamily = _myGoal * familyCount;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Card(
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "주간 진행률",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.info_outline, size: 24),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => const LevelInfoPopup(),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 180,
                    width: 180,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
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
                                child: Center(
                                  child: SizedBox(
                                    height: 140,
                                    width: 140,
                                    child: Image.asset(levelImage, fit: BoxFit.contain),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(
                          height: 140,
                          width: 140,
                          child: Image.asset(
                            levelImage,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "이번 주 $weeklySteps / $weeklyGoal 걸음",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  WaveProgressBar(
                    progress: _family.isNotEmpty
                        ? (totalTodaySteps / todayGoalWithFamily).clamp(0.0, 1.0)
                        : 0.0,
                    color: Colors.green,
                    height: 20, // 막대 두께
                  ),
                  const SizedBox(height: 4),
                  Text(
                    // ✅ 여기서 totalTodaySteps 사용!
                    "오늘 $totalTodaySteps / $todayGoalWithFamily 걸음",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            // ✅ 여기는 개인별 걸음 수 그대로
            child: FamilyStepsWidget(
              members: _family,
              range: range,
              goal: _myGoal,
              myUserId: _myUserId,
            ),
          ),
        ],
      ),
    );
  }
}