#if os(iOS)
import BackgroundTasks
import Foundation
import UserNotifications
import WidgetKit

/// Gathers today's inputs from the store, runs `PlanEngine`, publishes the result for the Plan widget and
/// keeps the 07:00 morning notification up to date. Called from the same hooks that refresh the glance
/// widget (foreground, data refresh, app exit) and from its own early-morning background refresh.
@MainActor
enum PlanPublisher {
    static let widgetKind = "PlanWidget"
    static let morningEnabledKey = "rick.plan.morningEnabled"
    private static let kcalBaseKey = "rick.plan.kcalBase"
    private static let kcalAdjustDayKey = "rick.plan.kcalAdjustDay"
    private static let kcalReasonKey = "rick.plan.kcalReason"

    static var kcalBase: Int {
        let v = UserDefaults.standard.integer(forKey: kcalBaseKey)
        return v > 0 ? v : FitnessPlan.baseKcal
    }
    static var lastKcalReason: String? { UserDefaults.standard.string(forKey: kcalReasonKey) }

    @discardableResult
    static func publish(from model: AppModel, now: Date = Date()) async -> PlanAdvice {
        await WithingsSync.syncIfDue(model: model)

        let repo = model.repo
        let days = repo.days
        let anchor = Repository.widgetAnchor(days: days, now: now)

        // HRV: tonight vs the 7 nights before it, plus how many nights in a row sat >15 % under.
        let hrvDays = days.filter { $0.avgHrv != nil }
        var hrvAvg7: Double?
        var lowStreak = 0
        if let a = anchor, let idx = hrvDays.lastIndex(where: { $0.day == a.day }) {
            let prior = hrvDays[max(0, idx - 7)..<idx].compactMap(\.avgHrv)
            if !prior.isEmpty { hrvAvg7 = prior.reduce(0, +) / Double(prior.count) }
            var i = idx
            while i >= 1 {
                let window = hrvDays[max(0, i - 7)..<i].compactMap(\.avgHrv)
                guard let v = hrvDays[i].avgHrv, window.count >= 3 else { break }
                let mean = window.reduce(0, +) / Double(window.count)
                if v < mean * 0.85 { lowStreak += 1; i -= 1 } else { break }
            }
        }

        let yesterdayKey = Repository.localDayKey(now.addingTimeInterval(-86_400))
        let strainY = days.last(where: { $0.day == yesterdayKey })?.strain
            .map { UnitFormatter.effortValue($0, scale: .whoop) }

        let weightRows = await repo.series(key: "weight", source: Repository.appleHealthSource, days: 42)
        let weights = weightRows.map { WeightPoint(day: $0.day, kg: $0.value) }
        let fat = await repo.series(key: "body_fat", source: Repository.appleHealthSource, days: 42).last?.value

        // Weekly calorie step (±150 kcal) from the weight trend.
        let todayKey = FitnessPlan.dayKey(now)
        let adjusted = PlanEngine.adjustBase(current: kcalBase, weights: weights,
                                             lastAdjustDay: UserDefaults.standard.string(forKey: kcalAdjustDayKey),
                                             todayKey: todayKey)
        if adjusted.kcal != kcalBase {
            UserDefaults.standard.set(adjusted.kcal, forKey: kcalBaseKey)
            UserDefaults.standard.set(todayKey, forKey: kcalAdjustDayKey)
            UserDefaults.standard.set(adjusted.reason, forKey: kcalReasonKey)
        }

        let inputs = PlanInputs(
            recovery: anchor?.recovery, sleepMin: anchor?.totalSleepMin, hrvToday: anchor?.avgHrv,
            hrvAvg7: hrvAvg7, hrvLowStreak: lowStreak, strainYesterday21: strainY,
            weights: weights, bodyFatPct: fat, kcalBase: kcalBase)
        var advice = PlanEngine.advice(for: now, inputs: inputs, now: now)
        if let r = adjusted.reason {
            advice.notes.insert(r, at: 0)
        }

        let previous = PlanSnapshotStore.load()
        PlanSnapshotStore.save(advice)
        if previous.map({ !sameRendered($0, advice) }) ?? true {
            WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        }
        PlanNotifier.reschedule(today: advice, inputs: inputs, now: now)
        return advice
    }

    private static func sameRendered(_ a: PlanAdvice, _ b: PlanAdvice) -> Bool {
        var a = a, b = b
        a.generatedAt = .distantPast; b.generatedAt = .distantPast
        return a == b
    }
}

/// The 07:00 morning message. iOS can't compute content at fire time, so the pending request always
/// carries the freshest advice we have: before 07:00 it is today's (the overnight strap sync and the
/// 06:15 background refresh both republish), after 07:00 it is tomorrow's plan without recovery yet.
@MainActor
enum PlanNotifier {
    static let requestId = "rick.plan.morning"
    static let category = "rick.plan"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: PlanPublisher.morningEnabledKey) as? Bool ?? true
    }

    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .denied: return false
        default: return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        }
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [requestId])
    }

    static func reschedule(today: PlanAdvice, inputs: PlanInputs, now: Date) {
        guard isEnabled else { cancel(); return }
        let cal = Calendar.current
        guard let todayFire = cal.date(bySettingHour: FitnessPlan.morningHour, minute: 0, second: 0, of: now) else { return }
        let fire: Date
        let advice: PlanAdvice
        if now < todayFire {
            fire = todayFire
            advice = today
        } else {
            fire = cal.date(byAdding: .day, value: 1, to: todayFire) ?? todayFire.addingTimeInterval(86_400)
            var tomorrowInputs = inputs
            tomorrowInputs.recovery = nil; tomorrowInputs.sleepMin = nil; tomorrowInputs.strainYesterday21 = nil
            advice = PlanEngine.advice(for: fire, inputs: tomorrowInputs, now: now)
        }

        let content = UNMutableNotificationContent()
        content.title = "\(advice.weekdayShort): \(advice.trainingTitle) · \(advice.headline)"
        var lines = [advice.trainingNote,
                     "Ziel \(advice.kcalTarget) kcal · \(advice.proteinG) g Protein",
                     "Abends: \(advice.dinner)"]
        if let w = advice.weightAvg7 { lines.insert(String(format: "Gewicht Ø7: %.1f kg", w), at: 0) }
        lines.append(contentsOf: advice.notes.prefix(2))
        content.body = lines.joined(separator: "\n")
        content.sound = .default
        content.categoryIdentifier = category

        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [requestId])
        center.add(UNNotificationRequest(identifier: requestId, content: content, trigger: trigger))
    }
}

/// Early-morning wake (≈06:15) so the 07:00 message already reflects last night's recovery even when the
/// app wasn't opened. Best effort: iOS decides when a refresh really runs.
@MainActor
enum PlanBackgroundScheduler {
    static let taskIdentifier = (Bundle.main.bundleIdentifier ?? "com.noopapp.noop") + ".plan"

    static func register(perform operation: @escaping @MainActor () async -> Void) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            let guardBox = CompletionGuard(task: task)
            let worker = Task { @MainActor in
                schedule()
                await operation()
                guard !Task.isCancelled else { return }
                guardBox.finish(success: true)
            }
            task.expirationHandler = {
                worker.cancel()
                guardBox.finish(success: false)
            }
        }
    }

    static func schedule(now: Date = Date()) {
        let cal = Calendar.current
        guard var next = cal.date(bySettingHour: 6, minute: 15, second: 0, of: now) else { return }
        if next <= now { next = cal.date(byAdding: .day, value: 1, to: next) ?? next.addingTimeInterval(86_400) }
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = next
        try? BGTaskScheduler.shared.submit(request)
    }

    private final class CompletionGuard: @unchecked Sendable {
        private let task: BGTask
        private let lock = NSLock()
        private var finished = false
        init(task: BGTask) { self.task = task }
        func finish(success: Bool) {
            lock.lock(); defer { lock.unlock() }
            guard !finished else { return }
            finished = true
            task.setTaskCompleted(success: success)
            task.expirationHandler = nil
        }
    }
}
#endif
