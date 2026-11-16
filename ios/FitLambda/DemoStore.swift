import SwiftUI
import Combine

/// Visual-only state. No CoreBluetooth, HealthKit or real health data.
final class DemoStore: ObservableObject {
    @Published var name = "Antonio"
    @Published var goal = 10_000.0
    @Published var isDark = true
    @Published var reminders = false
    @Published var face = 0
    @Published var connectionPreview = false
    let steps = 8_432
    static let week: [StepDay] = [
        .init(day: "Seg", steps: 10_800), .init(day: "Ter", steps: 10_100),
        .init(day: "Qua", steps: 10_400), .init(day: "Qui", steps: 11_500),
        .init(day: "Sex", steps: 6_800), .init(day: "Sáb", steps: 8_487),
        .init(day: "Dom", steps: 8_432)
    ]
    static let month: [StepDay] = [
        .init(day: "1–4", steps: 7_350), .init(day: "5–8", steps: 8_020),
        .init(day: "9–12", steps: 9_120), .init(day: "13–15", steps: 9_240)
    ]
    static func number(_ value: Int) -> String {
        value.formatted(.number.locale(Locale(identifier: "pt_BR")))
    }
}

struct StepDay: Identifiable {
    var id: String { day }
    let day: String
    let steps: Int
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
