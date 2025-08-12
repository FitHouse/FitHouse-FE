import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';

class StepCounterScreen extends StatefulWidget {
  const StepCounterScreen({super.key});
  @override
  State<StepCounterScreen> createState() => _StepCounterScreenState();
}

class _StepCounterScreenState extends State<StepCounterScreen> with WidgetsBindingObserver {
  static const _eventChannel = EventChannel('step_counter/events');

  final _dio = Dio(BaseOptions(baseUrl: 'http://<YOUR_SERVER_HOST>:<PORT>')); // TODO: 서버 주소
  StreamSubscription? _sub;
  Timer? _tick;

  int _steps = 0;          // “오늘 누적” (네이티브에서 상대값으로 세팅했으면 그대로 사용)
  int _lastSent = -1;      // 직전에 서버로 보낸 값(중복 전송 방지)
  String? _error;

  final int _userId = 6;   // TODO: 실제 로그인 사용자 ID로 대체(또는 토큰 인증)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 센서 스트림 구독 (실시간 표시)
    _sub = _eventChannel.receiveBroadcastStream().listen((event) {
      setState(() {
        _steps = (event as num).toInt();
        _error = null;
      });
    }, onError: (e) {
      setState(() => _error = e.toString());
    });

    // 1분마다 서버 저장
    _tick = Timer.periodic(const Duration(minutes: 1), (_) => _flush());
  }

  // 앱 포그라운드/백그라운드 전환 시에도 한 번 저장(선택)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _flush(); // 백그라운드 진입 전에 한 번 저장
    }
  }

  Future<void> _flush() async {
    // 같은 값이면 전송 생략(트래픽 절약)
    if (_steps == _lastSent) return;

    try {
      final nowIso = DateTime.now().toIso8601String();
      await _dio.put(
        '/api/steps/today',
        data: {
          'steps': _steps,       // 오늘 누적(단조 증가)
          'clientAt': nowIso,    // 서버에서 Asia/Seoul 기준 날짜 계산
        },
        options: Options(headers: {
          'X-User-Id': _userId.toString(), // or Authorization: Bearer <token>
        }),
      );
      _lastSent = _steps;
    } catch (e) {
      // 네트워크 에러는 조용히 무시하고 다음 주기에 재시도
      debugPrint('push steps failed: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _error != null
          ? Text('Error: $_error')
          : Text('걸음 수: $_steps', style: const TextStyle(fontSize: 28)),
    );
  }
}
