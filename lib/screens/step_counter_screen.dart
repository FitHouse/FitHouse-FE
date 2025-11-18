import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:fithouse/models/family_steps.dart';
import 'package:fithouse/screens/widgets/family_steps_widget.dart';
import 'package:fithouse/api/http_client.dart' show baseUrl, httpClient, authHeaders;
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import '../background/step_task_handler.dart';
import 'community_tab.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(StepTaskHandler());
}

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
    return (data['members'] as List)
        .map((e) => FamilySteps.fromJson(e))
        .toList();
  }
}

class CommunityRepo {
  const CommunityRepo();

  Future<FamilySummary> fetchFamilySummary() async {
    final uri = Uri.parse('$baseUrl/api/community/family');
    final res = await httpClient.get(uri, headers: await authHeaders());

    if (res.statusCode != 200) {
      throw Exception('summary ${res.statusCode}: ${res.body}');
    }

    return FamilySummary.fromJson(jsonDecode(res.body));
  }
}


class StepCounterScreen extends StatefulWidget {
  const StepCounterScreen({super.key});

  @override
  State<StepCounterScreen> createState() => _StepCounterScreenState();
}

class _StepCounterScreenState extends State<StepCounterScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {

  final StepCounterRepo _repo = const StepCounterRepo();
  final CommunityRepo _communityRepo = const CommunityRepo();

  int? _myUserId;
  int? _myFamilyId;
  int _myGoal = 10000;

  int todaySteps = 0;
  List<FamilySteps> _family = [];
  FamilyStepsSummary? _familySummary;

  StreamSubscription? _sub;
  Timer? _tick;
  Timer? _midnightTimer;

  int _sensorStepsNow = 0;
  int _startSensorSteps = 0;
  int _startServerSteps = 0;

  static const int _stepChangeThreshold = 10;
  static const Duration _minSendInterval = Duration(minutes: 1);

  DateTime _lastSendTime = DateTime.fromMillisecondsSinceEpoch(0);
  int _lastSent = -1;

  bool _hasFlushedThisCycle = false;
  DateTime? _lastFetchedDate;

  bool _loading = true;

  ReceivePort? _receivePort;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    FlutterForegroundTask.addTaskDataCallback(_onTaskData);

    _initForegroundTask().then((_) async {

      // 1) 권한 요청
      final loc = await Permission.locationWhenInUse.request();
      final act = await Permission.activityRecognition.request();

      // 2) 권한 체크 후 서비스 실행
      if (loc.isGranted && act.isGranted) {
        await FlutterForegroundTask.startService(
          notificationTitle: 'FitHouse',
          notificationText: '걸음 수 측정 중',
          callback: startCallback,
        );
      } else {
        // 권한 거부 시 앱이 crash 방지
        debugPrint("권한 거부됨. ForegroundService 시작 불가.");
      }
    });

    _loadAll().then((_) {
      _lastFetchedDate = DateTime.now();
      _startAutoTick();
      _scheduleMidnightRefresh();
    });
  }



  Future<void> _initForegroundTask() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'step_service',
        channelName: 'FitHouse Step Service',
        channelDescription: 'Background step counter',
        channelImportance: NotificationChannelImportance.LOW,
      ),
      iosNotificationOptions: IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000),
      ),
    );

    /// ⛔ _receivePort = ... 절대 불가 (void 반환)
    /// ⛔ getReceivePort() 없음
    /// ✔ 네 버전에서는 통신 포트는 이렇게 초기화해야 함:
    FlutterForegroundTask.initCommunicationPort();

    /// 메시지는 callback으로 받음
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
  }




  /// 🔥 Task 데이터 콜백
  void _onTaskData(dynamic data) {
    if (data is Map && data.containsKey('steps')) {
      final sensorNow = data['steps'] as int;

      if (_startSensorSteps == 0) {
        _startSensorSteps = sensorNow;
      }

      _sensorStepsNow = sensorNow;

      final adjusted = _startServerSteps +
          (sensorNow - _startSensorSteps).clamp(0, 999999);

      if (!mounted) return;

      setState(() {
        todaySteps = adjusted;
        final idx = _family.indexWhere((f) => f.userId == _myUserId);
        if (idx != -1) {
          _family[idx] = _family[idx].copyWith(today: todaySteps);
        }
      });
    }
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);

    if (!_hasFlushedThisCycle) {
      _flush(sync: true);
      _hasFlushedThisCycle = true;
    }

    _tick?.cancel();
    _sub?.cancel();
    _midnightTimer?.cancel();
    _receivePort?.close();

    super.dispose();
  }

  /// 1분마다 서버로 기록
  void _startAutoTick() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) => _flush());
  }

  Future<void> _scheduleMidnightRefresh() async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final duration = tomorrow.difference(now);

    _midnightTimer?.cancel();
    _midnightTimer = Timer(duration, () async {
      _startSensorSteps = 0;
      _startServerSteps = 0;
      _sensorStepsNow = 0;

      if (mounted) {
        setState(() => todaySteps = 0);
      }

      await _fetchSteps();
      _scheduleMidnightRefresh();
    });
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

      await _fetchSteps();
    } catch (_) {
      setState(() => _family = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchSteps() async {
    if (_myFamilyId == null) {
      setState(() => _family = []);
      return;
    }

    try {
      final uri = Uri.parse('$baseUrl/api/families/$_myFamilyId/steps/summary')
          .replace(queryParameters: {'range': 'week'});

      final res = await httpClient.get(uri, headers: await authHeaders());
      if (res.statusCode != 200) return;

      final summary = FamilyStepsSummary.fromJson(jsonDecode(res.body));
      final todayList = await _repo.fetchFamilySteps(_myFamilyId!, range: 'today');

      if (todayList.isEmpty) {
        setState(() {
          _familySummary = summary;
          _family = [];
          todaySteps = 0;
          _startServerSteps = 0;
        });
        return;
      }

      final meToday = _myUserId == null
          ? todayList.first
          : todayList.firstWhere(
            (f) => f.userId == _myUserId,
        orElse: () => todayList.first,
      );

      _startServerSteps = meToday.today;

      setState(() {
        _familySummary = summary;
        _family = todayList;
        todaySteps = meToday.today;
      });
    } catch (_) {
      setState(() => _family = []);
    }
  }

  Future<void> _flush({bool sync = false}) async {
    if (_myUserId == null) return;

    final adjusted = _startServerSteps +
        (_sensorStepsNow - _startSensorSteps).clamp(0, 999999);

    if (adjusted == _lastSent) return;

    final now = DateTime.now();
    if (!sync) {
      if (now.difference(_lastSendTime) < _minSendInterval) return;
      if ((adjusted - _lastSent).abs() < _stepChangeThreshold) return;
    }

    try {
      final body = jsonEncode({
        'steps': adjusted,
        'clientAt': now.toIso8601String(),
      });

      final uri = Uri.parse('$baseUrl/api/steps/today');

      final res = await httpClient.put(
        uri,
        headers: {
          ...await authHeaders(),
          'Content-Type': 'application/json',
          'X-User-Id': _myUserId.toString(),
        },
        body: body,
      );

      if (res.statusCode == 200) {
        _lastSent = adjusted;
        _lastSendTime = now;
      }
    } catch (_) {}
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
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
