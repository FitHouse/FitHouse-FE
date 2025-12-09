package com.codechip.fithouse

import android.app.*
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import java.time.LocalDate
import android.content.pm.ServiceInfo
import kotlinx.coroutines.*
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject

class StepService : Service(), SensorEventListener {

    private val CHANNEL_ID = "fit_step_channel"
    private val NOTIFICATION_ID = 1001

    private lateinit var sensorManager: SensorManager
    private var stepCounter: Sensor? = null

    private lateinit var prefs: android.content.SharedPreferences

    private var baseline = 0
    private var todaySteps = 0
    private var lastDate = ""

    private var lastSyncTime = 0L
    private val syncInterval = 10_000L // 서버 자동 동기화 10초 간격

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    override fun onCreate() {
        super.onCreate()

        prefs = getSharedPreferences("steps", Context.MODE_PRIVATE)

        val todayStr = LocalDate.now().toString()
        val savedDate = prefs.getString("date", "")

        if (savedDate != todayStr) {
            prefs.edit()
                .putInt("baseline", -1)
                .putInt("todaySteps", 0)
                .putBoolean("baseline_initialized", false)
                .putString("date", todayStr)
                .apply()
        }

        baseline = prefs.getInt("baseline", -1)
        todaySteps = prefs.getInt("todaySteps", 0)
        lastDate = prefs.getString("date", "") ?: ""

        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        stepCounter = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)

        createNotificationChannel()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                buildNotification(todaySteps),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH
            )
        } else {
            startForeground(NOTIFICATION_ID, buildNotification(todaySteps))
        }

        stepCounter?.also {
            sensorManager.registerListener(
                this,
                it,
                SensorManager.SENSOR_DELAY_FASTEST
            )
        }
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null) return

        val cumulative = event.values[0].toInt()
        val todayStr = LocalDate.now().toString()

        // 자정 리셋
        if (lastDate != todayStr) {
            baseline = cumulative
            todaySteps = 0
            lastDate = todayStr

            prefs.edit()
                .putString("date", todayStr)
                .putInt("baseline", baseline)
                .putInt("todaySteps", 0)
                .putBoolean("baseline_initialized", false)
                .apply()

            updateNotification(0)
            log("MIDNIGHT RESET → baseline=$baseline / todaySteps=0")
            return
        }

        // baseline 초기 설정
        if (!prefs.getBoolean("baseline_initialized", false)) {
            baseline = cumulative
            prefs.edit()
                .putInt("baseline", baseline)
                .putBoolean("baseline_initialized", true)
                .apply()

            log("BASELINE INIT → cumulative=$cumulative / baseline=$baseline")
        }

        // 오늘 걸음 계산
        val diff = cumulative - baseline
        todaySteps = if (diff >= 0) diff else 0

        prefs.edit()
            .putInt("todaySteps", todaySteps)
            .apply()

        updateNotification(todaySteps)

        // 센서 디버그 로그
        log("EVENT → cumulative=$cumulative baseline=$baseline todaySteps=$todaySteps")

        // 서버 자동 동기화
        if (System.currentTimeMillis() - lastSyncTime > syncInterval) {
            lastSyncTime = System.currentTimeMillis()
            syncToServer(todaySteps)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onDestroy() {
        sensorManager.unregisterListener(this)
        scope.cancel()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun syncToServer(steps: Int) {
        scope.launch {
            try {
                val prefs = getSharedPreferences("steps", Context.MODE_PRIVATE)
                val userId = prefs.getInt("user_id", -1)
                if (userId == -1) return@launch

                val client = OkHttpClient()

                val json = JSONObject()
                json.put("steps", steps)
                json.put("clientAt", LocalDate.now().toString())

                val body = json.toString().toRequestBody("application/json".toMediaTypeOrNull())

                val req = Request.Builder()
                    .url("http://marketalert.iptime.org:8080/api/steps/today")
                    .put(body)
                    .addHeader("X-User-Id", userId.toString())
                    .build()

                client.newCall(req).execute()
                log("SERVER SYNC → steps=$steps")
            } catch (e: Exception) {
                log("SYNC ERROR → ${e.message}")
            }
        }
    }

    private fun log(msg: String) {
        println("[StepService] $msg")
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "걸음 수 추적",
                NotificationManager.IMPORTANCE_LOW
            )
            channel.enableVibration(false)
            channel.setSound(null, null)

            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(steps: Int): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("FitHouse 만보기")
            .setContentText("$steps 걸음")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun updateNotification(steps: Int) {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, buildNotification(steps))
    }
}
