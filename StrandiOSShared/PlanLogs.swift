import Foundation

// MARK: - Personal fork: food + training logs
//
// Small JSON blobs in the App Group defaults so the widget can show "eaten / remaining" too. Kept to the
// last 180 days; a year of food entries is well under 200 KB.

public struct FoodEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var day: String          // yyyy-MM-dd (local)
    public var at: Date
    public var slot: MealSlot
    public var name: String
    public var kcal: Int
    public var protein: Int

    public init(id: UUID = UUID(), day: String, at: Date = Date(), slot: MealSlot, name: String, kcal: Int, protein: Int) {
        self.id = id; self.day = day; self.at = at; self.slot = slot; self.name = name
        self.kcal = kcal; self.protein = protein
    }
}

public enum FoodLogStore {
    static let key = "rick.food.entries"
    static let keepDays = 180

    private static var defaults: UserDefaults? { UserDefaults(suiteName: WidgetSnapshot.suiteName) }

    public static func all() -> [FoodEntry] {
        guard let data = defaults?.data(forKey: key),
              let list = try? JSONDecoder().decode([FoodEntry].self, from: data) else { return [] }
        return list
    }

    public static func entries(day: String) -> [FoodEntry] {
        all().filter { $0.day == day }.sorted { $0.at < $1.at }
    }

    public static func add(_ entry: FoodEntry) {
        var list = all()
        list.append(entry)
        save(list)
    }

    public static func update(_ entry: FoodEntry) {
        var list = all()
        if let i = list.firstIndex(where: { $0.id == entry.id }) { list[i] = entry } else { list.append(entry) }
        save(list)
    }

    public static func delete(id: UUID) {
        save(all().filter { $0.id != id })
    }

    /// Per-day totals, oldest → newest.
    public static func dailyTotals() -> [IntakeDay] {
        var kcal: [String: Int] = [:]
        var protein: [String: Int] = [:]
        for e in all() {
            kcal[e.day, default: 0] += e.kcal
            protein[e.day, default: 0] += e.protein
        }
        return kcal.keys.sorted().map { IntakeDay(day: $0, kcal: kcal[$0] ?? 0, protein: protein[$0] ?? 0) }
    }

    public static func total(day: String) -> (kcal: Int, protein: Int) {
        let e = entries(day: day)
        return (e.reduce(0) { $0 + $1.kcal }, e.reduce(0) { $0 + $1.protein })
    }

    private static func save(_ list: [FoodEntry]) {
        let cutoff = FitnessPlan.dayKey(Date().addingTimeInterval(-Double(keepDays) * 86_400))
        let kept = list.filter { $0.day >= cutoff }
        guard let data = try? JSONEncoder().encode(kept) else { return }
        defaults?.set(data, forKey: key)
    }
}

/// One exercise of one day: how many sets are ticked off and the working weight used.
public struct ExerciseLog: Codable, Equatable, Sendable {
    public var setsDone: Int
    public var kg: Double?
    public init(setsDone: Int = 0, kg: Double? = nil) { self.setsDone = setsDone; self.kg = kg }
}

public enum TrainingLogStore {
    static let prefix = "rick.training."
    static let lastKgKey = "rick.training.lastKg"

    private static var defaults: UserDefaults? { UserDefaults(suiteName: WidgetSnapshot.suiteName) }

    public static func day(_ key: String) -> [String: ExerciseLog] {
        guard let data = defaults?.data(forKey: prefix + key),
              let map = try? JSONDecoder().decode([String: ExerciseLog].self, from: data) else { return [:] }
        return map
    }

    public static func save(_ map: [String: ExerciseLog], day key: String) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        defaults?.set(data, forKey: prefix + key)
        var last = lastKg()
        for (name, log) in map { if let kg = log.kg { last[name] = kg } }
        if let d = try? JSONEncoder().encode(last) { defaults?.set(d, forKey: lastKgKey) }
    }

    /// The most recent working weight per exercise name, to prefill the next session.
    public static func lastKg() -> [String: Double] {
        guard let data = defaults?.data(forKey: lastKgKey),
              let map = try? JSONDecoder().decode([String: Double].self, from: data) else { return [:] }
        return map
    }
}

/// "Bankdrücken 4×6–8" → name "Bankdrücken", sets 4, reps "6–8". Entries without "N×" keep sets = 1.
public struct ParsedExercise: Equatable, Sendable {
    public let raw: String
    public let name: String
    public let sets: Int
    public let reps: String?

    public init(_ raw: String) {
        self.raw = raw
        guard let x = raw.firstIndex(of: "×") else {
            name = raw; sets = 1; reps = nil; return
        }
        var start = x
        while start > raw.startIndex, raw[raw.index(before: start)].isNumber { start = raw.index(before: start) }
        guard start < x, let n = Int(raw[start..<x]) else {
            name = raw; sets = 1; reps = nil; return
        }
        name = raw[raw.startIndex..<start].trimmingCharacters(in: .whitespaces)
        sets = n
        reps = String(raw[raw.index(after: x)...]).trimmingCharacters(in: .whitespaces)
    }
}
