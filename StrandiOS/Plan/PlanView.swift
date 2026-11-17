#if os(iOS)
import SwiftUI
import WebKit
import StrandDesign

/// The Plan tab: today's training and meals adapted to recovery and the weight trend, the week at a
/// glance, and the Withings scale connection.
struct PlanView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var repo: Repository

    @State private var advice: PlanAdvice? = PlanSnapshotStore.load()
    @State private var loading = false
    @AppStorage(PlanPublisher.morningEnabledKey) private var morningEnabled = true
    @State private var notificationDenied = false

    var body: some View {
        ScreenScaffold(title: "Plan", subtitle: "Training und Essen, angepasst an deine Recovery",
                       onRefresh: { await reload() },
                       topBackground: liquidScaffoldSky()) {
            VStack(alignment: .leading, spacing: NoopMetrics.sectionSpacing) {
                if let a = advice {
                    heroCard(a)
                    todayCard(a)
                    mealsCard(a)
                    bodyCard(a)
                } else {
                    NoopCard {
                        Text("Plan wird berechnet …")
                            .font(StrandFont.subhead)
                            .foregroundStyle(StrandPalette.textSecondary)
                    }
                }
                weekCard
                WithingsCard()
                morningCard
            }
        }
        .task(id: repo.refreshSeq) { await reload() }
    }

    private func reload() async {
        loading = true
        advice = await PlanPublisher.publish(from: model)
        loading = false
    }

    // MARK: Hero

    /// The same liquid gauge trio as Today's Charge / Effort / Rest: recovery, last night's sleep and the
    /// share of the way from the start weight to the goal.
    private func heroCard(_ a: PlanAdvice) -> some View {
        let goalShare: Double? = a.weightAvg7.map { avg in
            max(0, min(100, (FitnessPlan.startWeightKg - avg)
                / (FitnessPlan.startWeightKg - FitnessPlan.goalWeightKg) * 100))
        }
        return NoopCard {
            HStack(alignment: .top, spacing: 0) {
                heroGauge("Recovery", score: a.recovery,
                          tint: a.recovery.map { StrandPalette.recoveryColor($0) } ?? StrandPalette.chargeColor)
                heroGauge("Schlaf h", score: a.sleepHours, tint: StrandPalette.restColor,
                          maxValue: 9, decimals: 1)
                heroGauge("Ziel %", score: goalShare, tint: StrandPalette.effortColor)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func heroGauge(_ label: String, score: Double?, tint: Color,
                           maxValue: Double = 100, decimals: Int = 0) -> some View {
        VStack(spacing: 7) {
            LiquidScoreGauge(score: score, tint: tint, diameter: 88, animated: true,
                             maxValue: maxValue, decimals: decimals)
            Text(label.uppercased())
                .font(StrandFont.overline).tracking(1.6)
                .lineLimit(1).minimumScaleFactor(0.7)
                .foregroundStyle(StrandPalette.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Today

    private func todayCard(_ a: PlanAdvice) -> some View {
        NoopCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Heute · \(a.weekdayShort)").strandOverline()
                    Spacer()
                    readinessPill(a)
                }
                Text(a.trainingTitle)
                    .font(StrandFont.title2)
                    .foregroundStyle(StrandPalette.textPrimary)
                Text(a.trainingNote)
                    .font(StrandFont.subhead)
                    .foregroundStyle(StrandPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                divider
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(a.exercises, id: \.self) { ex in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Circle().fill(StrandPalette.accent).frame(width: 5, height: 5)
                            Text(ex).font(StrandFont.body).foregroundStyle(StrandPalette.textPrimary)
                        }
                    }
                }
                if !a.notes.isEmpty {
                    divider
                    ForEach(a.notes, id: \.self) { n in
                        Text(n)
                            .font(StrandFont.caption)
                            .foregroundStyle(StrandPalette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                HStack(spacing: 16) {
                    metric("Recovery", a.recovery.map { "\(Int($0.rounded())) %" })
                    metric("Schlaf", a.sleepHours.map { String(format: "%.1f h", $0) })
                    metric("HRV", a.hrv.map { "\(Int($0.rounded())) ms" })
                }
                .padding(.top, 4)
                Text("Training \(FitnessPlan.trainingTime) · \(FitnessPlan.rules[0])")
                    .font(StrandFont.caption)
                    .foregroundStyle(StrandPalette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func readinessPill(_ a: PlanAdvice) -> some View {
        let color: Color = {
            switch a.readiness {
            case .green: return StrandPalette.statusPositive
            case .yellow: return StrandPalette.statusWarning
            case .red: return StrandPalette.statusCritical
            case .unknown: return StrandPalette.textTertiary
            }
        }()
        return Text(a.headline)
            .font(StrandFont.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .overlay(Capsule().stroke(color, lineWidth: 1))
    }

    // MARK: Meals

    private func mealsCard(_ a: PlanAdvice) -> some View {
        NoopCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Essen").strandOverline()
                mealRow("Frühstück", a.breakfast, icon: "sunrise.fill", tint: StrandPalette.statusWarning)
                mealRow("Snack", a.snack, icon: "cup.and.saucer.fill", tint: StrandPalette.effortColor)
                mealRow("Mittag", a.lunch, icon: "sun.max.fill", tint: StrandPalette.chargeColor)
                mealRow("Abend", a.dinner, icon: "moon.stars.fill", tint: StrandPalette.restColor)
                divider
                HStack(spacing: 16) {
                    metric("Kalorien", "\(a.kcalTarget)")
                    metric("Protein", "\(a.proteinG) g")
                    metric("Fett", "\(a.fatG) g")
                }
                Text(FitnessPlan.rules[2])
                    .font(StrandFont.caption)
                    .foregroundStyle(StrandPalette.textTertiary)
            }
        }
    }

    private func mealRow(_ label: String, _ text: String, icon: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(Circle().fill(tint.opacity(0.18)))
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(StrandFont.caption).foregroundStyle(StrandPalette.textTertiary)
                Text(text).font(StrandFont.body).foregroundStyle(StrandPalette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Body

    private func bodyCard(_ a: PlanAdvice) -> some View {
        NoopCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Gewicht · Ziel \(Int(FitnessPlan.goalWeightKg)) kg").strandOverline()
                HStack(spacing: 16) {
                    metric("Ø 7 Tage", a.weightAvg7.map { String(format: "%.1f kg", $0) })
                    metric("pro Woche", a.weeklyChange.map { String(format: "%+.1f kg", $0) })
                    metric("bis Ziel", a.toGoal.map { String(format: "%.1f kg", $0) })
                }
                HStack(spacing: 16) {
                    metric("Letzte Messung", a.latestWeight.map { String(format: "%.1f kg", $0) })
                    metric("Körperfett", a.bodyFatPct.map { String(format: "%.1f %%", $0) })
                }
                if let start = Optional(FitnessPlan.startWeightKg), let avg = a.weightAvg7 {
                    let done = max(0, min(1, (start - avg) / (start - FitnessPlan.goalWeightKg)))
                    ProgressView(value: done)
                        .tint(StrandPalette.accent)
                    Text(String(format: "%.0f %% vom Weg geschafft (Start %.0f kg)", done * 100, start))
                        .font(StrandFont.caption)
                        .foregroundStyle(StrandPalette.textTertiary)
                }
                Text("Ziel: 0,8–1,0 kg pro Woche. Kalorien passen sich wöchentlich um ±150 kcal an.")
                    .font(StrandFont.caption)
                    .foregroundStyle(StrandPalette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Week

    private var weekCard: some View {
        let order = [2, 3, 4, 5, 6, 7, 1]
        let todayWd = Calendar(identifier: .gregorian).component(.weekday, from: Date())
        return NoopCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Woche").strandOverline()
                ForEach(order, id: \.self) { wd in
                    if let d = FitnessPlan.week.first(where: { $0.weekday == wd }) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(d.short)
                                .font(StrandFont.subhead.weight(wd == todayWd ? .bold : .regular))
                                .foregroundStyle(wd == todayWd ? StrandPalette.accent : StrandPalette.textSecondary)
                                .frame(width: 30, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(d.trainingTitle).font(StrandFont.body).foregroundStyle(StrandPalette.textPrimary)
                                Text(d.dinner).font(StrandFont.caption).foregroundStyle(StrandPalette.textTertiary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                    }
                }
                if todayWd == 1 || todayWd == 7 {
                    divider
                    Text("Einkaufsliste (Rewe Wangen)").strandOverline()
                    ForEach(FitnessPlan.shoppingList, id: \.self) { item in
                        Text("• \(item)").font(StrandFont.caption).foregroundStyle(StrandPalette.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: Morning notification

    private var morningCard: some View {
        NoopCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Morgen-Briefing").strandOverline()
                Toggle(isOn: $morningEnabled) {
                    Text("Mitteilung um 7:00")
                        .font(StrandFont.subhead)
                        .foregroundStyle(StrandPalette.textPrimary)
                }
                .toggleStyle(.switch)
                .tint(StrandPalette.accent)
                .onChangeCompat(of: morningEnabled) { on in
                    Task {
                        if on {
                            notificationDenied = !(await PlanNotifier.requestPermission())
                            await reload()
                        } else {
                            PlanNotifier.cancel()
                        }
                    }
                }
                Text(notificationDenied
                     ? "Mitteilungen sind in den iOS-Einstellungen für NOOP aus."
                     : "Jeden Morgen: Recovery-Status, angepasstes Training, Kalorienziel und Abendessen.")
                    .font(StrandFont.caption)
                    .foregroundStyle(notificationDenied ? StrandPalette.statusWarning : StrandPalette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .task {
            if morningEnabled { notificationDenied = !(await PlanNotifier.requestPermission()) }
        }
    }

    // MARK: Bits

    private func metric(_ label: String, _ value: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(StrandFont.caption).foregroundStyle(StrandPalette.textTertiary)
            Text(value ?? "—").font(StrandFont.headline).foregroundStyle(StrandPalette.textPrimary)
                .monospacedDigit()
        }
    }

    private var divider: some View {
        Rectangle().fill(StrandPalette.hairline).frame(height: 1).padding(.vertical, 2)
    }
}

// MARK: - Withings connection card

private struct WithingsCard: View {
    @EnvironmentObject var model: AppModel

    @State private var connected = WithingsSync.isConnected
    @State private var clientId = WithingsKeychain.credentials?.clientId ?? ""
    @State private var clientSecret = WithingsKeychain.credentials?.clientSecret ?? ""
    @State private var showAuth = false
    @State private var authState = UUID().uuidString
    @State private var status: String?
    @State private var busy = false

    var body: some View {
        NoopCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Withings-Waage").strandOverline()
                    Spacer()
                    Text(connected ? "verbunden" : "nicht verbunden")
                        .font(StrandFont.caption)
                        .foregroundStyle(connected ? StrandPalette.statusPositive : StrandPalette.textTertiary)
                }
                if connected {
                    if let last = WithingsSync.lastSync {
                        Text("Zuletzt synchronisiert: \(last.formatted(date: .abbreviated, time: .shortened))")
                            .font(StrandFont.caption)
                            .foregroundStyle(StrandPalette.textSecondary)
                    }
                    HStack {
                        Button(busy ? "Synchronisiere …" : "Jetzt synchronisieren") {
                            Task {
                                busy = true
                                let n = await WithingsSync.sync(model: model)
                                status = WithingsSync.lastError ?? "\(n) Tage übernommen."
                                busy = false
                            }
                        }
                        .disabled(busy)
                        .foregroundStyle(StrandPalette.accent)
                        Spacer()
                        Button("Trennen") {
                            WithingsSync.disconnect()
                            connected = false
                            clientId = ""; clientSecret = ""
                            status = "Getrennt."
                        }
                        .foregroundStyle(StrandPalette.statusCritical)
                    }
                    .font(StrandFont.subhead)
                } else {
                    Text("Kostenlos: Lege auf developer.withings.com eine App an (Public API) mit der Callback-URL \(WithingsAPI.redirectURI) und trage hier Client ID und Secret ein.")
                        .font(StrandFont.caption)
                        .foregroundStyle(StrandPalette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                    TextField("Client ID", text: $clientId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(StrandFont.body)
                        .padding(10)
                        .background(StrandPalette.surfaceInset, in: RoundedRectangle(cornerRadius: 10))
                    SecureField("Client Secret", text: $clientSecret)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(StrandFont.body)
                        .padding(10)
                        .background(StrandPalette.surfaceInset, in: RoundedRectangle(cornerRadius: 10))
                    Button("Mit Withings verbinden") {
                        let cred = WithingsCredentials(
                            clientId: clientId.trimmingCharacters(in: .whitespacesAndNewlines),
                            clientSecret: clientSecret.trimmingCharacters(in: .whitespacesAndNewlines))
                        guard !cred.clientId.isEmpty, !cred.clientSecret.isEmpty else {
                            status = "Bitte Client ID und Secret eintragen."
                            return
                        }
                        WithingsKeychain.saveCredentials(cred)
                        authState = UUID().uuidString
                        showAuth = true
                    }
                    .font(StrandFont.subhead)
                    .foregroundStyle(StrandPalette.accent)
                }
                if let status {
                    Text(status)
                        .font(StrandFont.caption)
                        .foregroundStyle(StrandPalette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .sheet(isPresented: $showAuth) {
            NavigationStack {
                Group {
                    if let url = WithingsAPI.authorizeURL(clientId: clientId.trimmingCharacters(in: .whitespacesAndNewlines),
                                                          state: authState) {
                        WithingsAuthWebView(url: url, expectedState: authState) { result in
                            showAuth = false
                            Task { await finishAuth(result) }
                        }
                    } else {
                        Text("Ungültige Client ID.")
                    }
                }
                .navigationTitle("Withings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") { showAuth = false }
                    }
                }
            }
        }
    }

    private func finishAuth(_ result: Result<String, Error>) async {
        switch result {
        case .failure(let e):
            status = e.localizedDescription
        case .success(let code):
            do {
                try await WithingsAPI.exchange(code: code)
                connected = true
                status = "Verbunden. Hole Messungen …"
                let n = await WithingsSync.sync(model: model)
                status = WithingsSync.lastError ?? "\(n) Tage übernommen."
            } catch {
                status = error.localizedDescription
            }
        }
    }
}

/// Hosts the Withings consent page and catches the redirect to the registered localhost callback
/// before it is loaded, so no local server is needed.
private struct WithingsAuthWebView: UIViewRepresentable {
    let url: URL
    let expectedState: String
    let completion: (Result<String, Error>) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WithingsAuthWebView
        private var done = false
        init(_ parent: WithingsAuthWebView) { self.parent = parent }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url,
                  url.absoluteString.hasPrefix(WithingsAPI.redirectURI) else {
                decisionHandler(.allow)
                return
            }
            decisionHandler(.cancel)
            guard !done else { return }
            done = true
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let code = items.first { $0.name == "code" }?.value
            let state = items.first { $0.name == "state" }?.value
            if let code, state == parent.expectedState {
                parent.completion(.success(code))
            } else if code != nil {
                parent.completion(.failure(WithingsError.stateMismatch))
            } else {
                let err = items.first { $0.name == "error" }?.value ?? "abgelehnt"
                parent.completion(.failure(WithingsError.api(-1, err)))
            }
        }
    }
}
#endif
