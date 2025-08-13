import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:fithouse/api/http_client.dart'; // 기존에 작성된 authHeaders 함수가 있는 파일

class StepCounterScreen extends StatefulWidget {
  const StepCounterScreen({super.key});
  @override
  State<StepCounterScreen> createState() => _StepCounterScreenState();
}

class _StepCounterScreenState extends State<StepCounterScreen> with WidgetsBindingObserver {
  // 네이티브에서 보내는 걸음 이벤트 채널
  static const _eventChannel = EventChannel('step_counter/events');

  // 기본 Base URL (에뮬레이터/기기 구분 안내)
  // adb reverse를 사용하거나 실제 PC의 IP로 변경
  static const String _defaultAndroid = 'http://localhost:8080';
  static const String _defaultOther   = 'http://localhost:8080';
  String get _initialBaseUrl => Platform.isAndroid ? _defaultAndroid : _defaultOther;

  final _baseUrlCtrl = TextEditingController();
  late Dio _dio;

  StreamSubscription? _sub;
  Timer? _tick;

  int _steps = 0;
  int _lastSent = -1;
  String? _error;

  bool _autoSend = true;
  bool _loading = false;
  String _log = '';

  // 서버에 보낼 사용자 ID (실제 로그인 사용자로 교체/토큰으로 대체 가능)
  final int _userId = 6;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _baseUrlCtrl.text = _initialBaseUrl;
    _dio = Dio(BaseOptions(baseUrl: _baseUrlCtrl.text));

    _sub = _eventChannel.receiveBroadcastStream().listen((event) {
      setState(() {
        _steps = (event as num).toInt();
        _error = null;
      });
    }, onError: (e) {
      setState(() => _error = e.toString());
    });

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
      _flush();
    }
  }

  void _appendLog(String s) {
    setState(() {
      _log = '${DateTime.now().toIso8601String()}  $s\n$_log';
    });
  }

  Future<void> _applyBaseUrl() async {
    _dio = Dio(BaseOptions(baseUrl: _baseUrlCtrl.text.trim()));
    _appendLog('Base URL 변경: ${_baseUrlCtrl.text.trim()}');
    _showSnack('Base URL 적용 완료');
  }

  Future<void> _flush() async {
    if (_steps == _lastSent) {
      _appendLog('전송 생략(값 동일): $_steps');
      return;
    }

    setState(() => _loading = true);
    try {
      final nowIso = DateTime.now().toIso8601String();

      // Authorization 헤더와 X-User-Id 헤더를 함께 가져오기
      final headers = await authHeaders();
      headers['X-User-Id'] = _userId.toString();

      final res = await _dio.put(
        '/api/steps/today',
        data: {'steps': _steps, 'clientAt': nowIso},
        options: Options(headers: headers),
      );
      _lastSent = _steps;
      _appendLog('PUT /api/steps/today ${res.statusCode} ${res.data}');
      _showSnack('서버 저장 성공: $_steps');
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
                      hintText: '예: http://10.0.2.2:8080 (에뮬레이터)\n실기기는 PC IP 사용 예: http://192.168.x.x:8080',
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('실시간', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('걸음 수(오늘): $_steps', style: const TextStyle(fontSize: 28)),
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