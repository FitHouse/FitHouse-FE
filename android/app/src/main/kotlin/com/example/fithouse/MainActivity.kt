package com.example.fithouse  // ← 실제 패키지명으로 바꿔주세요(Manifest와 동일해야 함)

import android.Manifest
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.widget.Toast
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity(), SensorEventListener {

    private val CHANNEL = "step_counter/events"
    private val REQ_ACTIVITY_RECOGNITION = 1001

    private var sensorManager: SensorManager? = null
    private var stepDetector: Sensor? = null
    private var stepCounter: Sensor? = null

    private var eventsSink: EventChannel.EventSink? = null

    // DETECTOR용 세션 카운터
    private var currentSteps = 0

    // COUNTER(누적) 기준값: 세션 시작 시점의 누적값을 저장해 상대값으로 표시
    private var baseCounter: Int? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        sensorManager = getSystemService(SENSOR_SERVICE) as SensorManager
        // 센서는 startListening()에서 다시 확인하지만 한 번 캐시해 둠
        stepDetector = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR)
        stepCounter  = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                    eventsSink = sink
                    ensurePermissionAndStart()
                }

                override fun onCancel(args: Any?) {
                    stopListening()
                    eventsSink = null
                }
            })
    }

    private fun ensurePermissionAndStart() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val granted = ContextCompat.checkSelfPermission(
                this, Manifest.permission.ACTIVITY_RECOGNITION
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) {
                ActivityCompat.requestPermissions(
                    this, arrayOf(Manifest.permission.ACTIVITY_RECOGNITION),
                    REQ_ACTIVITY_RECOGNITION
                )
                return
            }
        }
        startListening()
    }

    private fun startListening() {
        // 중복 등록 방지
        stopListening()

        // 항상 최신 센서 핸들을 다시 조회(일부 기기에서 상태 변동 대비)
        val preferCounter  = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        val preferDetector = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR)

        val ok = when {
            // 1) STEP_COUNTER(누적) 우선: 정상 보행에서 제일 안정적
            preferCounter != null -> {
                stepCounter = preferCounter
                baseCounter = null        // 새 세션 시작 시 기준값 초기화
                currentSteps = 0
                // 배치 없이 즉시 전달: maxReportLatencyUs = 0
                sensorManager?.registerListener(
                    this, stepCounter,
                    20_000,   // samplingPeriodUs ≈ 50Hz
                    0         // maxReportLatencyUs (no batching)
                )
                Log.d("Steps", "Using STEP_COUNTER: ${stepCounter?.name} / ${stepCounter?.vendor}")
                true
            }

            // 2) STEP_DETECTOR(이벤트=1) 대체 경로
            preferDetector != null -> {
                stepDetector = preferDetector
                currentSteps = 0
                sensorManager?.registerListener(
                    this, stepDetector,
                    20_000,
                    0
                )
                Log.d("Steps", "Using STEP_DETECTOR: ${stepDetector?.name} / ${stepDetector?.vendor}")
                true
            }

            else -> false
        }

        if (!ok) {
            Toast.makeText(this, "No Step Sensor", Toast.LENGTH_SHORT).show()
            eventsSink?.error("NO_SENSOR", "No step sensor on device", null)
        }
    }

    private fun stopListening() {
        sensorManager?.unregisterListener(this)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_ACTIVITY_RECOGNITION) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                startListening()
            } else {
                eventsSink?.error("PERMISSION_DENIED", "ACTIVITY_RECOGNITION denied", null)
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null) return

        when (event.sensor.type) {
            Sensor.TYPE_STEP_COUNTER -> {
                // 누적값 → 세션 상대값으로 변환해서 보냄
                if (event.values.isNotEmpty()) {
                    val cumulative = event.values[0].toInt()
                    if (baseCounter == null) {
                        baseCounter = cumulative
                        // 첫 이벤트는 0으로 보정(바로 0을 보내 사용자가 증가 시작을 확인 가능)
                        eventsSink?.success(0)
                        return
                    }
                    val relative = cumulative - (baseCounter ?: 0)
                    eventsSink?.success(relative)
                }
            }

            Sensor.TYPE_STEP_DETECTOR -> {
                // 이벤트마다 1.0f 이상
                if (event.values.isNotEmpty() && event.values[0] >= 0.5f) {
                    currentSteps += 1
                    eventsSink?.success(currentSteps)
                }
            }
        }
    }

    // 화면 켜진 동안만 확실히 센서 유지하고 싶다면(선택)
    override fun onResume() {
        super.onResume()
        if (eventsSink != null) startListening()
    }

    override fun onPause() {
        super.onPause()
        stopListening()
    }
}
