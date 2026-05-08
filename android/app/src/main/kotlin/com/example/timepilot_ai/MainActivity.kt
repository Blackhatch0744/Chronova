package com.example.timepilot_ai

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Process
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class MainActivity : FlutterActivity() {
    private val channelName = "timepilot_ai/usage_stats"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasUsageAccess" -> {
                    result.success(hasUsageAccess())
                }

                "getTodayUsageStats" -> {
                    result.success(getTodayUsageStats())
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun hasUsageAccess(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager

        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            packageName
        )

        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun getTodayUsageStats(): List<Map<String, Any>> {
        if (!hasUsageAccess()) return emptyList()

        val usageStatsManager =
            getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

        val calendar = Calendar.getInstance()

        val endTime = System.currentTimeMillis()

        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)

        val startTime = calendar.timeInMillis

        val usageEvents = usageStatsManager.queryEvents(startTime, endTime)

        val event = UsageEvents.Event()

        val foregroundStartMap = mutableMapOf<String, Long>()
        val totalUsageMap = mutableMapOf<String, Long>()

        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)

            val packageName = event.packageName ?: continue
            val eventTime = event.timeStamp

            when (event.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND,
                UsageEvents.Event.ACTIVITY_RESUMED -> {
                    foregroundStartMap[packageName] = eventTime
                }

                UsageEvents.Event.MOVE_TO_BACKGROUND,
                UsageEvents.Event.ACTIVITY_PAUSED -> {
                    val start = foregroundStartMap[packageName]

                    if (start != null && eventTime > start) {
                        val duration = eventTime - start
                        totalUsageMap[packageName] =
                            (totalUsageMap[packageName] ?: 0L) + duration

                        foregroundStartMap.remove(packageName)
                    }
                }
            }
        }

        // If an app is still open right now, count its usage until current time.
        for ((packageName, start) in foregroundStartMap) {
            if (endTime > start) {
                val duration = endTime - start
                totalUsageMap[packageName] =
                    (totalUsageMap[packageName] ?: 0L) + duration
            }
        }

        val pm = packageManager

        return totalUsageMap.entries
            .mapNotNull { entry ->
                val packageName = entry.key
                val durationMinutes = (entry.value / 60000).toInt()

                if (durationMinutes <= 0) return@mapNotNull null

                val appName = try {
                    val appInfo = pm.getApplicationInfo(
                        packageName,
                        PackageManager.GET_META_DATA
                    )
                    pm.getApplicationLabel(appInfo).toString()
                } catch (e: Exception) {
                    packageName.substringAfterLast(".")
                }

                mapOf(
                    "packageName" to packageName,
                    "appName" to appName,
                    "durationMinutes" to durationMinutes
                )
            }
            .sortedByDescending { it["durationMinutes"] as Int }
            .take(10)
    }
}