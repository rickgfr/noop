#if os(iOS)
import SwiftUI
import StrandDesign

/// Today's session as a checklist: tap the set pips (or the circle for the whole exercise), note the
/// working weight, open the how-to. Ticks and weights persist per day (TrainingLogStore).
struct TrainingView: View {
    let advice: PlanAdvice

    @State private var log: [String: ExerciseLog] = [:]
    @State private var lastKg: [String: Double] = [:]
    @State private var expanded: Set<String> = []
    @State private var restUntil: Date?
    @State private var restTotal: Int = 90

    private var exercises: [ParsedExercise] { advice.exercises.map(ParsedExercise.init) }
    private var doneCount: Int { exercises.filter { (log[$0.name]?.setsDone ?? 0) >= $0.sets }.count }

    var body: some View {
        ScreenScaffold(title: LocalizedStringKey(advice.trainingTitle),
                       subtitle: LocalizedStringKey("\(advice.weekdayShort) · \(FitnessPlan.trainingTime) · \(advice.headline)"),
                       topBackground: liquidScaffoldSky()) {
            VStack(alignment: .leading, spacing: NoopMetrics.sectionSpacing) {
                progressCard
                if let until = restUntil, until > Date() { restCard(until) }
                ForEach(exercises, id: \.raw) { ex in exerciseCard(ex) }
                Text(FitnessPlan.rules[0])
                    .font(StrandFont.caption)
                    .foregroundStyle(StrandPalette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear {
            log = TrainingLogStore.day(advice.dayKey)
            lastKg = TrainingLogStore.lastKg()
        }
    }

    // MARK: Progress

    private var progressCard: some View {
        let total = max(1, exercises.count)
        let share = Double(doneCount) / Double(total)
        return NoopCard {
            HStack(spacing: 16) {
                LiquidScoreGauge(score: share * 100, tint: StrandPalette.chargeColor, diameter: 72, animated: true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(doneCount == exercises.count ? "Training erledigt" : "\(doneCount) von \(exercises.count) Übungen")
                        .font(StrandFont.headline)
                        .foregroundStyle(StrandPalette.textPrimary)
                    Text(advice.trainingNote)
                        .font(StrandFont.caption)
                        .foregroundStyle(StrandPalette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func restCard(_ until: Date) -> some View {
        NoopCard {
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                let left = max(0, Int(until.timeIntervalSince(ctx.date).rounded()))
                HStack {
                    Image(systemName: "timer").foregroundStyle(StrandPalette.accent)
                    Text(left > 0 ? String(format: "Pause %d:%02d", left / 60, left % 60) : "Weiter geht's")
                        .font(StrandFont.headline)
                        .monospacedDigit()
                        .foregroundStyle(StrandPalette.textPrimary)
                    Spacer()
                    ProgressView(value: Double(restTotal - left), total: Double(max(1, restTotal)))
                        .tint(StrandPalette.accent)
                        .frame(width: 90)
                    Button { restUntil = nil } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(StrandPalette.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Exercise

    private func exerciseCard(_ ex: ParsedExercise) -> some View {
        let entry = log[ex.name] ?? ExerciseLog()
        let done = entry.setsDone >= ex.sets
        let info = ExerciseGuide.info(for: ex.name)
        return NoopCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    Button { toggleAll(ex) } label: {
                        Image(systemName: done ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 26))
                            .foregroundStyle(done ? StrandPalette.statusPositive : StrandPalette.textTertiary)
                    }
                    .buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ex.name)
                            .font(StrandFont.headline)
                            .foregroundStyle(StrandPalette.textPrimary)
                            .strikethrough(done, color: StrandPalette.textTertiary)
                        if let reps = ex.reps {
                            Text("\(ex.sets) × \(reps)")
                                .font(StrandFont.subhead)
                                .foregroundStyle(StrandPalette.textSecondary)
                        }
                    }
                    Spacer(minLength: 0)
                    if info != nil {
                        Button {
                            if expanded.contains(ex.name) { expanded.remove(ex.name) } else { expanded.insert(ex.name) }
                        } label: {
                            Image(systemName: expanded.contains(ex.name) ? "chevron.up.circle" : "info.circle")
                                .font(.system(size: 20))
                                .foregroundStyle(StrandPalette.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if ex.sets > 1 || ex.reps != nil {
                    HStack(spacing: 8) {
                        ForEach(0..<ex.sets, id: \.self) { i in
                            Button { tapSet(ex, index: i) } label: {
                                Text("\(i + 1)")
                                    .font(StrandFont.subhead.weight(.semibold))
                                    .frame(width: 36, height: 36)
                                    .foregroundStyle(i < entry.setsDone ? StrandPalette.surfaceBase : StrandPalette.textSecondary)
                                    .background(Circle().fill(i < entry.setsDone ? StrandPalette.chargeColor : StrandPalette.hairline))
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer(minLength: 8)
                        kgField(ex, entry: entry)
                    }
                }

                if expanded.contains(ex.name), let info {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(info.muscles).strandOverline()
                        ForEach(Array(info.cues.enumerated()), id: \.offset) { i, cue in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("\(i + 1).").font(StrandFont.caption).foregroundStyle(StrandPalette.accent)
                                Text(cue).font(StrandFont.subhead).foregroundStyle(StrandPalette.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        HStack {
                            Text("Pause ca. \(info.restSeconds / 60):\(String(format: "%02d", info.restSeconds % 60)) min")
                                .font(StrandFont.caption).foregroundStyle(StrandPalette.textTertiary)
                            Spacer()
                            if let url = ExerciseGuide.videoURL(for: ex.name) {
                                Link(destination: url) {
                                    Label("Video", systemImage: "play.rectangle")
                                        .font(StrandFont.caption)
                                }
                                .tint(StrandPalette.accent)
                            }
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    private func kgField(_ ex: ParsedExercise, entry: ExerciseLog) -> some View {
        let binding = Binding<String>(
            get: { entry.kg.map { $0.truncatingRemainder(dividingBy: 1) == 0 ? String(Int($0)) : String(format: "%.1f", $0) } ?? "" },
            set: { text in
                var e = log[ex.name] ?? ExerciseLog()
                e.kg = Double(text.replacingOccurrences(of: ",", with: "."))
                log[ex.name] = e
                persist()
            })
        let placeholder = lastKg[ex.name].map { String(format: "%g", $0) } ?? "kg"
        return HStack(spacing: 4) {
            TextField(placeholder, text: binding)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(StrandFont.subhead.monospacedDigit())
                .frame(width: 54)
            Text("kg").font(StrandFont.caption).foregroundStyle(StrandPalette.textTertiary)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().stroke(StrandPalette.hairline, lineWidth: 1))
    }

    // MARK: Actions

    private func tapSet(_ ex: ParsedExercise, index: Int) {
        var e = log[ex.name] ?? ExerciseLog()
        // Tapping the next open set ticks it; tapping a ticked set un-ticks back to it.
        e.setsDone = index < e.setsDone ? index : index + 1
        if e.kg == nil, let last = lastKg[ex.name] { e.kg = last }
        log[ex.name] = e
        persist()
        if index + 1 == e.setsDone, e.setsDone < ex.sets {
            startRest(ExerciseGuide.info(for: ex.name)?.restSeconds ?? 90)
        }
    }

    private func toggleAll(_ ex: ParsedExercise) {
        var e = log[ex.name] ?? ExerciseLog()
        e.setsDone = e.setsDone >= ex.sets ? 0 : ex.sets
        log[ex.name] = e
        persist()
    }

    private func startRest(_ seconds: Int) {
        restTotal = seconds
        restUntil = Date().addingTimeInterval(TimeInterval(seconds))
    }

    private func persist() {
        TrainingLogStore.save(log, day: advice.dayKey)
        lastKg = TrainingLogStore.lastKg()
    }
}
#endif
