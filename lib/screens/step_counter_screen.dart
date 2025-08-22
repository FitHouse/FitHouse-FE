import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fithouse/models/family_steps.dart';
import 'package:fithouse/screens/widgets/family_steps_widget.dart';
import 'package:fithouse/screens/widgets/family_progress_card.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

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

  FamilyStepsSummary? _familySummary; // ✅ 주간 요약 저장용

  static const _eventChannel = EventChannel('step_counter/events');
  StreamSubscription? _sub;
  Timer? _tick;
  Timer? _midnightTimer;
  int _sensorStepsNow = 0;

  int _startServerSteps = 0;
  int _startSensorSteps = 0;

  static const int _stepChangeThreshold = 10;
  static const Duration _minSendInterval = Duration(minutes: 1);
  DateTime _lastSendTime = DateTime.fromMillisecondsSinceEpoch(0);
  int _lastSent = -1;

  bool _hasFlushedThisCycle = false;
  DateTime? _lastFetchedDate;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _loadAll().then((_) {
      _lastFetchedDate = DateTime.now();
      _startSensorListening();
      _startAutoTick();
      _scheduleMidnightRefresh();
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
    _midnightTimer?.cancel();
    super.dispose();
  }

  void _scheduleMidnightRefresh() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final duration = tomorrow.difference(now);

    _midnightTimer?.cancel();
    _midnightTimer = Timer(duration, () async {
      debugPrint("🌙 자정 도달 → 오늘 기록 초기화 + 주간 데이터 갱신");

      _startSensorSteps = 0;
      _startServerSteps = 0;
      _sensorStepsNow = 0;

      setState(() {
        todaySteps = 0;
        if (_myUserId != null) {
          final idx = _family.indexWhere((f) => f.userId == _myUserId);
          if (idx != -1) {
            _family[idx] = _family[idx].copyWith(today: 0);
          }
        }
      });

      await _fetchSteps();
      _scheduleMidnightRefresh();
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
      _lastFetchedDate = DateTime.now();
    } catch (e) {
      debugPrint("❌ 초기 데이터 불러오기 실패: $e");
    }
  }

  Future<void> _fetchSteps() async {
    if (_myFamilyId == null) return;
    try {
      final uri = Uri.parse('$kBaseUrl/api/families/$_myFamilyId/steps/summary')
          .replace(queryParameters: {'range': 'week'});
      final headers = await _repo.authHeaders();
      final res = await http.get(uri, headers: headers);

      if (res.statusCode != 200) {
        throw Exception("summary fetch failed: ${res.body}");
      }

      final data = jsonDecode(res.body);
      final summary = FamilyStepsSummary.fromJson(data);

      final todayList =
      await _repo.fetchFamilySteps(_myFamilyId!, range: 'today');

      final meToday = todayList.firstWhere(
            (f) => f.userId == _myUserId,
        orElse: () => todayList.first,
      );

      _startServerSteps = meToday.today;

      setState(() {
        _familySummary = summary; // ✅ 저장
        _family = todayList;
        todaySteps = meToday.today;

        final meWeekly = summary.members
            .firstWhere((m) => m.userId == _myUserId,
            orElse: () => summary.members.first)
            .weekly;

        final idx = _family.indexWhere((f) => f.userId == _myUserId);
        if (idx != -1) {
          _family[idx] = _family[idx].copyWith(weekly: meWeekly);
        }
      });
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

      final adjusted =
          _startServerSteps + (sensorNow - _startSensorSteps).clamp(0, 999999);

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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _flush(sync: true);
    } else if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      if (_lastFetchedDate == null || !_isSameDay(_lastFetchedDate!, now)) {
        debugPrint("📌 날짜 변경 감지 → 데이터 새로 fetch");
        _fetchSteps();
        _lastFetchedDate = now;
      }
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
    final weeklyGoal = _myGoal * familyCount * 7;

    // ✅ 백엔드 family.totalSteps 사용
    final weeklySteps = _familySummary?.family?.totalSteps ?? 0;

    final totalTodaySteps = _family.isNotEmpty
        ? _family.map((f) => f.today).reduce((a, b) => a + b)
        : todaySteps;

    const stepSize = 1000;
    final steppedWeeklyProgress = (weeklyGoal > 0
        ? ((weeklySteps ~/ stepSize) * stepSize) / weeklyGoal
        : 0.0)
        .clamp(0.0, 1.0);

    final levelImage = _getLevelImagePath(steppedWeeklyProgress);
    final todayGoalWithFamily = _myGoal * familyCount;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          FamilyProgressCard(
            steppedWeeklyProgress: steppedWeeklyProgress,
            levelImage: levelImage,
            weeklySteps: weeklySteps,
            weeklyGoal: weeklyGoal,
            totalTodaySteps: totalTodaySteps,
            todayGoalWithFamily: todayGoalWithFamily,
          ),
          Expanded(
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
