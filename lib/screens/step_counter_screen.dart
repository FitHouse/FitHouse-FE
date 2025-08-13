import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:fithouse/api/http_client.dart'; // authHeaders()

class StepCounterScreen extends StatefulWidget {
  const StepCounterScreen({super.key});
  @override
  State<StepCounterScreen> createState() => _StepCounterScreenState();
}

class _StepCounterScreenState extends State<StepCounterScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin<StepCounterScreen> {
  // 네이티브에서 보내는 걸음 이벤트 채널
  static const _eventChannel = EventChannel('step_counter/events');

  @override
  bool get wantKeepAlive => true;

  // 기본 Base URL
  // - 에뮬레이터: 10.0.2.2
  // - 실기기: PC의 사설 IP(예: http://192.168.x.y:8080)
  static const String _defaultAndroid = 'http://localhost:8080';
  static const String _defaultOther   = 'http://localhost:8080';
  String get _initialBaseUrl => Platform.isAndroid ? _defaultAndroid : _defaultOther;

  final _baseUrlCtrl = TextEditingController();
  late Dio _dio;

  StreamSubscription? _sub;
  Timer? _tick;

  // 센서/서버 상태
  int _sensorSteps = 0;     // 센서에서 실시간 들어오는 값(증가분 or 누적, 어떤 형태든 안전하게 처리)
  int _serverSteps = 0;     // 서버(DB)에 저장된 오늘자 값(확정)
  int _serverAtSync = 0;    // 마지막 서버 동기 시점의 서버 누적값
  int _sensorAtSync = 0;    // 마지막 서버 동기 시점의 센서 기준값
  int _lastSent = -1;       // 마지막으로 서버에 반영된 값(중복 전송 방지)
  String? _error;

  bool _autoSend = true;
  bool _loading = false;
  String _log = '';

  // TODO: 실제 로그인 사용자로 교체
  final int _userId = 6;

  // 현재 누적(서버 기준 + 센서 증가분)
  int get _currentTotal {
    final delta = _sensorSteps - _sensorAtSync;
    return _serverAtSync + (delta > 0 ? delta : 0);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _baseUrlCtrl.text = _initialBaseUrl;
    _dio = Dio(BaseOptions(baseUrl: _baseUrlCtrl.text, responseType: ResponseType.json));

    // 센서 이벤트 수신: 실시간 값만 갱신
    _sub = _eventChannel.receiveBroadcastStream().listen((event) {
      setState(() {
        _sensorSteps = (event as num).toInt();
        _error = null;
      });
    }, onError: (e) {
      setState(() => _error = e.toString());
    });

    // 앱 시작 시 서버 저장값 로드
    _fetchTodayFromServer();

    _startAutoTick();
  }

  void _startAutoTick() {
    _tick?.cancel();
    if (_autoSend) {
      _tick = Timer.periodic(const Duration(minutes: 1), (_) => _flush());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _flush(); // 백그라운드로 갈 때 한 번 밀어줌(변화 없으면 스킵)
    }
  }

  void _appendLog(String s) {
    setState(() {
      _log = '${DateTime.now().toIso8601String()}  $s\n$_log';
    });
  }

  Future<void> _applyBaseUrl() async {
    _dio = Dio(BaseOptions(baseUrl: _baseUrlCtrl.text.trim(), responseType: ResponseType.json));
    _appendLog('Base URL 변경: ${_baseUrlCtrl.text.trim()}');
    _showSnack('Base URL 적용 완료');
    // URL 변경 시 최신 서버값 재조회
    _fetchTodayFromServer();
  }

  // 서버에서 오늘값 조회
  Future<void> _fetchTodayFromServer() async {
    try {
      final headers = await authHeaders();
      headers['X-User-Id'] = _userId.toString();

      final res = await _dio.get(
        '/api/steps/today',
        queryParameters: {'clientAt': DateTime.now().toIso8601String()},
        options: Options(headers: headers),
      );

      if (res.statusCode == 200 && res.data != null) {
        final data = (res.data is String) ? jsonDecode(res.data) : res.data;
        final steps = (data['steps'] ?? 0) as int;

        setState(() {
          _serverSteps  = steps;
          _serverAtSync = steps;         // 동기 기준(서버) 확정
          _sensorAtSync = _sensorSteps;  // 동기 기준(센서) 확정
          _lastSent     = steps;
        });

        _appendLog('GET /api/steps/today 200 $data');
      } else {
        _appendLog('GET /api/steps/today ${res.statusCode} (no body)');
      }
    } catch (e) {
      _appendLog('GET 실패: $e');
    }
  }

  // 변화 없으면 전송 스킵, 변화 있으면 서버 반영
  Future<void> _flush() async {
    final toSend = _currentTotal;

    // 변화 없으면 전송 스킵
    if (toSend == _lastSent) {
      _appendLog('전송 생략(변화 없음): $toSend');
      return;
    }

    setState(() => _loading = true);
    try {
      final headers = await authHeaders();
      headers['X-User-Id'] = _userId.toString();

      final res = await _dio.put(
        '/api/steps/today',
        data: {'steps': toSend, 'clientAt': DateTime.now().toIso8601String()},
        options: Options(headers: headers),
      );

      final data = (res.data is String) ? jsonDecode(res.data) : res.data;
      final saved = (data?['steps'] ?? toSend) as int;

      setState(() {
        _serverSteps  = saved;
        _lastSent     = saved;
        // 동기 기준 재설정 → 이후 delta는 여기서부터 다시 계산
        _serverAtSync = saved;
        _sensorAtSync = _sensorSteps;
      });

      _appendLog('PUT /api/steps/today ${res.statusCode} $data');
      _showSnack('서버 저장 성공: $saved');
    } catch (e) {
      _appendLog('전송 실패: $e');
      _showSnack('서버 저장 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _sub?.cancel();
    _baseUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin
    return Scaffold(
      appBar: AppBar(title: const Text('만보기 연동 테스트')),
      body: AbsorbPointer(
        absorbing: _loading,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _baseUrlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'API Base URL',
                      hintText: '에뮬레이터: http://10.0.2.2:8080\n실기기: PC IP 예) http://192.168.x.x:8080',
                    ),
                    maxLines: 2,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _applyBaseUrl,
                  child: const Text('적용'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 표시 영역: 현재 추정값(서버 + 센서 증가분), 서버값, 센서값
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('오늘 걸음 수', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('현재 추정(서버+증가분): $_currentTotal', style: const TextStyle(fontSize: 26)),
                    const SizedBox(height: 6),
                    Text('서버 저장값: $_serverSteps'),
                    Text('센서 실시간값: $_sensorSteps'),
                    const SizedBox(height: 8),
                    Text('마지막 전송값: $_lastSent'),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text('에러: $_error', style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Text('1분 자동 전송'),
                          const SizedBox(width: 8),
                          Switch(
                            value: _autoSend,
                            onChanged: (v) {
                              setState(() => _autoSend = v);
                              _startAutoTick();
                            },
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _flush,
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('즉시 전송'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            const Text('요청 로그', style: TextStyle(fontWeight: FontWeight.w600)),
            Container(
              height: 220,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(border: Border.all(color: Colors.black12)),
              child: SingleChildScrollView(child: Text(_log)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
