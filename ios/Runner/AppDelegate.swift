import Flutter
import HealthKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let healthStore = HKHealthStore()
  private let healthChannelName = "com.incline/native_health"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let didFinish = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: healthChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self else {
          result(FlutterError(code: "health_unavailable", message: "Health service is unavailable.", details: nil))
          return
        }

        switch call.method {
        case "isHealthDataAvailable":
          result(HKHealthStore.isHealthDataAvailable())
        case "requestPermissions":
          self.requestHealthPermissions(result: result)
        case "readDailyMetrics":
          self.readDailyMetrics(result: result)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return didFinish
  }

  private func requestHealthPermissions(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      result(false)
      return
    }

    var readTypes = Set<HKObjectType>()
    let identifiers: [HKQuantityTypeIdentifier] = [
      .stepCount,
      .activeEnergyBurned,
      .heartRate,
      .heartRateVariabilitySDNN,
      .appleExerciseTime,
    ]
    for identifier in identifiers {
      if let type = HKObjectType.quantityType(forIdentifier: identifier) {
        readTypes.insert(type)
      }
    }
    if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
      readTypes.insert(sleepType)
    }
    healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
      DispatchQueue.main.async {
        result(success && error == nil)
      }
    }
  }

  private func readDailyMetrics(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      result([:])
      return
    }

    Task {
      do {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)
        let calorieType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)
        let exerciseType = HKObjectType.quantityType(forIdentifier: .appleExerciseTime)
        let heartType = HKObjectType.quantityType(forIdentifier: .heartRate)
        let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)

        let steps: Double?
        if let stepType {
          steps = try await summedQuantity(stepType, unit: .count(), start: startOfDay, end: now)
        } else {
          steps = nil
        }
        let calories: Double?
        if let calorieType {
          calories = try await summedQuantity(calorieType, unit: .kilocalorie(), start: startOfDay, end: now)
        } else {
          calories = nil
        }
        let exerciseMinutes: Double?
        if let exerciseType {
          exerciseMinutes = try await summedQuantity(exerciseType, unit: .minute(), start: startOfDay, end: now)
        } else {
          exerciseMinutes = nil
        }

        let latestHeartRate: (value: Double, date: Date)?
        if let heartType {
          latestHeartRate = try await latestHeartRateSample(
            heartType,
            start: Calendar.current.date(byAdding: .hour, value: -24, to: now) ?? startOfDay,
            end: now
          )
        } else {
          latestHeartRate = nil
        }

        let latestHRV: (value: Double, date: Date)?
        if let hrvType {
          latestHRV = try await latestQuantitySample(
            hrvType,
            unit: HKUnit.secondUnit(with: .milli),
            start: Calendar.current.date(byAdding: .hour, value: -24, to: now) ?? startOfDay,
            end: now
          )
        } else {
          latestHRV = nil
        }

        let sleepSeconds = try await readSleepSeconds(
          start: Calendar.current.date(byAdding: .hour, value: -24, to: now) ?? startOfDay,
          end: now
        )

        var values: [String: Any] = [
          "hasStepsData": steps != nil,
          "hasCaloriesData": calories != nil,
          "hasWorkoutData": exerciseMinutes != nil,
          "hasHeartRateData": latestHeartRate != nil,
          "hasHrvData": latestHRV != nil,
          "hasSleepData": sleepSeconds > 0,
          "hasData": steps != nil || calories != nil || exerciseMinutes != nil ||
            latestHeartRate != nil || latestHRV != nil || sleepSeconds > 0,
        ]
        if let steps { values["steps"] = Int(steps.rounded()) }
        if let calories { values["activeCalories"] = Int(calories.rounded()) }
        if let exerciseMinutes { values["workoutMinutes"] = Int(exerciseMinutes.rounded()) }
        if let latestHeartRate {
          values["heartRate"] = Int(latestHeartRate.value.rounded())
          values["heartRateRecordedAt"] = ISO8601DateFormatter().string(from: latestHeartRate.date)
        }
        if let latestHRV {
          values["heartRateVariabilityMs"] = latestHRV.value
          values["heartRateVariabilityRecordedAt"] = ISO8601DateFormatter().string(from: latestHRV.date)
        }
        if sleepSeconds > 0 {
          values["sleepHours"] = sleepSeconds / 3600.0
        }

        DispatchQueue.main.async {
          result(values)
        }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "health_read_failed",
            message: "Health data could not be read.",
            details: String(describing: type(of: error))
          ))
        }
      }
    }
  }

  private func summedQuantity(
    _ type: HKQuantityType,
    unit: HKUnit,
    start: Date,
    end: Date
  ) async throws -> Double? {
    try await withCheckedThrowingContinuation { continuation in
      let predicate = HKQuery.predicateForSamples(
        withStart: start,
        end: end,
        options: .strictStartDate
      )
      let query = HKStatisticsQuery(
        quantityType: type,
        quantitySamplePredicate: predicate,
        options: .cumulativeSum
      ) { _, statistics, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: unit))
        }
      }
      healthStore.execute(query)
    }
  }

  private func latestHeartRateSample(
    _ type: HKQuantityType,
    start: Date,
    end: Date
  ) async throws -> (value: Double, date: Date)? {
    try await withCheckedThrowingContinuation { continuation in
      let predicate = HKQuery.predicateForSamples(
        withStart: start,
        end: end,
        options: .strictStartDate
      )
      let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
      let query = HKSampleQuery(
        sampleType: type,
        predicate: predicate,
        limit: 1,
        sortDescriptors: [sort]
      ) { _, samples, error in
        if let error {
          continuation.resume(throwing: error)
          return
        }
        guard let sample = samples?.first as? HKQuantitySample else {
          continuation.resume(returning: nil)
          return
        }
        let unit = HKUnit.count().unitDivided(by: HKUnit.minute())
        continuation.resume(returning: (sample.quantity.doubleValue(for: unit), sample.endDate))
      }
      healthStore.execute(query)
    }
  }

  private func latestQuantitySample(
    _ type: HKQuantityType,
    unit: HKUnit,
    start: Date,
    end: Date
  ) async throws -> (value: Double, date: Date)? {
    try await withCheckedThrowingContinuation { continuation in
      let predicate = HKQuery.predicateForSamples(
        withStart: start,
        end: end,
        options: .strictStartDate
      )
      let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
      let query = HKSampleQuery(
        sampleType: type,
        predicate: predicate,
        limit: 1,
        sortDescriptors: [sort]
      ) { _, samples, error in
        if let error {
          continuation.resume(throwing: error)
          return
        }
        guard let sample = samples?.first as? HKQuantitySample else {
          continuation.resume(returning: nil)
          return
        }
        continuation.resume(returning: (sample.quantity.doubleValue(for: unit), sample.endDate))
      }
      healthStore.execute(query)
    }
  }

  private func readSleepSeconds(start: Date, end: Date) async throws -> Double {
    guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
      return 0
    }

    let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
      let predicate = HKQuery.predicateForSamples(
        withStart: start,
        end: end,
        options: .strictStartDate
      )
      let query = HKSampleQuery(
        sampleType: type,
        predicate: predicate,
        limit: HKObjectQueryNoLimit,
        sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
      ) { _, samples, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
        }
      }
      healthStore.execute(query)
    }

    var asleepValues: Set<Int> = [HKCategoryValueSleepAnalysis.asleep.rawValue]
    if #available(iOS 16.0, *) {
      asleepValues.formUnion([
        HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
        HKCategoryValueSleepAnalysis.asleepCore.rawValue,
        HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
        HKCategoryValueSleepAnalysis.asleepREM.rawValue,
      ])
    }

    let intervals = samples
      .filter { asleepValues.contains($0.value) }
      .map { (max($0.startDate, start), min($0.endDate, end)) }
      .filter { $0.0 < $0.1 }
      .sorted { $0.0 < $1.0 }

    guard var current = intervals.first else { return 0 }
    var total: TimeInterval = 0
    for interval in intervals.dropFirst() {
      if interval.0 <= current.1 {
        current.1 = max(current.1, interval.1)
      } else {
        total += current.1.timeIntervalSince(current.0)
        current = interval
      }
    }
    total += current.1.timeIntervalSince(current.0)
    return total
  }

}
