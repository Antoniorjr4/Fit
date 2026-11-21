import AppIntents

/// How a notification forwarded from the Shortcuts app is labelled on the band.
enum BandNoticeKind: String, AppEnum {
    case message, mail, other

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "intent.kind"
    static var caseDisplayRepresentations: [BandNoticeKind: DisplayRepresentation] = [
        .message: "intent.kind.message",
        .mail: "intent.kind.mail",
        .other: "intent.kind.other",
    ]
}

/// Shortcuts action. iOS lets a personal automation run it when a message or an e-mail arrives,
/// which is the only way iOS offers to get that text to a band that is not an Apple Watch.
struct SendToBandIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.send.title"
    static var description = IntentDescription("intent.send.description")
    static var openAppWhenRun = false

    @Parameter(title: "intent.param.title")
    var title: String

    @Parameter(title: "intent.param.message", default: "")
    var message: String

    @Parameter(title: "intent.param.kind", default: .message)
    var kind: BandNoticeKind

    /// Name of the app the notification came from (for the iOS 27 notification automation).
    @Parameter(title: "intent.param.app", default: "")
    var app: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        let link = BandLink.shared
        let mapped: SapNotify.Kind = kind == .message ? .message : (kind == .mail ? .mail : .other)
        // The iOS notification automation hands over one text, "sender\nmessage", often with invisible
        // direction marks. Split it so the band shows the sender as the title and the message below.
        func clean(_ value: String) -> String {
            String(value.unicodeScalars.filter { ![0x200E, 0x200F, 0x202A, 0x202B, 0x202C, 0x2068, 0x2069].contains($0.value) })
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        var shownTitle = clean(title)
        var shownText = clean(message)
        if shownText.isEmpty || shownText == shownTitle {
            let lines = shownTitle.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true).map(String.init)
            if lines.count == 2 {
                shownTitle = lines[0]
                shownText = lines[1]
            } else {
                shownText = ""
            }
        }
        if shownTitle.isEmpty { shownTitle = app.isEmpty ? mapped.appName : app }
        link.sendNotification(title: shownTitle, text: shownText, kind: mapped, app: app)
        // The app may have just been woken in the background: give the band up to 20 s to reconnect.
        var waited = 0
        while link.pendingNotifications > 0, waited < 40 {
            try? await Task.sleep(nanoseconds: 500_000_000)
            waited += 1
        }
        return .result(value: link.pendingNotifications == 0)
    }
}
