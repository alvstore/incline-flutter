package com.incline.incline_app

import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.permission.PermissionController
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.HeartRateVariabilityRmssdRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.lifecycle.lifecycleScope
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

class MainActivity : FlutterFragmentActivity() {
    private val healthChannelName = "com.incline/native_health"
    private var pendingHealthPermissionResult: MethodChannel.Result? = null

    private val requestedHealthPermissions = setOf(
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
        HealthPermission.getReadPermission(ExerciseSessionRecord::class),
        HealthPermission.getReadPermission(HeartRateRecord::class),
        HealthPermission.getReadPermission(HeartRateVariabilityRmssdRecord::class),
        HealthPermission.getReadPermission(SleepSessionRecord::class),
    )

    private val healthPermissionLauncher: ActivityResultLauncher<Set<String>> =
        registerForActivityResult(PermissionController.createRequestPermissionResultContract()) { granted ->
            pendingHealthPermissionResult?.success(granted.any { it in requestedHealthPermissions })
            pendingHealthPermissionResult = null
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, healthChannelName)
            .setMethodCallHandler(::handleHealthMethodCall)
    }

    private fun handleHealthMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isHealthDataAvailable" -> result.success(isHealthConnectAvailable())
            "requestPermissions" -> requestHealthPermissions(result)
            "readDailyMetrics" -> readDailyHealthMetrics(result)
            else -> result.notImplemented()
        }
    }

    private fun isHealthConnectAvailable(): Boolean = try {
        HealthConnectClient.getSdkStatus(this) == HealthConnectClient.SDK_AVAILABLE
    } catch (_: Exception) {
        false
    }

    private fun requestHealthPermissions(result: MethodChannel.Result) {
        if (!isHealthConnectAvailable()) {
            result.success(false)
            return
        }

        lifecycleScope.launch {
            try {
                val client = HealthConnectClient.getOrCreate(this@MainActivity)
                val alreadyGranted = client.permissionController.getGrantedPermissions()
                if (alreadyGranted.containsAll(requestedHealthPermissions)) {
                    result.success(true)
                } else {
                    pendingHealthPermissionResult = result
                    healthPermissionLauncher.launch(requestedHealthPermissions)
                }
            } catch (_: Exception) {
                result.success(false)
            }
        }
    }

    private fun readDailyHealthMetrics(result: MethodChannel.Result) {
        if (!isHealthConnectAvailable()) {
            result.success(emptyMap<String, Any>())
            return
        }

        lifecycleScope.launch {
            try {
                val client = HealthConnectClient.getOrCreate(this@MainActivity)
                val granted = client.permissionController.getGrantedPermissions()
                val now = Instant.now()
                val zone = ZoneId.systemDefault()
                val startOfDay = LocalDate.now(zone).atStartOfDay(zone).toInstant()
                val last24Hours = now.minus(Duration.ofHours(24))

                var steps: Int? = null
                if (HealthPermission.getReadPermission(StepsRecord::class) in granted) {
                    val aggregate = client.aggregate(
                        AggregateRequest(
                            metrics = setOf(StepsRecord.COUNT_TOTAL),
                            timeRangeFilter = TimeRangeFilter.between(startOfDay, now),
                        ),
                    )
                    steps = aggregate[StepsRecord.COUNT_TOTAL]?.toInt()
                }

                var activeCalories: Int? = null
                if (HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class) in granted) {
                    val aggregate = client.aggregate(
                        AggregateRequest(
                            metrics = setOf(ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL),
                            timeRangeFilter = TimeRangeFilter.between(startOfDay, now),
                        ),
                    )
                    activeCalories = aggregate[ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL]
                        ?.inKilocalories?.roundToInt()
                }

                var workoutMinutes: Int? = null
                if (HealthPermission.getReadPermission(ExerciseSessionRecord::class) in granted) {
                    val sessions = client.readRecords<ExerciseSessionRecord>(
                        ReadRecordsRequest(
                            timeRangeFilter = TimeRangeFilter.between(startOfDay, now),
                            pageSize = 1000,
                        ),
                    ).records
                    val intervals = sessions.mapNotNull { session ->
                        clippedInterval(session.startTime, session.endTime, startOfDay, now)
                    }
                    workoutMinutes = (mergedDurationSeconds(intervals) / 60L).toInt()
                }

                var heartRate: Int? = null
                var heartRateRecordedAt: Instant? = null
                if (HealthPermission.getReadPermission(HeartRateRecord::class) in granted) {
                    val records = client.readRecords<HeartRateRecord>(
                        ReadRecordsRequest(
                            timeRangeFilter = TimeRangeFilter.between(last24Hours, now),
                            ascendingOrder = false,
                            pageSize = 1000,
                        ),
                    ).records
                    val latest = records.asSequence()
                        .flatMap { it.samples.asSequence() }
                        .maxByOrNull { it.time }
                    heartRate = latest?.beatsPerMinute?.toInt()
                    heartRateRecordedAt = latest?.time
                }

                var hrv: Double? = null
                var hrvRecordedAt: Instant? = null
                if (HealthPermission.getReadPermission(HeartRateVariabilityRmssdRecord::class) in granted) {
                    val records = client.readRecords<HeartRateVariabilityRmssdRecord>(
                        ReadRecordsRequest(
                            timeRangeFilter = TimeRangeFilter.between(last24Hours, now),
                            ascendingOrder = false,
                            pageSize = 1000,
                        ),
                    ).records
                    val latest = records.maxByOrNull { it.time }
                    hrv = latest?.heartRateVariabilityMillis
                    hrvRecordedAt = latest?.time
                }

                var sleepHours: Double? = null
                if (HealthPermission.getReadPermission(SleepSessionRecord::class) in granted) {
                    val sessions = client.readRecords<SleepSessionRecord>(
                        ReadRecordsRequest(
                            timeRangeFilter = TimeRangeFilter.between(last24Hours, now),
                            pageSize = 1000,
                        ),
                    ).records
                    val asleepTypes = setOf(
                        SleepSessionRecord.STAGE_TYPE_SLEEPING,
                        SleepSessionRecord.STAGE_TYPE_LIGHT,
                        SleepSessionRecord.STAGE_TYPE_DEEP,
                        SleepSessionRecord.STAGE_TYPE_REM,
                    )
                    val intervals = sessions.flatMap { session ->
                        val stages = session.stages.filter { it.stage in asleepTypes }
                        if (stages.isEmpty()) {
                            listOfNotNull(clippedInterval(session.startTime, session.endTime, last24Hours, now))
                        } else {
                            stages.mapNotNull { stage ->
                                clippedInterval(stage.startTime, stage.endTime, last24Hours, now)
                            }
                        }
                    }
                    val seconds = mergedDurationSeconds(intervals)
                    if (seconds > 0) sleepHours = seconds / 3600.0
                }

                val values = mutableMapOf<String, Any>(
                    "hasStepsData" to (steps != null),
                    "hasCaloriesData" to (activeCalories != null),
                    "hasWorkoutData" to (workoutMinutes != null),
                    "hasHeartRateData" to (heartRate != null),
                    "hasHrvData" to (hrv != null),
                    "hasSleepData" to (sleepHours != null),
                    // A permission connection remains connected before its first record arrives.
                    "hasData" to granted.any { it in requestedHealthPermissions },
                )
                steps?.let { values["steps"] = it }
                activeCalories?.let { values["activeCalories"] = it }
                workoutMinutes?.let { values["workoutMinutes"] = it }
                heartRate?.let { values["heartRate"] = it }
                heartRateRecordedAt?.let { values["heartRateRecordedAt"] = it.toString() }
                hrv?.let { values["heartRateVariabilityMs"] = it }
                hrvRecordedAt?.let { values["heartRateVariabilityRecordedAt"] = it.toString() }
                sleepHours?.let { values["sleepHours"] = it }
                result.success(values)
            } catch (_: SecurityException) {
                // Health access can be revoked while the app is open.
                result.success(emptyMap<String, Any>())
            } catch (_: Exception) {
                result.error("health_read_failed", "Health data could not be read.", null)
            }
        }
    }

    private fun clippedInterval(
        start: Instant,
        end: Instant,
        rangeStart: Instant,
        rangeEnd: Instant,
    ): Pair<Instant, Instant>? {
        val clippedStart = maxOf(start, rangeStart)
        val clippedEnd = minOf(end, rangeEnd)
        return if (clippedStart < clippedEnd) clippedStart to clippedEnd else null
    }

    private fun mergedDurationSeconds(intervals: List<Pair<Instant, Instant>>): Long {
        val sorted = intervals.sortedBy { it.first }
        if (sorted.isEmpty()) return 0

        var currentStart = sorted.first().first
        var currentEnd = sorted.first().second
        var totalSeconds = 0L
        for ((start, end) in sorted.drop(1)) {
            if (start <= currentEnd) {
                currentEnd = maxOf(currentEnd, end)
            } else {
                totalSeconds += Duration.between(currentStart, currentEnd).seconds
                currentStart = start
                currentEnd = end
            }
        }
        return totalSeconds + Duration.between(currentStart, currentEnd).seconds
    }
}
