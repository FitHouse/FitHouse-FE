package com.codechip.fithouse

import android.os.Bundle
import com.pravera.flutter_foreground_task.FlutterForegroundTaskPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // flutter_foreground_task 초기화
        FlutterForegroundTaskPlugin.setPluginRegistrant(flutterEngine)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 앱이 완전히 종료되었다가 재시작될 때
        // ForegroundService 플러그인 초기화
        FlutterForegroundTaskPlugin.startFlutterForegroundTask(this.applicationContext)
    }
}
