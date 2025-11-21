package com.codechip.fithouse

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

    companion object {
        fun sendImmediateSync(context: Context) {
            val prefs = context.getSharedPreferences("step_prefs", Context.MODE_PRIVATE)
            val last = prefs.getInt("last_cumulative", -1)

            if (last == -1) return

            Thread {
                try {
                    val client = OkHttpClient()
                    val json = JSONObject()
                    json.put("steps", last)
                    json.put("clientAt", LocalDateTime.now().toString())

                    val body = json.toString()
                        .toRequestBody("application/json".toMediaTypeOrNull())

                    val request = Request.Builder()
                        .url("http://marketalert.iptime.org:8080/api/steps/today")
                        .put(body)
                        .addHeader("Content-Type", "application/json")
                        .build()

                    client.newCall(request).execute()
                } catch (_: Exception) {}
            }.start()
        }
    }

    override fun doWork(): Result {
        sendImmediateSync(applicationContext)
        return Result.success()
    }
}
