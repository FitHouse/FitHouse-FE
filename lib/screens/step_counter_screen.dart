import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fithouse/models/family_steps.dart';
import 'package:fithouse/screens/widgets/family_steps_widget.dart';
import 'package:fithouse/screens/widgets/family_progress_card.dart';
import 'package:fithouse/api/http_client.dart' show baseUrl, httpClient, authHeaders;
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class StepCounterRepo {
  const StepCounterRepo();

  Future<List<FamilySteps>> fetchFamilySteps(
      int familyId, {
        String range = 'today',
      }) async {
    final uri = Uri.parse('$baseUrl/api/families/$familyId/steps/summary')
        .replace(queryParameters: {'range': range});
    final res = await httpClient.get(uri, headers: await authHeaders());
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
  const CommunityRepo();

  Future<FamilySummary> fetchFamilySummary() async {
    final uri = Uri.parse('$baseUrl/api/community/family');
    final res = await httpClient.get(uri, headers: await authHeaders());
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
  State<StepCounterScreen> createState() => StepCounterScreenState();
}

class StepCounterScreenState extends State<StepCounterScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {

  Timer? midnightTimer;

  static StepCounterScreenState? instance;

  static const platform = MethodChannel("steps_channel");

  int initialServerSteps = 0;     // 서버에서 오늘 걸음 가져온 값
  int? baseSensorSteps;          // 센서 누적 시작 지점

  final StepCounterRepo _repo = const StepCounterRepo();
  final CommunityRepo _communityRepo = const CommunityRepo();
  bool _disposed = false;
  int? _myUserId;
  int? _myFamilyId;
  int _myGoal = 10000;

  int todaySteps = 0;
  int _lastSent = -1;

  List<FamilySteps> _family = [];
  FamilyStepsSummary? _familySummary;

  Timer? _prefsTick;
  Timer? _sendTick;
  bool _loading = true;

  DateTime? _lastFetchedDate;
  static const Duration _minSendInterval = Duration(minutes: 1);
  DateTime _lastSendTime = DateTime.fromMillisecondsSinceEpoch(0);


  Future<int> _getTodayStepsFromNative() async {
    try {
      final steps = await platform.invokeMethod<int>("getTodaySteps");
      return steps ?? 0;
    } catch (e) {
      debugPrint("Native read error: $e");
      return 0;
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    instance = this;

    _scheduleMidnightRefresh();   // <-- 자정 감지 기능 추가

    _loadAll().then((_) {
      _lastFetchedDate = DateTime.now();
      _startReadingPrefs();
      _startSendTick();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _prefsTick?.cancel();
    _sendTick?.cancel();

    midnightTimer?.cancel();   // <-- 추가

    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
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

      await _fetchStepsFromServer();
    } catch (e) {
      debugPrint("❌ 초기 데이터 로딩 실패: $e");
      _family = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchStepsFromServer() async {
    if (_myFamilyId == null) {
      if (!mounted) return;
      setState(() => _family = []);
      return;
    }

    try {
      final uri = Uri.parse('$baseUrl/api/families/$_myFamilyId/steps/summary')
          .replace(queryParameters: {'range': 'week'});

      final res = await httpClient.get(uri, headers: await authHeaders());
      if (res.statusCode != 200) throw Exception("weekly fetch failed");

      final data = jsonDecode(res.body);
      final summary = FamilyStepsSummary.fromJson(data);

      // await 후 dispose 되었을 가능성 → 무조건 체크해야 함
      if (!mounted) return;

      final todayList = await _repo.fetchFamilySteps(_myFamilyId!, range: 'today');

      if (!mounted) return;  // ← 반드시 들어가야 함

      if (todayList.isEmpty) {
        setState(() {
          _familySummary = summary;
          _family = [];
          todaySteps = 0;
        });
        return;
      }

      final my = _myUserId == null
          ? todayList.first
          : todayList.firstWhere((f) => f.userId == _myUserId,
          orElse: () => todayList.first);

      if (!mounted) return;  // ← setState 전에 다시 체크

      setState(() {
        _familySummary = summary;
        _family = todayList;
        // 서버에서 받아온 오늘 걸음(누적) → 초기 todaySteps로 설정
        if (todaySteps < my.today) {
          todaySteps = my.today;
        }
      });

      await platform.invokeMethod("setServerToday", my.today);
      await Future.delayed(Duration(milliseconds: 200)); // 데이터 저장 안정화

      await platform.invokeMethod("prepareStepService");

    } catch (e) {
      debugPrint("걸음 수 서버 로드 실패: $e");

      if (!mounted) return;

      setState(() => _family = []);
    }
  }


  /// SharedPreferences("steps") → todaySteps 읽기
  void _startReadingPrefs() {
    _prefsTick?.cancel();
    _prefsTick = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || _disposed) return;

      final localSteps = await _getTodayStepsFromNative();

      if (!mounted || _disposed) return;

      if (localSteps != todaySteps) {
        if (!mounted || _disposed) return;
        setState(() {
          todaySteps = localSteps;
          final idx = _family.indexWhere((f) => f.userId == _myUserId);
          if (idx != -1) {
            _family[idx] = _family[idx].copyWith(today: todaySteps);
          }
        });
      }
    });
  }

  void _scheduleMidnightRefresh() {
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);

    final duration = nextMidnight.difference(now);

    midnightTimer?.cancel();
    midnightTimer = Timer(duration, () async {
      print("자정 감지됨! summary 자동 새로고침 실행");

      await _fetchStepsFromServer(); // 서버에서 최신 주간/오늘 걸음수 받아오기

      // 다음 자정도 다시 예약
      _scheduleMidnightRefresh();
    });
  }


  /// 주기적으로 서버 전송
  void _startSendTick() {
    _sendTick?.cancel();
    _sendTick = Timer.periodic(const Duration(minutes: 1), (_) => _flush());
  }

  Future<void> _flush({bool sync = false}) async {
    if (_myUserId == null) return;

    final stepsToSend = todaySteps;
    if (stepsToSend == _lastSent) return;

    final now = DateTime.now();
    if (!sync && now.difference(_lastSendTime) < _minSendInterval) return;
    if (!sync && (stepsToSend - _lastSent).abs() < 10) return;

    try {
      final body = jsonEncode({
        'steps': stepsToSend,
        'clientAt': now.toIso8601String(),
      });

      final uri = Uri.parse('$baseUrl/api/steps/today');
      final res = await httpClient.put(
        uri,
        headers: {
          ...await authHeaders(),
          'Content-Type': 'application/json',
          if (_myUserId != null) 'X-User-Id': _myUserId.toString(),
        },
        body: body,
      );

      if (res.statusCode == 200) {
        _lastSent = stepsToSend;
        _lastSendTime = now;
      }
    } catch (e) {
      debugPrint("서버 전송 실패: $e");
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _flush(sync: true);
    } else if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      if (_lastFetchedDate == null || !_isSameDay(_lastFetchedDate!, now)) {
        _fetchStepsFromServer();
        _lastFetchedDate = now;
      }
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

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_family.isEmpty) {
      return Scaffold(
        body: RefreshIndicator(
          onRefresh: _loadAll,
          child: ListView(
            children: const [
              SizedBox(height: 120),
              _NoFamilyView(),
            ],
          ),
        ),
      );
    }

    final familyCount = _family.isNotEmpty ? _family.length : 1;
    final weeklyGoal = _myGoal * familyCount * 7;

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
              range: 'today',
              goal: _myGoal,
              myUserId: _myUserId,
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
