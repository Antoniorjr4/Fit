import SwiftUI
import Combine

/// Sample data and preferences for the interface. The real Bluetooth link lives in BandLink.
final class DemoStore: ObservableObject {
    private static let languageKey = "fitlambda.selected-language"
    @Published private(set) var language: AppLanguage
    @Published private(set) var languageChosen: Bool
    @Published var scenario: PreviewScenario = .standard
    @Published var recoveryNotice = false

    init() {
        let defaults = UserDefaults.standard
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-fit-ui-reset-language") { defaults.removeObject(forKey: Self.languageKey) }
        if let index = args.firstIndex(of: "-fit-ui-language"), args.indices.contains(index + 1),
           let language = AppLanguage(rawValue: args[index + 1]) {
            defaults.set(language.rawValue, forKey: Self.languageKey)
        }
        #endif
        let saved = defaults.string(forKey: Self.languageKey).flatMap(AppLanguage.init(rawValue:))
        language = saved ?? AppLanguage.recommended()
        languageChosen = saved != nil
    }
    func selectLanguage(_ value: AppLanguage) {
        language = value
        UserDefaults.standard.set(value.rawValue, forKey: Self.languageKey)
        languageChosen = true
    }
    func t(_ key: String, _ arguments: CVarArg...) -> String { language.format(key, arguments) }
    func number(_ value: Int) -> String { value.formatted(.number.locale(language.locale)) }
    func decimal(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)).locale(language.locale))
    }
    func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)).locale(language.locale))
    }
    // Fixed, reproducible demonstration dates; never presented as fresh device readings.
    func date(_ template: String, day: Int = 15, hour: Int = 20, minute: Int = 12) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let value = calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: value)
    }
    @Published private(set) var hasMetrics = true
    @Published private(set) var hasSleep = true
    @Published private(set) var isSyncingPreview = false

    func startSyncPreview() {
        guard connectionPreview, !isSyncingPreview else { return }
        isSyncingPreview = true
    }

    func setScenario(_ value: PreviewScenario) {
        isSyncingPreview = false
        scenario = value
        hasMetrics = value != .firstUse
        hasSleep = hasMetrics && value != .partial
        recoveryNotice = false
        connectionPreview = value == .syncFailed || value == .partial
    }
    func setPermissionPreview(granted: Bool) {
        // Authorization alone never creates metrics or fills a missing sleep record.
        scenario = granted ? .notFound : .permissionDenied
        recoveryNotice = false
    }
    func finishConnectionPreview() {
        connectionPreview = true
        retryPreview()
    }
    func retryPreview() {
        isSyncingPreview = false
        hasMetrics = true
        hasSleep = true
        scenario = .standard
        recoveryNotice = true
    }
    @Published var name = "Antonio"
    @Published var goal = 10_000.0
    @Published var isDark = true
    @Published var reminders = false
    @Published var face = 0
    @Published var connectionPreview = false
    let steps = 8_432
    static let week: [StepDay] = [
        .init(day: 9, steps: 10_800), .init(day: 10, steps: 10_100),
        .init(day: 11, steps: 10_400), .init(day: 12, steps: 11_500),
        .init(day: 13, steps: 6_800), .init(day: 14, steps: 8_487),
        .init(day: 15, steps: 8_432)
    ]
    static let month: [StepDay] = [
        .init(day: 1, range: "1–4", steps: 7_350), .init(day: 5, range: "5–8", steps: 8_020),
        .init(day: 9, range: "9–12", steps: 9_120), .init(day: 13, range: "13–15", steps: 9_240)
    ]
}

struct StepDay: Identifiable {
    var id: Int { day }
    let day: Int
    var range: String? = nil
    let steps: Int
    func label(in demo: DemoStore) -> String { range ?? demo.date("EEE", day: day) }
}

struct Palette {
    let scheme: ColorScheme
    init(_ scheme: ColorScheme) { self.scheme = scheme }
    var background: Color { scheme == .dark ? Color(hex: 0x101410) : Color(hex: 0xF5F6EF) }
    var surface: Color { scheme == .dark ? Color(hex: 0x1A201A) : .white }
    var line: Color { scheme == .dark ? Color(hex: 0x30372E) : Color(hex: 0xDDE2D5) }
    var accent: Color { scheme == .dark ? Color(hex: 0xD4F68A) : Color(hex: 0x496D1F) }
    var ink: Color { scheme == .dark ? Color(hex: 0x17230D) : Color(hex: 0xF3FFE2) }
    var muted: Color { scheme == .dark ? Color(hex: 0x9BA494) : Color(hex: 0x697560) }
    var pink: Color { scheme == .dark ? Color(hex: 0xF4B4AC) : Color(hex: 0x9E514D) }
    var purple: Color { scheme == .dark ? Color(hex: 0xC6BAF5) : Color(hex: 0x706092) }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255,
                  blue: Double(hex & 255) / 255, opacity: 1)
    }
}
