// step_counter_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fithouse/models/family_steps.dart';
import 'package:fithouse/screens/widgets/family_steps_widget.dart';
import 'package:fithouse/screens/widgets/level_info_popup.dart';
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
    final uri = Uri.parse('$baseUrl/api/me/family/summary');
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

class _StepCounterScreenState extends State<StepCounterScreen> {
  late final StepCounterRepo _repo = StepCounterRepo(baseUrl: kBaseUrl);
  late final CommunityRepo _communityRepo = CommunityRepo(baseUrl: kBaseUrl);

  int? _myUserId;
  int? _myFamilyId;
  int _myGoal = 10000;
  int todaySteps = 0;
  String range = 'today';
  Timer? _timer;
  List<FamilySteps> _family = [];
  bool _levelPopupShown = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      _fetchSteps();
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
    } catch (_) {}
  }

  Future<void> _fetchSteps() async {
    if (_myFamilyId == null) return;
    try {
      final familySteps =
      await _repo.fetchFamilySteps(_myFamilyId!, range: range);
      setState(() {
        _family = familySteps.isNotEmpty
            ? familySteps
            : [
          FamilySteps(
            userId: _myUserId ?? 0,
            familyId: _myFamilyId!,
            name: '나',
            today: 0,
            week: 0,
            month: 0,
            goal: _myGoal,
          )
        ];
        final me = _family.firstWhere(
              (f) => f.userId == _myUserId,
          orElse: () => _family.first,
        );
        todaySteps = me.today;
        if (!_levelPopupShown && todaySteps >= _myGoal) {
          _levelPopupShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showDialog(
              context: context,
              builder: (_) => const LevelInfoPopup(),
            );
          });
        }
      });
    } catch (_) {}
  }

  String _getLevelImagePath(double progress) {
    if (progress >= 0.75) return 'assets/images/level4.png';
    if (progress >= 0.5) return 'assets/images/level3.png';
    if (progress >= 0.25) return 'assets/images/level2.png';
    if (progress > 0) return 'assets/images/level1.png';
    return 'assets/images/question.png';
  }

  @override
  Widget build(BuildContext context) {
    final progress =
    _myGoal > 0 ? (todaySteps / _myGoal).clamp(0.0, 1.0) : 0.0;
    final levelImage = _getLevelImagePath(progress);

    return Scaffold(
      appBar: AppBar(title: const Text('가족 만보기')),
      body: Column(
        children: [
          // 카드 UI
          Card(
            margin: const EdgeInsets.all(16),
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상단 라벨 + 버튼
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("만보기",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {
                          // 일간 기록 보기
                        },
                        child: const Text("일간 기록"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 레벨 아이콘 + 시간
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(levelImage, height: 80),
                      const SizedBox(width: 16),
                      Text(
                        "${(todaySteps / 100).floor()}분",
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w500),
                      ),
                      IconButton(
                        icon: const Icon(Icons.info_outline),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => const LevelInfoPopup(),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text("오늘 총 걸음"),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade300,
                    color: Colors.blue,
                    minHeight: 8,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("나: $todaySteps"),
                      Text("가족 평균: ${( _family.isNotEmpty
                          ? (_family.map((f) => f.today).reduce((a,b) => a+b) / _family.length).floor()
                          : 0)}"),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 가족 랭킹
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
