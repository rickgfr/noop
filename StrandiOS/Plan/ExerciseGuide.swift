#if os(iOS)
import Foundation

/// Short how-to for every exercise in the plan: target muscles and three execution cues.
enum ExerciseGuide {
    struct Info {
        let muscles: String
        let cues: [String]
        let restSeconds: Int
    }

    static func info(for name: String) -> Info? {
        if let exact = table[name] { return exact }
        let lower = name.lowercased()
        return table.first { lower.hasPrefix($0.key.lowercased()) }?.value
    }

    /// YouTube search for a demo video (only the exercise name goes into the query).
    static func videoURL(for name: String) -> URL? {
        var c = URLComponents(string: "https://www.youtube.com/results")
        c?.queryItems = [URLQueryItem(name: "search_query", value: "\(name) richtige Ausführung")]
        return c?.url
    }

    private static let compound = 150
    private static let isolation = 90

    private static let table: [String: Info] = [
        "Bankdrücken": Info(muscles: "Brust, vordere Schulter, Trizeps", cues: [
            "Schulterblätter zusammen und nach unten, leichtes Hohlkreuz, Füße fest am Boden.",
            "Stange kontrolliert zur unteren Brust, Ellbogen ca. 45° vom Körper.",
            "Explosiv hochdrücken, Gesäß bleibt auf der Bank."], restSeconds: compound),
        "LH-Rudern": Info(muscles: "Oberer Rücken, Lat, Bizeps", cues: [
            "Oberkörper ca. 45° vorgebeugt, Rücken gerade, Knie leicht gebeugt.",
            "Stange zum Bauchnabel ziehen, Ellbogen eng am Körper.",
            "Oben kurz halten, langsam ablassen, nicht mit Schwung arbeiten."], restSeconds: compound),
        "KH-Schulterdrücken": Info(muscles: "Schultern, Trizeps", cues: [
            "Sitzend, Rücken an der Lehne, Hanteln auf Schulterhöhe.",
            "Nach oben drücken, ohne die Hanteln oben zusammenzuschlagen.",
            "Bauch fest, kein Hohlkreuz."], restSeconds: compound),
        "Latzug": Info(muscles: "Lat, Bizeps, hinterer Rücken", cues: [
            "Griff etwas breiter als schulterbreit, Brust raus.",
            "Stange zur oberen Brust ziehen, Ellbogen Richtung Hüfte.",
            "Oben ganz strecken lassen, nicht nach hinten lehnen."], restSeconds: isolation),
        "Seitheben": Info(muscles: "Seitliche Schulter", cues: [
            "Leichte Hanteln, Arme minimal gebeugt.",
            "Seitlich bis Schulterhöhe heben, kleiner Finger leicht oben.",
            "Langsam ablassen, kein Schwung aus dem Oberkörper."], restSeconds: isolation),
        "Trizeps Kabel": Info(muscles: "Trizeps", cues: [
            "Oberarme fest am Körper, nur der Unterarm bewegt sich.",
            "Unten ganz durchstrecken und kurz anspannen.",
            "Kontrolliert zurück bis etwa 90°."], restSeconds: isolation),
        "KH-Curls": Info(muscles: "Bizeps", cues: [
            "Ellbogen bleiben seitlich am Körper.",
            "Beim Hochcurlen Handgelenk nach außen drehen.",
            "Langsam ablassen, nicht schwingen."], restSeconds: isolation),
        "Kniebeuge": Info(muscles: "Beine, Gesäß, Rumpf", cues: [
            "Stange auf dem oberen Rücken, Füße schulterbreit, Zehen leicht nach außen.",
            "Hüfte nach hinten und unten, Knie folgen den Zehen, Brust bleibt oben.",
            "Mindestens bis Oberschenkel parallel, über die ganze Fußsohle hochdrücken."], restSeconds: 180),
        "RDL": Info(muscles: "Beinbeuger, Gesäß, unterer Rücken", cues: [
            "Rumänisches Kreuzheben: Knie leicht gebeugt, Rücken gerade.",
            "Hüfte nach hinten schieben, Stange nah an den Beinen bis Mitte Schienbein.",
            "Mit dem Gesäß nach vorne aufrichten, Dehnung hinten im Bein spüren."], restSeconds: compound),
        "Beinpresse": Info(muscles: "Oberschenkel vorne, Gesäß", cues: [
            "Füße schulterbreit mittig auf der Platte.",
            "So tief, dass der untere Rücken an der Lehne bleibt.",
            "Knie oben nicht ganz durchstrecken."], restSeconds: compound),
        "Beinbeuger": Info(muscles: "Hintere Oberschenkel", cues: [
            "Polster knapp über der Ferse, Hüfte bleibt unten.",
            "Fersen kräftig Richtung Gesäß ziehen.",
            "Langsam zurück, Gewicht nicht fallen lassen."], restSeconds: isolation),
        "Wadenheben sitzend": Info(muscles: "Waden (Schollenmuskel)", cues: [
            "Fußballen auf der Kante, Polster auf den Knien.",
            "Ganz hoch auf die Zehen, oben 1 s halten.",
            "Unten tief in die Dehnung."], restSeconds: 60),
        "Wadenheben": Info(muscles: "Waden", cues: [
            "Fußballen auf einer Stufe, Knie gestreckt.",
            "Ganz hoch auf die Zehen, oben 1 s halten.",
            "Unten tief in die Dehnung, kein Wippen."], restSeconds: 60),
        "Plank": Info(muscles: "Bauch, Rumpf", cues: [
            "Unterarme unter den Schultern, Körper eine gerade Linie.",
            "Bauch und Gesäß fest anspannen.",
            "Ruhig weiteratmen, Hüfte nicht durchhängen lassen."], restSeconds: 60),
        "Schrägbank KH": Info(muscles: "Obere Brust, Schulter, Trizeps", cues: [
            "Bank auf ca. 30°, Schulterblätter zusammen.",
            "Hanteln seitlich der Brust ablassen, Ellbogen ca. 45°.",
            "Nach oben drücken und leicht zusammenführen."], restSeconds: compound),
        "Klimmzüge/Latzug eng": Info(muscles: "Lat, Bizeps", cues: [
            "Klimmzug oder enger Latzug mit Neutralgriff.",
            "Brust zur Stange, Ellbogen nach unten ziehen.",
            "Unten ganz aushängen. Klimmzüge zu schwer? Band oder Latzug nehmen."], restSeconds: compound),
        "Kabelrudern": Info(muscles: "Mittlerer Rücken, Lat", cues: [
            "Aufrecht sitzen, Knie leicht gebeugt.",
            "Griff zum Bauch ziehen, Schulterblätter zusammendrücken.",
            "Arme langsam strecken, Oberkörper bleibt ruhig."], restSeconds: isolation),
        "Dips/Brustpresse": Info(muscles: "Brust, Trizeps", cues: [
            "Dips: Oberkörper leicht nach vorne, bis Oberarme etwa parallel zum Boden.",
            "Brustpresse: Griffe auf Brusthöhe, Schulterblätter an der Lehne.",
            "Kontrolliert, Schultern tief halten."], restSeconds: isolation),
        "Face Pulls": Info(muscles: "Hintere Schulter, oberer Rücken", cues: [
            "Seil auf Kopfhöhe, Daumen zeigen nach hinten.",
            "Zum Gesicht ziehen und Hände dabei auseinander führen.",
            "Hinten kurz halten, leichtes Gewicht."], restSeconds: 60),
        "Hammer-Curls": Info(muscles: "Bizeps, Unterarm", cues: [
            "Neutralgriff, Daumen zeigen nach oben.",
            "Ellbogen bleiben am Körper.",
            "Langsam ablassen."], restSeconds: isolation),
        "Overhead-Trizeps": Info(muscles: "Trizeps (langer Kopf)", cues: [
            "Kabel oder Kurzhantel hinter den Kopf, Oberarme neben den Ohren.",
            "Unterarme nach oben strecken.",
            "Tief in die Dehnung, Ellbogen nicht ausstellen."], restSeconds: isolation),
        "Kreuzheben": Info(muscles: "Ganzer hinterer Körper, Rumpf", cues: [
            "Stange über der Fußmitte, schulterbreiter Griff, Rücken gerade.",
            "Aus den Beinen drücken, Stange nah am Körper, Hüfte und Schultern steigen gleich schnell.",
            "Oben aufrecht stehen, nicht nach hinten lehnen. Kontrolliert ablassen."], restSeconds: 180),
        "Bulg. Split Squats": Info(muscles: "Oberschenkel, Gesäß", cues: [
            "Hinterer Fuß auf der Bank, vorderer Fuß weit genug vorne.",
            "Gerade nach unten, bis das hintere Knie fast den Boden berührt.",
            "Über die vordere Ferse hochdrücken. Erst alle Wdh. links, dann rechts."], restSeconds: isolation),
        "Hip Thrust": Info(muscles: "Gesäß", cues: [
            "Oberer Rücken an der Bank, Stange mit Polster auf der Hüfte.",
            "Hüfte hochdrücken, bis der Körper von Knie bis Schulter gerade ist.",
            "Oben Gesäß 1 s fest anspannen, Kinn zur Brust."], restSeconds: compound),
        "Beinstrecker": Info(muscles: "Oberschenkel vorne", cues: [
            "Polster knapp über dem Fußgelenk.",
            "Beine ganz strecken und oben kurz halten.",
            "Langsam zurück."], restSeconds: isolation),
        "Hanging Leg Raises": Info(muscles: "Unterer Bauch, Hüftbeuger", cues: [
            "An der Stange hängen, nicht schwingen.",
            "Beine (oder Knie) bis Hüfthöhe oder höher heben, Becken einrollen.",
            "Langsam ablassen."], restSeconds: 60),
    ]
}
#endif
