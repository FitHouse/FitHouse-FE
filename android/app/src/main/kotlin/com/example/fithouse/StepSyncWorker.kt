package com.example.fithouse

import android.content.Context
import android.content.SharedPreferences
import androidx.work.Worker
import androidx.work.WorkerParameters
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.time.LocalDateTime

class StepSyncWorker(appContext: Context, workerParams: WorkerParameters) :
    Worker(appContext, workerParams) {

    override fun doWork(): Result {
        val prefs: SharedPreferences = applicationContext.getSharedPreferences("step_prefs", Context.MODE_PRIVATE)
        val lastCumulative = prefs.getInt("last_cumulative", -1)
        val lastDate = prefs.getString("last_date", null)

        if (lastCumulative == -1 || lastDate == null) {
            return Result.success()
        }

        // 서버 전송
        val client = OkHttpClient()
        val json = JSONObject()
        json.put("steps", lastCumulative) // 또는 현재 센서 값 계산
        json.put("clientAt", LocalDateTime.now().toString())

        val body = json.toString().toRequestBody("application/json".toMediaTypeOrNull())

        val request = Request.Builder()
            .url("http://marketalert.iptime.org:8080/api/steps/today")
            .put(body)
            .addHeader("Content-Type", "application/json")
            // TODO: Authorization 헤더 추가
            .build()

        val response = client.newCall(request).execute()
        if (response.isSuccessful) {
            return Result.success()
        }

        return Result.retry()
    }
}
