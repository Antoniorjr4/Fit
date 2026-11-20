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

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        let link = BandLink.shared
        let mapped: SapNotify.Kind = kind == .message ? .message : (kind == .mail ? .mail : .other)
        link.sendNotification(title: title.isEmpty ? mapped.appName : title, text: message, kind: mapped)
        // The app may have just been woken in the background: give the band up to 20 s to reconnect.
        var waited = 0
        while link.pendingNotifications > 0, waited < 40 {
            try? await Task.sleep(nanoseconds: 500_000_000)
            waited += 1
        }
        return .result(value: link.pendingNotifications == 0)
    }
}
