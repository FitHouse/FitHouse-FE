import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:pedometer/pedometer.dart';

class StepTaskHandler extends TaskHandler {
  StreamSubscription<StepCount>? _stepSub;
  int _latestSteps = 0;

  @override
  void onStart(DateTime timestamp) {
    // pedometer 스트림 시작
    _stepSub = Pedometer.stepCountStream.listen(
          (StepCount event) {
        _latestSteps = event.steps;
        // 메인으로 센서 값 전송
        FlutterForegroundTask.sendDataToMain({'steps': _latestSteps});
      },
      onError: (err) {
        FlutterForegroundTask.sendDataToMain({'error': err.toString()});
      },
    );
  }

  @override
  void onDestroy(DateTime timestamp) {
    _stepSub?.cancel();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // 여기서는 아무것도 하지 않음 (1초 타이머 방식 제거)
    // pedometer 스트림이 알아서 steps 이벤트를 보내므로 불필요
  }
}
