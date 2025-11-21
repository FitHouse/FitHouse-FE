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

class StepService : Service(), SensorEventListener {

    private val CHANNEL_ID = "fit_step_channel"
    private val NOTIFICATION_ID = 1001

    private lateinit var sensorManager: SensorManager
    private var stepCounter: Sensor? = null

    private lateinit var prefs: android.content.SharedPreferences

    private var baseline = 0         // 오늘 하루 시작 지점
    private var todaySteps = 0       // 오늘 걸음
    private var lastDate = ""

    override fun onCreate() {
        super.onCreate()

        prefs = getSharedPreferences("steps", Context.MODE_PRIVATE)

        baseline = prefs.getInt("baseline", -1)
        todaySteps = prefs.getInt("todaySteps", 0)
        lastDate = prefs.getString("date", "") ?: ""

        val serverToday = prefs.getInt("serverToday", -1)

        // 앱 재시작 시 서버 값 적용
        if (serverToday >= 0 && todaySteps == 0) {
            todaySteps = serverToday
        }

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

        // 자정이면 초기화
        if (lastDate != todayStr) {
            baseline = cumulative
            todaySteps = 0
            lastDate = todayStr

            prefs.edit()
                .putString("date", todayStr)
                .putInt("baseline", baseline)
                .putInt("todaySteps", 0)
                .apply()

            updateNotification(0)
            return
        }

        val serverToday = prefs.getInt("serverToday", -1)

        // 오늘 첫 이벤트라면 baseline 강제 설정
        if (!prefs.getBoolean("baseline_initialized", false)) {

            baseline = if (serverToday >= 0) {
                cumulative - serverToday   // 서버값에서 이어가기
            } else {
                cumulative                 // 서버값 없으면 당일 0부터
            }

            if (baseline < 0) baseline = cumulative

            prefs.edit()
                .putInt("baseline", baseline)
                .putBoolean("baseline_initialized", true)
                .apply()
        }

        // 오늘 누적 계산
        val diff = cumulative - baseline
        todaySteps = if (diff >= 0) diff else 0

        // 절대 baseline 보정 금지 → 값 튐/리셋 방지

        prefs.edit()
            .putInt("todaySteps", todaySteps)
            .putString("date", todayStr)
            .apply()

        updateNotification(todaySteps)
        println("cumulative=$cumulative | baseline=$baseline | serverToday=$serverToday | todaySteps=$todaySteps")

    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onDestroy() {
        sensorManager.unregisterListener(this)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    // 📌 Notification Channel
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
            .setSilent(true)
            .build()
    }

    private fun updateNotification(steps: Int) {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, buildNotification(steps))
    }
}
