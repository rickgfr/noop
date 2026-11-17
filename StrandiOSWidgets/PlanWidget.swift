import WidgetKit
import SwiftUI
import StrandDesign

/// Personal fork: today's Plan (recovery status, adjusted training, kcal target, dinner) on the Home and
/// Lock Screen. Reads the `PlanAdvice` the app publishes into the App Group; never computes or fetches.
struct PlanEntry: TimelineEntry {
    let date: Date
    let advice: PlanAdvice?
}

struct PlanProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlanEntry {
        PlanEntry(date: Date(), advice: PlanEngine.advice(for: Date(), inputs: PlanInputs(recovery: 72, sleepMin: 450)))
    }

    func getSnapshot(in context: Context, completion: @escaping (PlanEntry) -> Void) {
        completion(PlanEntry(date: Date(), advice: PlanSnapshotStore.load() ?? placeholder(in: context).advice))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlanEntry>) -> Void) {
        let stored = PlanSnapshotStore.load()
        // A snapshot from an earlier day shows the plan for TODAY's weekday (without recovery) instead of
        // yesterday's adjusted session.
        let today = FitnessPlan.dayKey(Date())
        let advice: PlanAdvice?
        if let s = stored, s.dayKey == today {
            advice = s
        } else {
            advice = PlanEngine.advice(for: Date(), inputs: PlanInputs(weights: stored.flatMap { s in
                s.weightAvg7.map { [WeightPoint(day: s.dayKey, kg: $0)] } } ?? [],
                kcalBase: stored?.kcalTarget ?? FitnessPlan.baseKcal))
        }
        let cal = Calendar.current
        let nextMidnight = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86_400))
        let next = min(nextMidnight.addingTimeInterval(60), Date().addingTimeInterval(3600))
        completion(Timeline(entries: [PlanEntry(date: Date(), advice: advice)], policy: .after(next)))
    }
}

struct PlanWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PlanEntry

    var body: some View {
        if let a = entry.advice {
            switch family {
            case .accessoryRectangular: rectangular(a)
            case .accessoryInline: Text(verbatim: "\(a.trainingTitle) · \(a.kcalTarget) kcal")
            case .systemMedium: medium(a)
            default: small(a)
            }
        } else {
            Text("Öffne NOOP → Plan")
                .font(.system(size: 12))
                .foregroundStyle(StrandPalette.textTertiary)
        }
    }

    private func color(_ r: PlanReadiness) -> Color {
        switch r {
        case .green: return StrandPalette.statusPositive
        case .yellow: return StrandPalette.statusWarning
        case .red: return StrandPalette.statusCritical
        case .unknown: return StrandPalette.textTertiary
        }
    }

    private func header(_ a: PlanAdvice) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color(a.readiness)).frame(width: 8, height: 8)
            Text(verbatim: a.recovery.map { "\(Int($0.rounded())) %" } ?? a.weekdayShort)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(StrandPalette.textSecondary)
            Spacer(minLength: 0)
            Text(verbatim: "\(a.kcalTarget) kcal")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(StrandPalette.textTertiary)
        }
    }

    private func small(_ a: PlanAdvice) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            header(a)
            Text(verbatim: a.trainingTitle)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(StrandPalette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(verbatim: a.headline)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(color(a.readiness))
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(verbatim: "Abends: \(a.dinner)")
                .font(.system(size: 10))
                .foregroundStyle(StrandPalette.textSecondary)
                .lineLimit(3)
        }
        .padding(2)
    }

    private func medium(_ a: PlanAdvice) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                header(a)
                Text(verbatim: a.trainingTitle)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(StrandPalette.textPrimary)
                Text(verbatim: a.trainingNote)
                    .font(.system(size: 11))
                    .foregroundStyle(StrandPalette.textSecondary)
                    .lineLimit(3)
                Spacer(minLength: 0)
                if let w = a.weightAvg7 {
                    Text(verbatim: String(format: "Ø7 %.1f kg", w) + (a.toGoal.map { String(format: " · noch %.1f", $0) } ?? ""))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(StrandPalette.textTertiary)
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(verbatim: "Mittag").font(.system(size: 9, weight: .bold)).foregroundStyle(StrandPalette.textTertiary)
                Text(verbatim: a.lunch).font(.system(size: 11)).foregroundStyle(StrandPalette.textPrimary).lineLimit(2)
                Text(verbatim: "Abend").font(.system(size: 9, weight: .bold)).foregroundStyle(StrandPalette.textTertiary)
                Text(verbatim: a.dinner).font(.system(size: 11)).foregroundStyle(StrandPalette.textPrimary).lineLimit(3)
                Spacer(minLength: 0)
                Text(verbatim: "\(a.proteinG) g Protein")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(StrandPalette.accent)
            }
        }
        .padding(2)
    }

    private func rectangular(_ a: PlanAdvice) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(verbatim: "\(a.trainingTitle) · \(a.recovery.map { "\(Int($0.rounded()))%" } ?? "–")")
                .font(.system(size: 12, weight: .bold))
            Text(verbatim: a.headline).font(.system(size: 11))
            Text(verbatim: "\(a.kcalTarget) kcal · \(a.proteinG) g P").font(.system(size: 11))
        }
    }
}

struct PlanWidget: Widget {
    static let kind = "PlanWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: PlanProvider()) { entry in
            PlanWidgetView(entry: entry)
                .containerBackground(StrandPalette.surfaceBase, for: .widget)
        }
        .configurationDisplayName("Plan")
        .description("Training, Kalorien und Abendessen für heute – angepasst an deine Recovery.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}
