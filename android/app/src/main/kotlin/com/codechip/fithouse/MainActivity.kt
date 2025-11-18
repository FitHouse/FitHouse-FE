package com.codechip.fithouse


import android.Manifest
import android.content.Context
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
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import java.time.LocalDate
import java.util.concurrent.TimeUnit
import com.codechip.fithouse.StepSyncWorker


class MainActivity : FlutterActivity(), SensorEventListener {

    private val CHANNEL = "step_counter/events"
    private val REQ_ACTIVITY_RECOGNITION = 1001
    private val PREFS_NAME = "step_prefs"
    private val KEY_LAST_CUMULATIVE = "last_cumulative"
    private val KEY_LAST_DATE = "last_date"

    private var sensorManager: SensorManager? = null
    private var stepDetector: Sensor? = null
    private var stepCounter: Sensor? = null

    private var eventsSink: EventChannel.EventSink? = null

    private var currentSteps = 0 // TYPE_STEP_DETECTOR 전용
    private var baseCounter: Int? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 기존 센서 초기화 코드
        sensorManager = getSystemService(SENSOR_SERVICE) as SensorManager
        stepDetector = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR)
        stepCounter = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)

        // WorkManager 예약 (15분마다 실행)
        val workRequest = PeriodicWorkRequestBuilder<StepSyncWorker>(15, TimeUnit.MINUTES).build()
        WorkManager.getInstance(applicationContext).enqueue(workRequest)
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
        stopListening()

        val preferCounter = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        val preferDetector = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR)

        val ok = when {
            preferCounter != null -> {
                stepCounter = preferCounter
                baseCounter = null
                currentSteps = 0
                sensorManager?.registerListener(
                    this, stepCounter,
                    SensorManager.SENSOR_DELAY_FASTEST,
                    0
                )
                Log.d("Steps", "Using STEP_COUNTER: ${stepCounter?.name} / ${stepCounter?.vendor}")
                true
            }

            preferDetector != null -> {
                stepDetector = preferDetector
                currentSteps = 0
                sensorManager?.registerListener(
                    this, stepDetector,
                    SensorManager.SENSOR_DELAY_FASTEST,
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

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val todayStr = LocalDate.now().toString()

        when (event.sensor.type) {
            Sensor.TYPE_STEP_COUNTER -> {
                if (event.values.isNotEmpty()) {
                    val cumulative = event.values[0].toInt()
                    val lastDate = prefs.getString(KEY_LAST_DATE, null)
                    val lastSaved = prefs.getInt(KEY_LAST_CUMULATIVE, -1)

                    // 날짜가 바뀌었거나 최초 실행이면 초기화
                    if (lastDate != todayStr || lastSaved == -1) {
                        prefs.edit()
                            .putString(KEY_LAST_DATE, todayStr)
                            .putInt(KEY_LAST_CUMULATIVE, cumulative)
                            .apply()
                        eventsSink?.success(0)
                    } else {
                        val diff = cumulative - lastSaved
                        eventsSink?.success(if (diff >= 0) diff else 0)
                    }
                }
            }

            Sensor.TYPE_STEP_DETECTOR -> {
                if (event.values.isNotEmpty() && event.values[0] >= 0.5f) {
                    // 날짜 변경 체크
                    val lastDate = prefs.getString(KEY_LAST_DATE, null)
                    if (lastDate != todayStr) {
                        prefs.edit()
                            .putString(KEY_LAST_DATE, todayStr)
                            .apply()
                        currentSteps = 0
                    }
                    currentSteps += 1
                    eventsSink?.success(currentSteps)
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        if (eventsSink != null) startListening()
    }

    override fun onPause() {
        super.onPause()
        stopListening()
    }
}
