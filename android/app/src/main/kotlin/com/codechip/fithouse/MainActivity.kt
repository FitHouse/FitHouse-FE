package com.codechip.fithouse

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.content.Context
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    private val REQ_ACTIVITY_RECOGNITION = 1001
    private val REQ_POST_NOTIFICATIONS = 2001

    private val CHANNEL = "steps_channel"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->

                when (call.method) {

                    "getTodaySteps" -> {
                        val prefs = getSharedPreferences("steps", Context.MODE_PRIVATE)
                        val steps = prefs.getInt("todaySteps", 0)
                        result.success(steps)
                    }

                    // 권한만 확인
                    "startStepService" -> {
                        requestNeededPermissions()
                        result.success(true)
                    }

                    // 진짜 서비스 실행은 여기서!
                    "runStepService" -> {
                        startStepService()
                        result.success(true)
                    }

                    "setServerToday" -> {
                        val value = call.arguments as Int
                        val prefs = getSharedPreferences("steps", Context.MODE_PRIVATE)
                        prefs.edit().putInt("serverToday", value).apply()
                        result.success(true)
                    }

                    "prepareStepService" -> {
                        if (checkAllPermissionsGranted()) {
                            startStepService()
                        } else {
                            requestNeededPermissions()
                        }
                        result.success(true)
                    }

                    "setUserId" -> {
                        val userId = call.argument<Int>("userId") ?: -1
                        val prefs = getSharedPreferences("steps", Context.MODE_PRIVATE)
                        prefs.edit().putInt("user_id", userId).apply()
                        result.success(true)
                    }

                    "stopStepService" -> {
                        stopStepService()
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun stopStepService() {
        val intent = Intent(this, StepService::class.java)
        stopService(intent)
    }

    private fun checkAllPermissionsGranted(): Boolean {
        // Android 13+ 알림 권한
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val notifGranted = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED

            if (!notifGranted) return false
        }

        // Android 10+ Activity Recognition
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val actGranted = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.ACTIVITY_RECOGNITION
            ) == PackageManager.PERMISSION_GRANTED

            if (!actGranted) return false
        }

        return true
    }


    private fun requestNeededPermissions() {

        var needsRequest = false

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val notifGranted = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED

            if (!notifGranted) {
                needsRequest = true
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    REQ_POST_NOTIFICATIONS
                )
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val actGranted = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.ACTIVITY_RECOGNITION
            ) == PackageManager.PERMISSION_GRANTED

            if (!actGranted) {
                needsRequest = true
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.ACTIVITY_RECOGNITION),
                    REQ_ACTIVITY_RECOGNITION
                )
            }
        }

        // 권한 요청이 필요한 상황이 아니면 바로 서비스 실행
        if (!needsRequest) {
            startStepService()
        }
    }


    private fun startStepService() {
        val intent = Intent(this, StepService::class.java)
        ContextCompat.startForegroundService(this, intent)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (grantResults.isEmpty() || grantResults[0] != PackageManager.PERMISSION_GRANTED)
            return

        // 모든 권한이 허용되었는지 다시 검사
        if (checkAllPermissionsGranted()) {
            startStepService()
        }
    }
}
