#if os(iOS)
import Foundation
import Security
import WhoopStore

// MARK: - Withings body-scale sync (personal fork, opt-in)
//
// Reads the user's OWN scale readings from the Withings Public API (free developer app, one user):
// weight (meastype 1) and fat ratio (meastype 6). Nothing is ever sent TO Withings beyond the OAuth
// exchange and the read request. Credentials and tokens live in the Keychain. Readings land in the
// SAME metric-series rows the Apple Health import fills (`apple-health` / `weight` / `body_fat`), so the
// existing Today weight tile, its sparkline, Explore and Compare show them without further changes.

struct WithingsCredentials: Codable, Equatable {
    var clientId: String
    var clientSecret: String
}

struct WithingsTokens: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var isExpired: Bool { Date() >= expiresAt.addingTimeInterval(-60) }
}

enum WithingsKeychain {
    private static let service = "com.noop.withings"

    private static func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    @discardableResult
    private static func write<T: Encodable>(_ value: T, account: String) -> Bool {
        guard let data = try? JSONEncoder().encode(value) else { return false }
        SecItemDelete(query(account) as CFDictionary)
        var attrs = query(account)
        attrs[kSecValueData as String] = data
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(attrs as CFDictionary, nil) == errSecSuccess
    }

    private static func read<T: Decodable>(_ type: T.Type, account: String) -> T? {
        var q = query(account)
        q[kSecReturnData as String] = kCFBooleanTrue
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static var credentials: WithingsCredentials? { read(WithingsCredentials.self, account: "credentials") }
    @discardableResult static func saveCredentials(_ c: WithingsCredentials) -> Bool { write(c, account: "credentials") }

    static var tokens: WithingsTokens? { read(WithingsTokens.self, account: "tokens") }
    @discardableResult static func saveTokens(_ t: WithingsTokens) -> Bool { write(t, account: "tokens") }

    static func clearAll() {
        SecItemDelete(query("tokens") as CFDictionary)
        SecItemDelete(query("credentials") as CFDictionary)
    }
}

enum WithingsError: LocalizedError {
    case notConfigured, notConnected, stateMismatch, api(Int, String?), badResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Client ID und Secret fehlen."
        case .notConnected: return "Withings ist nicht verbunden."
        case .stateMismatch: return "Antwort von Withings passt nicht zur Anfrage. Bitte erneut verbinden."
        case .api(let status, let msg): return "Withings-Fehler \(status)\(msg.map { ": \($0)" } ?? "")"
        case .badResponse: return "Unerwartete Antwort von Withings."
        }
    }
}

struct WithingsReading: Equatable {
    let date: Date
    var weightKg: Double?
    var fatPct: Double?
}

enum WithingsAPI {
    /// Must be registered EXACTLY like this as the callback URL of the Withings developer app. The page is
    /// never loaded: the in-app web view catches the redirect before it leaves the device.
    static let redirectURI = "http://localhost:8723/callback"
    private static let authorizeBase = "https://account.withings.com/oauth2_user/authorize2"
    private static let tokenURL = URL(string: "https://wbsapi.withings.net/v2/oauth2")!
    private static let measureURL = URL(string: "https://wbsapi.withings.net/measure")!

    static func authorizeURL(clientId: String, state: String) -> URL? {
        var c = URLComponents(string: authorizeBase)
        c?.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "scope", value: "user.metrics"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "state", value: state),
        ]
        return c?.url
    }

    static func exchange(code: String) async throws {
        guard let cred = WithingsKeychain.credentials else { throw WithingsError.notConfigured }
        let body = try await tokenRequest([
            "action": "requesttoken", "grant_type": "authorization_code",
            "client_id": cred.clientId, "client_secret": cred.clientSecret,
            "code": code, "redirect_uri": redirectURI,
        ])
        WithingsKeychain.saveTokens(body)
    }

    /// A valid access token, refreshing (and storing the rotated refresh token) when needed.
    static func accessToken() async throws -> String {
        guard let tokens = WithingsKeychain.tokens else { throw WithingsError.notConnected }
        if !tokens.isExpired { return tokens.accessToken }
        guard let cred = WithingsKeychain.credentials else { throw WithingsError.notConfigured }
        let fresh = try await tokenRequest([
            "action": "requesttoken", "grant_type": "refresh_token",
            "client_id": cred.clientId, "client_secret": cred.clientSecret,
            "refresh_token": tokens.refreshToken,
        ])
        WithingsKeychain.saveTokens(fresh)
        return fresh.accessToken
    }

    /// Scale readings changed since `lastUpdate` (unix seconds; 0 = full history), paged.
    static func readings(since lastUpdate: Int) async throws -> [WithingsReading] {
        let token = try await accessToken()
        var out: [WithingsReading] = []
        var offset: Int?
        repeat {
            var form = ["action": "getmeas", "meastypes": "1,6", "category": "1"]
            if lastUpdate > 0 { form["lastupdate"] = String(lastUpdate) }
            if let offset { form["offset"] = String(offset) }
            let json = try await post(measureURL, form: form, bearer: token)
            let status = json["status"] as? Int ?? -1
            guard status == 0, let body = json["body"] as? [String: Any] else {
                throw WithingsError.api(status, json["error"] as? String)
            }
            for g in body["measuregrps"] as? [[String: Any]] ?? [] {
                guard let ts = g["date"] as? Int else { continue }
                var r = WithingsReading(date: Date(timeIntervalSince1970: TimeInterval(ts)))
                for m in g["measures"] as? [[String: Any]] ?? [] {
                    guard let v = m["value"] as? Int, let t = m["type"] as? Int, let u = m["unit"] as? Int else { continue }
                    let real = Double(v) * pow(10, Double(u))
                    if t == 1 { r.weightKg = real }
                    if t == 6 { r.fatPct = real }
                }
                if r.weightKg != nil || r.fatPct != nil { out.append(r) }
            }
            offset = ((body["more"] as? Int) ?? 0) != 0 ? body["offset"] as? Int : nil
        } while offset != nil
        return out.sorted { $0.date < $1.date }
    }

    private static func tokenRequest(_ form: [String: String]) async throws -> WithingsTokens {
        let json = try await post(tokenURL, form: form, bearer: nil)
        let status = json["status"] as? Int ?? -1
        guard status == 0, let body = json["body"] as? [String: Any],
              let access = body["access_token"] as? String,
              let refresh = body["refresh_token"] as? String else {
            throw WithingsError.api(status, json["error"] as? String)
        }
        let expires = (body["expires_in"] as? Int) ?? Int(body["expires_in"] as? String ?? "") ?? 10_800
        return WithingsTokens(accessToken: access, refreshToken: refresh,
                              expiresAt: Date().addingTimeInterval(TimeInterval(expires)))
    }

    private static func post(_ url: URL, form: [String: String], bearer: String?) async throws -> [String: Any] {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 30
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        if let bearer { req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        req.httpBody = form.map { k, v in
            "\(k)=\(v.addingPercentEncoding(withAllowedCharacters: allowed) ?? v)"
        }.joined(separator: "&").data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw WithingsError.badResponse }
        return obj
    }
}

/// Pulls new readings and writes them into the store. Throttled so the many republish points in the app
/// don't hit the API more than once every few hours.
@MainActor
enum WithingsSync {
    private static let lastUpdateKey = "rick.withings.lastUpdate"
    private static let lastSyncKey = "rick.withings.lastSync"
    private static let lastErrorKey = "rick.withings.lastError"
    static let minInterval: TimeInterval = 3 * 3600

    static var isConnected: Bool { WithingsKeychain.tokens != nil }
    static var lastSync: Date? { UserDefaults.standard.object(forKey: lastSyncKey) as? Date }
    static var lastError: String? { UserDefaults.standard.string(forKey: lastErrorKey) }

    static func disconnect() {
        WithingsKeychain.clearAll()
        UserDefaults.standard.removeObject(forKey: lastUpdateKey)
        UserDefaults.standard.removeObject(forKey: lastSyncKey)
        UserDefaults.standard.removeObject(forKey: lastErrorKey)
    }

    static func syncIfDue(model: AppModel) async {
        guard isConnected else { return }
        if let last = lastSync, Date().timeIntervalSince(last) < minInterval { return }
        _ = await sync(model: model)
    }

    /// Returns the number of days written.
    @discardableResult
    static func sync(model: AppModel) async -> Int {
        // Stamp first so a failing call can't be retried in a tight loop by the republish hooks.
        UserDefaults.standard.set(Date(), forKey: lastSyncKey)
        do {
            let since = UserDefaults.standard.integer(forKey: lastUpdateKey)
            let readings = try await WithingsAPI.readings(since: since)
            UserDefaults.standard.removeObject(forKey: lastErrorKey)
            guard !readings.isEmpty, let store = await model.repo.storeHandle() else { return 0 }
            // One value per local day: the LAST reading of the day wins (morning weigh-in after the
            // evening one only if it is later, which matches how the metric-series key is defined).
            var byDay: [String: WithingsReading] = [:]
            for r in readings { byDay[Repository.localDayKey(r.date)] = r }
            var points: [MetricPoint] = []
            for (day, r) in byDay {
                if let w = r.weightKg { points.append(MetricPoint(day: day, key: "weight", value: w)) }
                if let f = r.fatPct { points.append(MetricPoint(day: day, key: "body_fat", value: f)) }
            }
            _ = try await store.upsertMetricSeries(points, deviceId: Repository.appleHealthSource)
            if let newest = readings.last {
                UserDefaults.standard.set(Int(newest.date.timeIntervalSince1970), forKey: lastUpdateKey)
                if let w = readings.last(where: { $0.weightKg != nil })?.weightKg {
                    model.profile.weightKg = (w * 10).rounded() / 10
                }
            }
            model.repo.noteBodyDataChanged()
            return byDay.count
        } catch {
            UserDefaults.standard.set(error.localizedDescription, forKey: lastErrorKey)
            return 0
        }
    }
}
#endif
