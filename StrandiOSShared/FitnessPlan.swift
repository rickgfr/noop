import Foundation

// MARK: - Rick's cut plan (personal fork)
//
// Pure, Foundation-only model shared by the app and the widget extension: the weekly training split,
// the meal plan, and the rule engine that adapts the day to recovery, sleep, HRV and the weight trend.
// No store, no UIKit, no network — the app gathers the inputs (PlanPublisher) and the widget only reads
// the published `PlanSnapshot` from the App Group.

public enum PlanReadiness: String, Codable, Equatable, Sendable {
    case green, yellow, red, unknown
}

public struct PlanDay: Codable, Equatable, Sendable {
    /// Calendar weekday, 1 = Sunday … 7 = Saturday (Gregorian `Calendar.component(.weekday)`).
    public let weekday: Int
    public let short: String
    public let code: String
    public let trainingTitle: String
    public let isStrength: Bool
    public let exercises: [String]
    public let lunch: String
    public let dinner: String
}

public enum FitnessPlan {
    public static let startWeightKg = 103.0
    public static let goalWeightKg = 88.0
    public static let baseKcal = 2100
    public static let maintenanceKcal = 2850
    public static let proteinG = 180
    public static let fatG = 65
    public static let morningHour = 7
    public static let trainingTime = "16:00"

    public static let breakfast = "250 g Skyr, 40 g Haferflocken, Beeren, 1 EL Erdnussbutter"
    public static let snack = "Whey-Shake + Banane"

    /// USA trip: diet break on maintenance calories (inclusive day keys).
    public static let dietBreakFrom = "2026-12-20"
    public static let dietBreakTo = "2027-01-03"

    public static let rules: [String] = [
        "1–2 RIR, Pausen 2–3 min Grundübungen / 90 s Isolation, Gewichte loggen.",
        "8–10k Schritte am Tag, Cardio nur locker.",
        "Kein Lachs, kein Brokkoli. Mittag Meal Prep, abends frisch kochen.",
    ]

    public static let week: [PlanDay] = [
        PlanDay(weekday: 2, short: "Mo", code: "Frei", trainingTitle: "Ruhetag", isStrength: false,
                exercises: ["8–10k Schritte"],
                lunch: "Thunfisch-Wrap (1 Dose Thunfisch, Kidneybohnen, Mais, 1 VK-Wrap, Skyr-Dip)",
                dinner: "200 g Hähnchenbrust mit Ofengemüse (Paprika, Zucchini, Zwiebel) + 150 g Hüttenkäse"),
        PlanDay(weekday: 3, short: "Di", code: "OK-A", trainingTitle: "Oberkörper A", isStrength: true,
                exercises: ["Bankdrücken 4×6–8", "LH-Rudern 4×6–8", "KH-Schulterdrücken 3×8–10", "Latzug 3×10",
                            "Seitheben 3×15", "Trizeps Kabel 3×12", "KH-Curls 3×12"],
                lunch: "Chili con Carne (Meal Prep)",
                dinner: "180 g Hüftsteak, 300 g Ofenkartoffeln, 200 g grüne Bohnen, 150 g Magerquark"),
        PlanDay(weekday: 4, short: "Mi", code: "UK-A", trainingTitle: "Unterkörper A", isStrength: true,
                exercises: ["Kniebeuge 4×6–8", "RDL 3×8–10", "Beinpresse 3×10–12", "Beinbeuger 3×12",
                            "Wadenheben 4×12–15", "Plank 3×45 s"],
                lunch: "Chili con Carne (Meal Prep)",
                dinner: "Puten-Wraps (2 VK-Wraps, 180 g Pute, Salat, Skyr-Knoblauch-Soße), danach Curry vorkochen"),
        PlanDay(weekday: 5, short: "Do", code: "Cardio", trainingTitle: "Cardio locker", isStrength: false,
                exercises: ["30–45 min locker (Rad, Laufband schräg, Spaziergang)", "8–10k Schritte"],
                lunch: "Hähnchen-Curry (Meal Prep)",
                dinner: "Shakshuka (3 Eier + 150 g Eiklar), 1 Scheibe VK-Brot, 150 g Hüttenkäse"),
        PlanDay(weekday: 6, short: "Fr", code: "OK-B", trainingTitle: "Oberkörper B", isStrength: true,
                exercises: ["Schrägbank KH 4×8–10", "Klimmzüge/Latzug eng 4×6–10", "Kabelrudern 3×10–12",
                            "Dips/Brustpresse 3×10", "Face Pulls 3×15", "Hammer-Curls 3×12", "Overhead-Trizeps 3×12"],
                lunch: "Hähnchen-Curry (Meal Prep)",
                dinner: "Bolognese (80 g VK-Nudeln, 150 g Rinderhack 5 %, Passata, 15 g Parmesan)"),
        PlanDay(weekday: 7, short: "Sa", code: "UK-B", trainingTitle: "Unterkörper B", isStrength: true,
                exercises: ["Kreuzheben 4×5", "Bulg. Split Squats 3×10/Bein", "Hip Thrust 3×10",
                            "Beinstrecker 3×12–15", "Wadenheben sitzend 4×15", "Hanging Leg Raises 3×12"],
                lunch: "Rührei (3 Eier + 100 g Eiklar), 2 Scheiben VK-Brot, Tomaten",
                dinner: "Hähnchen-Kartoffel-Pfanne (200 g Hähnchen, 250 g Kartoffeln, Paprika, Kräuterquark)"),
        PlanDay(weekday: 1, short: "So", code: "Frei", trainingTitle: "Ruhetag", isStrength: false,
                exercises: ["8–10k Schritte", "Meal Prep: Chili für Di + Mi kochen"],
                lunch: "Puten-Bowl (180 g Pute, 70 g Reis, Mais, Paprika, Skyr-Dip)",
                dinner: "Rinderhack-Linsen-Bolognese (150 g Rinderhack 5 %, 40 g rote Linsen, 70 g VK-Nudeln)"),
    ]

    public static let shoppingList: [String] = [
        "Rinderhack 5 % (550 g)", "Hähnchenbrust (800 g)", "Putenbrust (360 g)", "Hüftsteak (180 g)",
        "Skyr (1,5 kg)", "Magerquark (500 g)", "Hüttenkäse (2×)", "Eier (10) + Eiklar (500 ml)",
        "Basmati, Haferflocken, VK-Nudeln, VK-Wraps, VK-Brot", "Kidneybohnen, Mais, Passata (2×), Kokosmilch light",
        "Paprika (4), Zucchini, TK-Erbsen, grüne Bohnen, Tomaten, Salat, Beeren, Bananen", "Whey, Erdnussbutter, Parmesan",
    ]

    /// Planned meals with rough macro estimates (editable when logged). Breakfast + snack are fixed;
    /// lunch/dinner follow the weekday. Values: (kcal, protein g).
    public static let breakfastMacros = (kcal: 445, protein: 36)
    public static let snackMacros = (kcal: 225, protein: 27)
    static let dayMacros: [Int: (lunch: (Int, Int), dinner: (Int, Int))] = [
        2: ((525, 53), (515, 67)), 3: ((600, 45), (665, 68)), 4: ((600, 45), (635, 63)),
        5: ((600, 50), (630, 58)), 6: ((600, 50), (590, 49)), 7: ((515, 36), (650, 64)),
        1: ((575, 58), (640, 51)),
    ]

    public static func plannedMeals(for date: Date) -> [PlannedMeal] {
        let d = day(for: date)
        let m = dayMacros[d.weekday] ?? ((600, 45), (650, 55))
        return [
            PlannedMeal(slot: .breakfast, name: breakfast, kcal: breakfastMacros.kcal, protein: breakfastMacros.protein),
            PlannedMeal(slot: .lunch, name: d.lunch, kcal: m.lunch.0, protein: m.lunch.1),
            PlannedMeal(slot: .snack, name: snack, kcal: snackMacros.kcal, protein: snackMacros.protein),
            PlannedMeal(slot: .dinner, name: d.dinner, kcal: m.dinner.0, protein: m.dinner.1),
        ]
    }

    public static func day(for date: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> PlanDay {
        let wd = calendar.component(.weekday, from: date)
        return week.first { $0.weekday == wd } ?? week[0]
    }

    public static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }
}

public enum MealSlot: String, Codable, CaseIterable, Sendable {
    case breakfast, lunch, snack, dinner, other
    public var label: String {
        switch self {
        case .breakfast: return "Frühstück"
        case .lunch: return "Mittag"
        case .snack: return "Snack"
        case .dinner: return "Abend"
        case .other: return "Sonstiges"
        }
    }
}

public struct PlannedMeal: Equatable, Sendable {
    public let slot: MealSlot
    public let name: String
    public let kcal: Int
    public let protein: Int
}

/// One logged day of eating: total kcal and how many entries made it up.
public struct IntakeDay: Codable, Equatable, Sendable {
    public let day: String
    public let kcal: Int
    public let protein: Int
    public init(day: String, kcal: Int, protein: Int) { self.day = day; self.kcal = kcal; self.protein = protein }
}

/// Everything the engine reads, gathered by the app. All optional: a missing strap night or a missing
/// scale reading degrades the advice instead of blocking it.
public struct PlanInputs: Equatable, Sendable {
    public var recovery: Double?          // 0–100
    public var sleepMin: Double?
    public var hrvToday: Double?          // ms
    public var hrvAvg7: Double?           // ms, the 7 nights before today
    public var hrvLowStreak: Int          // consecutive nights >15 % under their 7-night average
    public var strainYesterday21: Double? // WHOOP 0–21 scale
    public var weights: [WeightPoint]     // oldest → newest
    public var bodyFatPct: Double?
    public var kcalBase: Int

    public init(recovery: Double? = nil, sleepMin: Double? = nil, hrvToday: Double? = nil, hrvAvg7: Double? = nil,
                hrvLowStreak: Int = 0, strainYesterday21: Double? = nil, weights: [WeightPoint] = [],
                bodyFatPct: Double? = nil, kcalBase: Int = FitnessPlan.baseKcal) {
        self.recovery = recovery; self.sleepMin = sleepMin; self.hrvToday = hrvToday; self.hrvAvg7 = hrvAvg7
        self.hrvLowStreak = hrvLowStreak; self.strainYesterday21 = strainYesterday21; self.weights = weights
        self.bodyFatPct = bodyFatPct; self.kcalBase = kcalBase
    }
}

public struct WeightPoint: Codable, Equatable, Sendable {
    public let day: String
    public let kg: Double
    public init(day: String, kg: Double) { self.day = day; self.kg = kg }
}

public struct PlanAdvice: Codable, Equatable, Sendable {
    public var dayKey: String
    public var weekdayShort: String
    public var readiness: PlanReadiness
    public var headline: String
    public var trainingTitle: String
    public var trainingNote: String
    public var exercises: [String]
    public var breakfast: String
    public var snack: String
    public var lunch: String
    public var dinner: String
    public var kcalTarget: Int
    public var proteinG: Int
    public var fatG: Int
    public var notes: [String]
    public var recovery: Double?
    public var sleepHours: Double?
    public var hrv: Double?
    public var latestWeight: Double?
    public var bodyFatPct: Double?
    public var weightAvg7: Double?
    public var weeklyChange: Double?
    public var toGoal: Double?
    public var generatedAt: Date
    /// Adaptive energy model (nil until ~10 logged days with scale readings).
    public var tdeeEstimate: Int? = nil
    public var intakeAvg: Int? = nil
    public var loggedDays: Int? = nil
}

/// Energy balance read from what was eaten and how the scale moved.
public struct EnergyEstimate: Equatable, Sendable {
    public let tdee: Int          // estimated maintenance kcal/day
    public let avgIntake: Int     // mean kcal on logged days
    public let loggedDays: Int
    public let kgPerWeek: Double  // regression slope, negative = losing
}

public enum PlanEngine {
    public static func readiness(recovery: Double?, sleepMin: Double?) -> PlanReadiness {
        if let s = sleepMin, s < 360 { return .red }
        guard let r = recovery else { return .unknown }
        if r >= 67 { return .green }
        if r >= 34 { return .yellow }
        return .red
    }

    /// 7-day mean ending at the newest reading, and its change against the 7 days before it.
    public static func weightTrend(_ weights: [WeightPoint]) -> (avg7: Double?, weeklyChange: Double?) {
        let pts = weights.compactMap { p -> (Date, Double)? in
            guard let d = parseDay(p.day) else { return nil }
            return (d, p.kg)
        }.sorted { $0.0 < $1.0 }
        guard let end = pts.last?.0 else { return (nil, nil) }
        let day: TimeInterval = 86_400
        let cur = pts.filter { $0.0 > end.addingTimeInterval(-7 * day) }.map(\.1)
        let prev = pts.filter { $0.0 <= end.addingTimeInterval(-7 * day) && $0.0 > end.addingTimeInterval(-14 * day) }.map(\.1)
        let avg = cur.isEmpty ? nil : cur.reduce(0, +) / Double(cur.count)
        let prevAvg = prev.isEmpty ? nil : prev.reduce(0, +) / Double(prev.count)
        let change: Double? = (avg != nil && prevAvg != nil) ? avg! - prevAvg! : nil
        return (avg.map(round1), change.map(round1))
    }

    /// The ±150 kcal rule from the plan: judged on two weeks of 7-day means, at most one step per week.
    /// Returns the new base and a human reason when it moved.
    public static func adjustBase(current: Int, weights: [WeightPoint], lastAdjustDay: String?, todayKey: String)
        -> (kcal: Int, reason: String?) {
        if let last = lastAdjustDay, let l = parseDay(last), let t = parseDay(todayKey),
           t.timeIntervalSince(l) < 7 * 86_400 { return (current, nil) }
        let pts = weights.compactMap { p -> (Date, Double)? in parseDay(p.day).map { ($0, p.kg) } }.sorted { $0.0 < $1.0 }
        guard let first = pts.first?.0, let end = pts.last?.0, end.timeIntervalSince(first) >= 14 * 86_400 else {
            return (current, nil)
        }
        let day: TimeInterval = 86_400
        func mean(_ from: Double, _ to: Double) -> Double? {
            let v = pts.filter { $0.0 > end.addingTimeInterval(-from * day) && $0.0 <= end.addingTimeInterval(-to * day) }.map(\.1)
            return v.isEmpty ? nil : v.reduce(0, +) / Double(v.count)
        }
        guard let now = mean(7, 0), let twoWeeksAgo = mean(21, 14) else { return (current, nil) }
        let perWeek = (twoWeeksAgo - now) / 2   // positive = loss per week
        if perWeek < 0.5 {
            return (max(1700, current - 150), String(format: "Nur %.1f kg/Woche verloren → −150 kcal", perWeek))
        }
        if perWeek > 1.2 {
            return (min(2600, current + 150), String(format: "%.1f kg/Woche verloren → +150 kcal", perWeek))
        }
        return (current, nil)
    }

    /// Target loss pace for the cut (kg per week) and the energy content of body mass change.
    public static let targetLossKgPerWeek = 0.9
    public static let kcalPerKg = 7700.0
    public static let minKcal = 1700
    public static let maxKcal = 2600
    /// A day counts as logged only from this many kcal on (a half-logged day would fake a big deficit).
    public static let minLoggedKcal = 1000

    /// Maintenance estimate from the last 21 complete days: mean intake minus the energy the weight
    /// trend says was stored/burned (linear regression over the scale readings, so single water-weight
    /// spikes barely move it). Needs ≥10 logged days and ≥6 weigh-ins spanning ≥10 days.
    public static func estimateEnergy(intake: [IntakeDay], weights: [WeightPoint], todayKey: String,
                                      windowDays: Int = 21) -> EnergyEstimate? {
        guard let today = parseDay(todayKey) else { return nil }
        let day: TimeInterval = 86_400
        let from = today.addingTimeInterval(-Double(windowDays) * day)
        let logged = intake.filter { d in
            guard let t = parseDay(d.day) else { return false }
            return t >= from && t < today && d.kcal >= minLoggedKcal
        }
        guard logged.count >= 10 else { return nil }
        let avgIntake = Double(logged.map { $0.kcal }.reduce(0, +)) / Double(logged.count)

        let pts = weights.compactMap { p -> (Double, Double)? in
            guard let t = parseDay(p.day), t >= from, t <= today else { return nil }
            return (t.timeIntervalSince(from) / day, p.kg)
        }
        let xs = pts.map { $0.0 }
        let ys = pts.map { $0.1 }
        guard pts.count >= 6, let minX = xs.min(), let maxX = xs.max(), maxX - minX >= 10 else {
            return nil
        }
        let n = Double(pts.count)
        let mx = xs.reduce(0, +) / n
        let my = ys.reduce(0, +) / n
        let sxx = pts.map { ($0.0 - mx) * ($0.0 - mx) }.reduce(0, +)
        guard sxx > 0 else { return nil }
        let slopePerDay = pts.map { ($0.0 - mx) * ($0.1 - my) }.reduce(0, +) / sxx
        let tdee = avgIntake - slopePerDay * kcalPerKg
        guard tdee.isFinite, tdee > 1200, tdee < 5000 else { return nil }
        return EnergyEstimate(tdee: Int(tdee.rounded()), avgIntake: Int(avgIntake.rounded()),
                              loggedDays: logged.count, kgPerWeek: round1(slopePerDay * 7))
    }

    /// Weekly target update. With enough food logs: target = estimated maintenance − the deficit for
    /// 0.9 kg/week, approached in steps of at most ±200 kcal. Without logs: the plan's ±150 kcal rule.
    public static func adaptTarget(current: Int, weights: [WeightPoint], intake: [IntakeDay],
                                   lastAdjustDay: String?, todayKey: String)
        -> (kcal: Int, reason: String?, estimate: EnergyEstimate?) {
        let estimate = estimateEnergy(intake: intake, weights: weights, todayKey: todayKey)
        if let last = lastAdjustDay, let l = parseDay(last), let t = parseDay(todayKey),
           t.timeIntervalSince(l) < 7 * 86_400 { return (current, nil, estimate) }
        guard let e = estimate else {
            let r = adjustBase(current: current, weights: weights, lastAdjustDay: nil, todayKey: todayKey)
            return (r.kcal, r.reason, nil)
        }
        let deficit = targetLossKgPerWeek * kcalPerKg / 7
        let ideal = min(maxKcal, max(minKcal, Int((Double(e.tdee) - deficit).rounded())))
        let step = max(-200, min(200, ideal - current))
        let next = Int((Double(current + step) / 25).rounded()) * 25
        guard abs(next - current) >= 50 else { return (current, nil, e) }
        let reason = String(format: "Verbrauch ≈ %d kcal (Ø %d gegessen, %+.1f kg/Woche) → Ziel %d kcal",
                            e.tdee, e.avgIntake, e.kgPerWeek, next)
        return (next, reason, e)
    }

    public static func advice(for date: Date, inputs: PlanInputs, now: Date = Date()) -> PlanAdvice {
        let plan = FitnessPlan.day(for: date)
        let key = FitnessPlan.dayKey(date)
        let ready = readiness(recovery: inputs.recovery, sleepMin: inputs.sleepMin)
        var notes: [String] = []
        var exercises = plan.exercises
        var trainingNote: String
        var headline: String

        switch ready {
        case .green:
            headline = "Grün · voll trainieren"
            trainingNote = plan.isStrength ? "Wie geplant, 1–2 RIR. Wenn es gut läuft: Gewicht leicht steigern." : "Wie geplant."
        case .yellow:
            headline = "Gelb · normal, aber mit Reserve"
            trainingNote = plan.isStrength ? "Alle Übungen wie geplant, aber 2–3 RIR und keine Extra-Sätze." : "Locker bleiben."
        case .red:
            headline = "Rot · Volumen runter"
            if plan.isStrength {
                exercises = exercises.map(dropOneSet)
                trainingNote = "1 Satz weniger pro Übung, 3 RIR. Alternativ mit dem nächsten Ruhetag tauschen."
            } else {
                exercises = ["Nur Spaziergang, 8k Schritte"]
                trainingNote = "Heute nur locker bewegen."
            }
        case .unknown:
            headline = "Noch keine Recovery"
            trainingNote = plan.isStrength ? "Wie geplant, 1–2 RIR. Strap über Nacht tragen, dann passt NOOP die Einheit an." : "Wie geplant."
        }

        if let s = inputs.sleepMin, s < 360 {
            notes.append(String(format: "Nur %.1f h Schlaf – heute früher ins Bett.", s / 60))
        }
        if inputs.hrvLowStreak >= 2 {
            notes.append("HRV seit \(inputs.hrvLowStreak) Nächten >15 % unter Schnitt: Ruhetag oder Deload-Woche einplanen.")
        }

        var kcal = inputs.kcalBase
        let inDietBreak = key >= FitnessPlan.dietBreakFrom && key <= FitnessPlan.dietBreakTo
        if inDietBreak {
            kcal = FitnessPlan.maintenanceKcal
            notes.append("Diet Break (USA): Erhaltung ~\(FitnessPlan.maintenanceKcal) kcal, Protein hoch halten.")
        } else if let st = inputs.strainYesterday21, st > 15 {
            kcal += 125
            notes.append(String(format: "Strain gestern %.1f → heute +125 kcal Kohlenhydrate rund ums Training.", st))
        }
        if plan.weekday == 1 {
            notes.append("Sonntag: Einkauf für Di–Fr (Rewe Wangen) und Chili vorkochen.")
        }

        let trend = weightTrend(inputs.weights)
        let latest = inputs.weights.last?.kg
        let toGoal = trend.avg7.map { round1($0 - FitnessPlan.goalWeightKg) }

        return PlanAdvice(
            dayKey: key, weekdayShort: plan.short, readiness: ready, headline: headline,
            trainingTitle: plan.trainingTitle, trainingNote: trainingNote, exercises: exercises,
            breakfast: FitnessPlan.breakfast, snack: FitnessPlan.snack, lunch: plan.lunch, dinner: plan.dinner,
            kcalTarget: kcal, proteinG: FitnessPlan.proteinG, fatG: FitnessPlan.fatG, notes: notes,
            recovery: inputs.recovery, sleepHours: inputs.sleepMin.map { round1($0 / 60) }, hrv: inputs.hrvToday,
            latestWeight: latest, bodyFatPct: inputs.bodyFatPct, weightAvg7: trend.avg7,
            weeklyChange: trend.weeklyChange, toGoal: toGoal, generatedAt: now)
    }

    /// "4×6–8" → "3×6–8" (never below 2 sets). Leaves entries without a set count untouched.
    static func dropOneSet(_ s: String) -> String {
        guard let x = s.firstIndex(of: "×") else { return s }
        var start = x
        while start > s.startIndex, s[s.index(before: start)].isNumber { start = s.index(before: start) }
        guard start < x, let n = Int(s[start..<x]) else { return s }
        return s.replacingCharacters(in: start..<x, with: String(max(2, n - 1)))
    }

    static func parseDay(_ key: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: key)
    }

    static func round1(_ v: Double) -> Double { (v * 10).rounded() / 10 }
}

/// What the app publishes for the widget (App Group JSON).
public enum PlanSnapshotStore {
    public static let key = "rick.plan.advice"

    public static func save(_ advice: PlanAdvice) {
        guard let defaults = UserDefaults(suiteName: WidgetSnapshot.suiteName),
              let data = try? JSONEncoder().encode(advice) else { return }
        defaults.set(data, forKey: key)
    }

    public static func load() -> PlanAdvice? {
        guard let defaults = UserDefaults(suiteName: WidgetSnapshot.suiteName),
              let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PlanAdvice.self, from: data)
    }
}
