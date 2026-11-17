#if os(iOS)
import SwiftUI
import WidgetKit
import StrandDesign

/// Calorie tracker: tick off the planned meals (with editable estimates), add anything else, see what
/// is left for today, and how the adaptive model reads intake against the scale.
struct FoodView: View {
    let advice: PlanAdvice

    @State private var day = Date()
    @State private var entries: [FoodEntry] = []
    @State private var recents: [FoodEntry] = []
    @State private var history: [IntakeDay] = []
    @State private var editing: FoodEntry?

    private var dayKey: String { FitnessPlan.dayKey(day) }
    private var isToday: Bool { Calendar.current.isDateInToday(day) }
    private var eaten: Int { entries.reduce(0) { $0 + $1.kcal } }
    private var protein: Int { entries.reduce(0) { $0 + $1.protein } }

    var body: some View {
        ScreenScaffold(title: "Essen", subtitle: "Kalorien-Tracker · Ziel passt sich an deinen Verlauf an",
                       topBackground: liquidScaffoldSky()) {
            VStack(alignment: .leading, spacing: NoopMetrics.sectionSpacing) {
                dayPicker
                summaryCard
                plannedCard
                eatenCard
                energyCard
                historyCard
            }
        }
        .onAppear(perform: load)
        .sheet(item: $editing) { entry in
            FoodEntryEditor(entry: entry,
                            isNew: !entries.contains { $0.id == entry.id },
                            onSave: { FoodLogStore.update($0); editing = nil; changed() },
                            onDelete: { FoodLogStore.delete(id: entry.id); editing = nil; changed() },
                            onCancel: { editing = nil })
        }
    }

    // MARK: Day

    private var dayPicker: some View {
        HStack {
            Button { shift(-1) } label: { Image(systemName: "chevron.left.circle.fill").font(.system(size: 26)) }
            Spacer()
            Text(isToday ? "Heute" : day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(StrandFont.headline)
                .foregroundStyle(StrandPalette.textPrimary)
            Spacer()
            Button { shift(1) } label: { Image(systemName: "chevron.right.circle.fill").font(.system(size: 26)) }
                .disabled(isToday)
                .opacity(isToday ? 0.3 : 1)
        }
        .buttonStyle(.plain)
        .foregroundStyle(StrandPalette.accent)
    }

    private func shift(_ days: Int) {
        guard let d = Calendar.current.date(byAdding: .day, value: days, to: day), d <= Date() else { return }
        day = d
        load()
    }

    // MARK: Summary

    private var summaryCard: some View {
        let target = advice.kcalTarget
        let over = eaten > target
        return NoopCard {
            HStack(spacing: 18) {
                LiquidScoreGauge(score: Double(eaten), tint: over ? StrandPalette.statusWarning : StrandPalette.chargeColor,
                                 diameter: 96, animated: true, maxValue: Double(max(1, target)),
                                 captionText: "kcal")
                VStack(alignment: .leading, spacing: 8) {
                    Text(over ? "\(eaten - target) kcal drüber" : "noch \(target - eaten) kcal")
                        .font(StrandFont.title2)
                        .foregroundStyle(over ? StrandPalette.statusWarning : StrandPalette.textPrimary)
                    Text("Ziel \(target) kcal")
                        .font(StrandFont.caption)
                        .foregroundStyle(StrandPalette.textTertiary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Protein \(protein) / \(advice.proteinG) g")
                            .font(StrandFont.subhead)
                            .foregroundStyle(StrandPalette.textSecondary)
                        ProgressView(value: Double(min(protein, advice.proteinG)), total: Double(max(1, advice.proteinG)))
                            .tint(StrandPalette.effortColor)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Planned meals

    private var plannedCard: some View {
        NoopCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Geplant").strandOverline()
                ForEach(FitnessPlan.plannedMeals(for: day), id: \.slot) { meal in
                    let logged = entries.contains { $0.slot == meal.slot && $0.name == meal.name }
                    HStack(alignment: .top, spacing: 12) {
                        slotIcon(meal.slot)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(meal.slot.label).font(StrandFont.caption).foregroundStyle(StrandPalette.textTertiary)
                            Text(meal.name).font(StrandFont.subhead).foregroundStyle(StrandPalette.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("≈ \(meal.kcal) kcal · \(meal.protein) g P")
                                .font(StrandFont.caption).foregroundStyle(StrandPalette.textSecondary)
                        }
                        Spacer(minLength: 4)
                        Button {
                            if logged {
                                entries.filter { $0.slot == meal.slot && $0.name == meal.name }
                                    .forEach { FoodLogStore.delete(id: $0.id) }
                            } else {
                                FoodLogStore.add(FoodEntry(day: dayKey, at: timestamp(), slot: meal.slot,
                                                           name: meal.name, kcal: meal.kcal, protein: meal.protein))
                            }
                            changed()
                        } label: {
                            Image(systemName: logged ? "checkmark.circle.fill" : "plus.circle")
                                .font(.system(size: 26))
                                .foregroundStyle(logged ? StrandPalette.statusPositive : StrandPalette.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    .contentShape(Rectangle())
                    .onLongPressGesture {
                        editing = FoodEntry(day: dayKey, at: timestamp(), slot: meal.slot, name: meal.name,
                                            kcal: meal.kcal, protein: meal.protein)
                    }
                }
                Text("Tippen = so gegessen wie geplant. Lange drücken = Menge/Kalorien anpassen.")
                    .font(StrandFont.caption)
                    .foregroundStyle(StrandPalette.textTertiary)
            }
        }
    }

    // MARK: Eaten

    private var eatenCard: some View {
        NoopCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Gegessen").strandOverline()
                    Spacer()
                    Button {
                        editing = FoodEntry(day: dayKey, at: timestamp(), slot: .other, name: "", kcal: 0, protein: 0)
                    } label: {
                        Label("Eintrag", systemImage: "plus")
                            .font(StrandFont.subhead.weight(.semibold))
                    }
                    .tint(StrandPalette.accent)
                }
                if !recents.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(recents) { r in
                                Button {
                                    FoodLogStore.add(FoodEntry(day: dayKey, at: timestamp(), slot: r.slot,
                                                               name: r.name, kcal: r.kcal, protein: r.protein))
                                    changed()
                                } label: {
                                    Text("+ \(r.name) · \(r.kcal)")
                                        .font(StrandFont.caption)
                                        .lineLimit(1)
                                        .padding(.horizontal, 10).padding(.vertical, 6)
                                        .background(Capsule().fill(StrandPalette.hairline))
                                        .foregroundStyle(StrandPalette.textPrimary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                if entries.isEmpty {
                    Text("Noch nichts eingetragen.")
                        .font(StrandFont.subhead)
                        .foregroundStyle(StrandPalette.textSecondary)
                }
                ForEach(entries) { e in
                    Button { editing = e } label: {
                        HStack(spacing: 12) {
                            slotIcon(e.slot)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.name.isEmpty ? e.slot.label : e.name)
                                    .font(StrandFont.subhead)
                                    .foregroundStyle(StrandPalette.textPrimary)
                                    .lineLimit(2)
                                Text("\(e.slot.label) · \(e.protein) g Protein")
                                    .font(StrandFont.caption)
                                    .foregroundStyle(StrandPalette.textTertiary)
                            }
                            Spacer(minLength: 4)
                            Text("\(e.kcal)")
                                .font(StrandFont.headline.monospacedDigit())
                                .foregroundStyle(StrandPalette.textPrimary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Adaptive energy

    private var energyCard: some View {
        let todayKey = FitnessPlan.dayKey(Date())
        let from = FitnessPlan.dayKey(Date().addingTimeInterval(-21 * 86_400))
        let logged = history.filter { $0.day >= from && $0.day < todayKey && $0.kcal >= PlanEngine.minLoggedKcal }.count
        return NoopCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Dein Verbrauch").strandOverline()
                if let tdee = advice.tdeeEstimate {
                    HStack(spacing: 16) {
                        stat("Verbrauch", "\(tdee) kcal")
                        stat("Ø gegessen", advice.intakeAvg.map { "\($0) kcal" } ?? "—")
                        stat("Trend", advice.weeklyChange.map { String(format: "%+.1f kg/W", $0) } ?? "—")
                    }
                    Text("Berechnet aus \(advice.loggedDays ?? logged) geloggten Tagen und deiner Waage. Ziel = Verbrauch − \(Int(PlanEngine.targetLossKgPerWeek * PlanEngine.kcalPerKg / 7)) kcal für \(String(format: "%.1f", PlanEngine.targetLossKgPerWeek)) kg pro Woche. Einmal pro Woche passt NOOP das Ziel an (max. ±200 kcal).")
                        .font(StrandFont.caption)
                        .foregroundStyle(StrandPalette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("\(logged) von 10 Tagen geloggt")
                        .font(StrandFont.headline)
                        .foregroundStyle(StrandPalette.textPrimary)
                    ProgressView(value: Double(min(logged, 10)), total: 10)
                        .tint(StrandPalette.accent)
                    Text("Logge an mindestens 10 der letzten 21 Tage alles, was du isst, und wieg dich regelmäßig. Dann rechnet NOOP aus Essen und Gewichtsverlauf deinen echten Verbrauch und stellt das Kalorienziel automatisch nach. Bis dahin gilt die Regel: weniger als 0,5 kg/Woche → −150 kcal, mehr als 1,2 kg/Woche → +150 kcal.")
                        .font(StrandFont.caption)
                        .foregroundStyle(StrandPalette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: History

    private var historyCard: some View {
        let keys = (0..<7).reversed().map { FitnessPlan.dayKey(Date().addingTimeInterval(-Double($0) * 86_400)) }
        let byDay = Dictionary(uniqueKeysWithValues: history.map { ($0.day, $0) })
        let target = advice.kcalTarget
        let maxV = max(Double(target) * 1.25, Double(byDay.values.map(\.kcal).max() ?? 0))
        return NoopCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Letzte 7 Tage").strandOverline()
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(keys, id: \.self) { k in
                        let v = byDay[k]?.kcal ?? 0
                        VStack(spacing: 4) {
                            Text(v > 0 ? "\(v)" : "–")
                                .font(.system(size: 9, weight: .semibold).monospacedDigit())
                                .foregroundStyle(StrandPalette.textTertiary)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(v > target ? StrandPalette.statusWarning : StrandPalette.chargeColor)
                                .frame(height: max(4, CGFloat(Double(v) / maxV) * 90))
                                .opacity(v > 0 ? 1 : 0.25)
                            Text(String(weekday(k)))
                                .font(StrandFont.caption)
                                .foregroundStyle(StrandPalette.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 130, alignment: .bottom)
            }
        }
    }

    // MARK: Helpers

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(StrandFont.caption).foregroundStyle(StrandPalette.textTertiary)
            Text(value).font(StrandFont.subhead.weight(.semibold).monospacedDigit()).foregroundStyle(StrandPalette.textPrimary)
        }
    }

    private func slotIcon(_ slot: MealSlot) -> some View {
        let (icon, tint): (String, Color) = {
            switch slot {
            case .breakfast: return ("sunrise.fill", StrandPalette.statusWarning)
            case .lunch: return ("sun.max.fill", StrandPalette.chargeColor)
            case .snack: return ("cup.and.saucer.fill", StrandPalette.effortColor)
            case .dinner: return ("moon.stars.fill", StrandPalette.restColor)
            case .other: return ("fork.knife", StrandPalette.accent)
            }
        }()
        return Image(systemName: icon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 32, height: 32)
            .background(Circle().fill(tint.opacity(0.18)))
    }

    private func weekday(_ key: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        guard let d = f.date(from: key) else { return "" }
        let wd = Calendar(identifier: .gregorian).component(.weekday, from: d)
        return FitnessPlan.week.first { $0.weekday == wd }?.short ?? ""
    }

    /// Entries for a past day get noon of that day so they sort sensibly.
    private func timestamp() -> Date {
        isToday ? Date() : (Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day)
    }

    private func load() {
        entries = FoodLogStore.entries(day: dayKey)
        history = FoodLogStore.dailyTotals()
        let planned = Set(FitnessPlan.week.flatMap { [$0.lunch, $0.dinner] } + [FitnessPlan.breakfast, FitnessPlan.snack])
        var seen = Set<String>()
        recents = FoodLogStore.all()
            .sorted { $0.at > $1.at }
            .filter { !planned.contains($0.name) && !$0.name.isEmpty && seen.insert($0.name).inserted }
            .prefix(8)
            .map { $0 }
    }

    private func changed() {
        load()
        WidgetCenter.shared.reloadTimelines(ofKind: PlanPublisher.widgetKind)
    }
}

// MARK: - Entry editor

private struct FoodEntryEditor: View {
    @State var entry: FoodEntry
    let isNew: Bool
    let onSave: (FoodEntry) -> Void
    let onDelete: () -> Void
    let onCancel: () -> Void

    @State private var kcalText = ""
    @State private var proteinText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Was") {
                    TextField("z. B. Proteinpudding", text: $entry.name)
                    Picker("Mahlzeit", selection: $entry.slot) {
                        ForEach(MealSlot.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                }
                Section("Nährwerte") {
                    HStack {
                        Text("Kalorien")
                        Spacer()
                        TextField("0", text: $kcalText).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                        Text("kcal").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Protein")
                        Spacer()
                        TextField("0", text: $proteinText).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                        Text("g").foregroundStyle(.secondary)
                    }
                }
                if !isNew {
                    Section {
                        Button("Eintrag löschen", role: .destructive, action: onDelete)
                    }
                }
            }
            .navigationTitle(isNew ? "Neuer Eintrag" : "Eintrag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        var e = entry
                        e.kcal = Int(kcalText) ?? 0
                        e.protein = Int(proteinText) ?? 0
                        onSave(e)
                    }
                    .disabled(Int(kcalText) == nil)
                }
            }
            .onAppear {
                kcalText = entry.kcal > 0 ? String(entry.kcal) : ""
                proteinText = entry.protein > 0 ? String(entry.protein) : ""
            }
        }
        .presentationDetents([.medium, .large])
    }
}
#endif
