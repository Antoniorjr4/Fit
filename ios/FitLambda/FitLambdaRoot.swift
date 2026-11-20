import SwiftUI
import Charts

enum FitTab: Hashable { case today, trends, band, profile }
enum FitSheet: String, Identifiable {
    case goal, heart, sleep, welcome, pairing, faces, health, privacy, sync, name, language, scenarios, permissions, diagnostics, live
    var id: String { rawValue }
}

struct FitLambdaRoot: View {
    @EnvironmentObject private var demo: DemoStore
    @EnvironmentObject private var link: BandLink
    @Environment(\.colorScheme) private var scheme
    @State private var tab: FitTab = .today
    @State private var sheet: FitSheet?
    private var p: Palette { Palette(scheme) }

    var body: some View {
        TabView(selection: $tab) {
            TodayScreen(tab: $tab, sheet: $sheet)
                .tabItem { Label(demo.t("tab.today"), systemImage: "house.fill") }.tag(FitTab.today)
            TrendsScreen(sheet: $sheet)
                .tabItem { Label(demo.t("tab.trends"), systemImage: "chart.bar.fill") }.tag(FitTab.trends)
            BandScreen(sheet: $sheet)
                .tabItem { Label(demo.t("tab.band"), systemImage: "applewatch") }.tag(FitTab.band)
            ProfileScreen(sheet: $sheet)
                .tabItem { Label(demo.t("tab.profile"), systemImage: "person.fill") }.tag(FitTab.profile)
        }
        .tint(p.accent)
        .sheet(item: $sheet) { item in
            Group {
                switch item {
                case .language: LanguagePickerScreen(isFirstLaunch: false)
                case .scenarios:
                    ScenarioPickerScreen()
                        .interactiveDismissDisabled()
                case .permissions: PermissionsScreen()
                case .diagnostics: BandDiagnosticsScreen()
                case .live: LiveBandScreen()
                default: FitDetailSheet(kind: item)
                }
            }
            .environmentObject(demo)
            .environmentObject(link)
            .environment(\.locale, demo.language.locale)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}

struct Page<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    var scrollID = "page.scroll"
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) { content }
                .padding(.horizontal, 22).padding(.top, 20).padding(.bottom, 28)
                .frame(maxWidth: 580)
                .frame(maxWidth: .infinity)
        }.background(Palette(scheme).background.ignoresSafeArea())
            .accessibilityIdentifier(scrollID)
    }
}

struct Card<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 16) { content }
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette(scheme).surface, in: RoundedRectangle(cornerRadius: 26))
            .overlay(RoundedRectangle(cornerRadius: 26).stroke(Palette(scheme).line, lineWidth: 1))
    }
}

struct Kicker: View {
    @Environment(\.colorScheme) private var scheme
    let text: String
    var body: some View {
        Text(text).font(.caption2.weight(.medium)).tracking(1.6)
            .foregroundStyle(Palette(scheme).muted)
    }
}

struct DemoNote: View {
    @EnvironmentObject private var demo: DemoStore
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Text(demo.t("demo.note"))
            .font(.caption).foregroundStyle(Palette(scheme).muted).multilineTextAlignment(.center)
            .frame(maxWidth: .infinity).padding(.top, 8)
    }
}

struct PrimaryAction: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var isEnabled
    let title: String
    let symbol: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 16).padding(.vertical, 8)
        }
        .foregroundStyle(Palette(scheme).ink)
        .background(Palette(scheme).accent, in: RoundedRectangle(cornerRadius: 18))
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.45)
    }
}

struct TodayScreen: View {
    @EnvironmentObject private var demo: DemoStore
    @EnvironmentObject private var link: BandLink
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var textSize
    @Binding var tab: FitTab
    @Binding var sheet: FitSheet?
    private var p: Palette { Palette(scheme) }
    var body: some View {
        Page {
            Kicker(text: demo.date("EEEE d MMM").uppercased(with: demo.language.locale))
            HStack {
                Text(demo.t("today.greeting", demo.name))
                    .font(.largeTitle.weight(.semibold)).tracking(-1.2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("today.greeting")
                Spacer()
                Button { tab = .profile } label: {
                    Text(String(demo.name.prefix(1)).uppercased()).font(.subheadline)
                        .frame(width: 48, height: 48).background(p.surface, in: Circle())
                }.accessibilityLabel(demo.t("today.openProfile"))
            }
            HStack {
                Button { tab = .band } label: {
                    Label(demo.t("today.device"), systemImage: "applewatch").frame(minHeight: 44)
                }
                Spacer()
                Label(demo.hasMetrics ? demo.percent(0.78) : "—", systemImage: "battery.75percent").foregroundStyle(p.accent)
            }.font(.caption).foregroundStyle(p.muted)
            if demo.scenario != .standard && demo.scenario != .firstUse {
                ScenarioStatusCard(sheet: $sheet)
            }
            if demo.recoveryNotice {
                Text(demo.t("state.recovered")).font(.caption).foregroundStyle(p.accent)
                    .accessibilityIdentifier("state.recovered")
            }
            if demo.hasMetrics {
                Card {
                    HStack {
                        Kicker(text: demo.t("today.movement"))
                        Spacer()
                        Button { sheet = .goal } label: {
                            Image(systemName: "target").frame(width: 44, height: 44)
                        }.accessibilityLabel(demo.t("goal.edit"))
                            .accessibilityIdentifier("goal.open")
                    }
                    ActivityArc(steps: demo.steps, goal: demo.goal)
                    Text(demo.goal > Double(demo.steps)
                         ? demo.t("today.remaining", demo.number(Int(demo.goal) - demo.steps))
                         : demo.t("today.goalReached"))
                        .font(.caption).foregroundStyle(p.muted).frame(maxWidth: .infinity)
                    Divider()
                    statsLayout {
                        Stat(value: demo.decimal(5.8), unit: "km", label: demo.t("stat.distance"))
                        Divider()
                        Stat(value: demo.number(382), unit: "kcal", label: demo.t("stat.energy"))
                        Divider()
                        Stat(value: demo.number(42), unit: "min", label: demo.t("stat.active"))
                    }.fixedSize(horizontal: false, vertical: true)
                }
                Text(demo.t("today.body")).font(.headline)
                if textSize.isAccessibilitySize {
                    VStack(spacing: 12) { vitalCards }
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) { vitalCards }
                        VStack(spacing: 12) { vitalCards }
                    }
                }
                Button { tab = .trends } label: {
                    Card {
                        Label(demo.t("today.insightTitle"), systemImage: "sparkles").font(.subheadline.weight(.medium))
                        Text(demo.t("today.insight"))
                            .font(.caption).foregroundStyle(p.muted)
                    }
                }.buttonStyle(.plain)
            } else {
                EmptyMetricsCard(kind: "today") { sheet = .pairing }
            }
            DemoNote()
        }
    }
    private var statsLayout: AnyLayout {
        textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(spacing: 8))
    }
    @ViewBuilder private var vitalCards: some View {
        if let heart = link.heart {
            // A reading received from the band over Bluetooth, with its own time.
            VitalTile(title: demo.t("vital.heart"), value: demo.number(heart.bpm), unit: demo.t("unit.bpm"), detail: demo.t("live.heart.detail", demo.stamp(heart.at)), symbol: "heart.fill", color: p.pink) { sheet = .live }
                .accessibilityIdentifier("heart.live")
        } else {
            VitalTile(title: demo.t("vital.heart"), value: demo.number(68), unit: demo.t("unit.bpm"), detail: demo.t("heart.lastReading", demo.date("jm")), symbol: "heart", color: p.pink) { sheet = .heart }
                .accessibilityIdentifier("heart.open")
        }
        if demo.hasSleep {
            VitalTile(title: demo.t("vital.sleep"), value: demo.t("duration.hm", demo.number(7), demo.number(32)), unit: "", detail: demo.t("sleep.total"), symbol: "moon", color: p.purple) { sheet = .sleep }
                .accessibilityIdentifier("sleep.open")
        } else {
            EmptyMetricsCard(kind: "sleep") { sheet = .sync }
        }
    }
}

struct ActivityArc: View {
    @EnvironmentObject private var demo: DemoStore
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var textSize
    let steps: Int
    let goal: Double
    private var p: Palette { Palette(scheme) }
    var body: some View {
        Group {
            if textSize >= .xxxLarge {
                VStack(spacing: 16) {
                    Text(demo.number(steps)).font(.largeTitle.weight(.semibold)).monospacedDigit()
                    Text(demo.t("goal.ofSteps", demo.number(Int(goal)))).font(.body).foregroundStyle(p.muted)
                    ProgressView(value: min(Double(steps) / goal, 1)).tint(p.accent)
                    Text(demo.t("goal.percent", demo.percent(Double(steps) / goal)))
                        .font(.headline).foregroundStyle(p.accent)
                }.frame(maxWidth: .infinity).padding(.vertical, 12)
            } else {
                arc.frame(height: 245)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(demo.t("goal.accessibility", demo.number(steps), demo.number(Int(goal))))
        .accessibilityIdentifier("today.progress")
    }
    private var arc: some View {
        ZStack {
            Circle().trim(from: 0, to: 0.75).stroke(p.line, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                .rotationEffect(.degrees(135))
            Circle().trim(from: 0, to: CGFloat(min(Double(steps) / goal, 1)) * 0.75)
                .stroke(p.accent, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                .rotationEffect(.degrees(135))
            VStack(spacing: 9) {
                Image(systemName: "figure.walk").font(.title3).foregroundStyle(p.accent)
                Text(demo.number(steps)).font(.system(size: 48, weight: .semibold, design: .rounded)).minimumScaleFactor(0.7)
                Text(demo.t("goal.ofSteps", demo.number(Int(goal)))).font(.caption).foregroundStyle(p.muted)
            }.padding(.bottom, 20)
            VStack { Spacer(); Text(demo.t("goal.percent", demo.percent(Double(steps) / goal))).font(.caption.weight(.semibold)).foregroundStyle(p.accent).padding(.bottom, 8) }
        }.frame(maxWidth: 245).frame(maxWidth: .infinity)
    }
}

struct Stat: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var textSize
    let value: String
    let unit: String
    let label: String
    var body: some View {
        VStack(alignment: textSize.isAccessibilitySize ? .leading : .center, spacing: 7) {
            (Text(value).font(.title3.weight(.semibold)) + Text(" \(unit)").font(.caption2))
            Text(label).font(.caption2).foregroundStyle(Palette(scheme).muted)
        }.frame(maxWidth: .infinity, alignment: textSize.isAccessibilitySize ? .leading : .center)
            .accessibilityElement(children: .combine)
    }
}

struct VitalTile: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    let value: String
    let unit: String
    let detail: String
    let symbol: String
    let color: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 13) {
                Label(title, systemImage: symbol).font(.caption).foregroundStyle(color)
                (Text(value).font(.title.weight(.medium)) + Text(" \(unit)").font(.caption))
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail).font(.caption2).foregroundStyle(Palette(scheme).muted)
                HStack(alignment: .center, spacing: 4) {
                    ForEach(0..<15) { i in Capsule().fill(color.opacity(i % 3 == 0 ? 0.4 : 0.8)).frame(height: CGFloat(8 + (i * 7) % 21)) }
                }.frame(height: 29).accessibilityHidden(true)
            }.padding(17).frame(maxWidth: .infinity, alignment: .leading)
                .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 23))
        }.buttonStyle(.plain)
    }
}

struct TrendsScreen: View {
    @EnvironmentObject private var demo: DemoStore
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var textSize
    @Binding var sheet: FitSheet?
    @State private var period = 0
    private var data: [StepDay] { period == 0 ? DemoStore.week : DemoStore.month }
    private var p: Palette { Palette(scheme) }
    var body: some View {
        Page {
            Kicker(text: demo.t("trends.kicker"))
            Text(demo.t("trends.title")).font(.largeTitle.weight(.semibold)).tracking(-1.2)
                .accessibilityIdentifier("trends.title")
            Text(demo.t("trends.subtitle")).font(.subheadline).foregroundStyle(p.muted)
            if demo.hasMetrics {
                Picker(demo.t("trends.period"), selection: $period) {
                    Text(demo.t("trends.week")).tag(0); Text(demo.t("trends.month")).tag(1)
                }.pickerStyle(.segmented)
                    .accessibilityIdentifier("trends.period")
                Text(demo.t("trends.range", period == 0 ? "9 — 15" : "1 — 15", demo.date("MMMM")))
                    .font(.caption).foregroundStyle(p.muted).frame(maxWidth: .infinity)
                    .accessibilityIdentifier("trends.range")
                Card {
                    Text(demo.number(data.map(\.steps).reduce(0, +) / data.count))
                        .font(.largeTitle.weight(.semibold)).monospacedDigit()
                    Text(demo.t("trends.average")).font(.caption).foregroundStyle(p.muted)
                    if textSize.isAccessibilitySize {
                        ForEach(data) { day in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(demo.t("trends.daySteps", day.label(in: demo), demo.number(day.steps))).font(.body)
                                ProgressView(value: Double(day.steps), total: 12000).tint(p.accent)
                                    .accessibilityHidden(true)
                            }.padding(.vertical, 4)
                        }
                    } else {
                        Chart(data) { day in
                            BarMark(x: .value(demo.t("trends.period"), day.label(in: demo)), y: .value(demo.t("steps.label"), day.steps))
                                .foregroundStyle(p.accent.opacity(day.day == data.last?.day ? 1 : 0.75))
                                .cornerRadius(5)
                                .accessibilityLabel(demo.t("trends.daySteps", day.label(in: demo), demo.number(day.steps)))
                        }
                        .chartYScale(domain: 0...12000)
                        .chartXAxis {
                            AxisMarks(values: .automatic) { value in
                                AxisGridLine()
                                AxisValueLabel {
                                    if let day = value.as(String.self) {
                                        Text(day).foregroundStyle(p.muted)
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks(values: .automatic) { value in
                                AxisGridLine()
                                AxisValueLabel {
                                    if let steps = value.as(Int.self) {
                                        Text(demo.number(steps)).foregroundStyle(p.muted)
                                    }
                                }
                            }
                        }
                        .frame(height: 210)
                    }
                }
                Text(demo.t("trends.closer")).font(.headline)
                Card {
                    Label(demo.t("trends.consistency"), systemImage: "target")
                    Divider()
                    Label(demo.t("trends.bestDay"), systemImage: "figure.walk")
                }.font(.subheadline)
            } else {
                EmptyMetricsCard(kind: "trends") { sheet = .pairing }
            }
            DemoNote()
        }
    }
}

struct BandIllustration: View {
    @EnvironmentObject private var demo: DemoStore
    let face: Int
    private var tone: Color { face == 1 ? Color(hex: 0xEFF1DF) : face == 2 ? Color(hex: 0x251B2E) : Color(hex: 0x0A100A) }
    private var ink: Color { face == 1 ? Color(hex: 0x2A3122) : face == 2 ? Color(hex: 0xD3BAFF) : Color(hex: 0xD4F68A) }
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24).fill(LinearGradient(colors: [Color(hex: 0x1A211C), Color(hex: 0x39433A), Color(hex: 0x171E19)], startPoint: .leading, endPoint: .trailing)).frame(width: 79, height: 268)
            RoundedRectangle(cornerRadius: 26).fill(LinearGradient(colors: [.gray, Color(hex: 0xCAD3C7), .gray], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 108, height: 151)
            RoundedRectangle(cornerRadius: 22).fill(tone).frame(width: 99, height: 143)
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(.black, lineWidth: 6))
            VStack(spacing: 3) {
                Text(demo.date("EEE d MMM").uppercased(with: demo.language.locale)).font(.system(size: 7, weight: .medium)).tracking(1)
                Text("09\n41").font(.system(size: 44, weight: face == 1 ? .light : .bold, design: .rounded)).lineSpacing(-11)
                Text(demo.hasMetrics ? demo.t("steps.count", demo.number(demo.steps)).uppercased(with: demo.language.locale) : "—").font(.system(size: 6)).tracking(1)
            }.foregroundStyle(ink)
        }.frame(height: 280).rotationEffect(.degrees(-12))
            .shadow(color: .black.opacity(0.15), radius: 10, x: 12, y: 14)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(demo.t("band.illustration"))
            .accessibilityValue([demo.t("face.rhythm"), demo.t("face.essential"), demo.t("face.night")][face])
            .accessibilityIdentifier("band.illustration")
    }
}

struct BandScreen: View {
    @EnvironmentObject private var demo: DemoStore
    @EnvironmentObject private var link: BandLink
    @Environment(\.colorScheme) private var scheme
    @Binding var sheet: FitSheet?
    var body: some View {
        Page {
            Kicker(text: demo.t("band.kicker"))
            Text(demo.t("band.title")).font(.largeTitle.weight(.semibold)).tracking(-1.2)
                .accessibilityIdentifier("band.title")
            Text(demo.t("band.subtitle")).font(.subheadline).foregroundStyle(Palette(scheme).muted)
            LiveBandCard(sheet: $sheet)
            BandConnectionPanel(sheet: $sheet)
            BandIllustration(face: demo.face).frame(maxWidth: .infinity)
            VStack(spacing: 8) {
                Text("Galaxy Fit3").font(.title2.weight(.semibold))
                if let battery = link.battery {
                    Label(demo.t("live.battery", demo.percent(Double(battery) / 100)), systemImage: "battery.75percent").font(.caption)
                } else {
                    Label(demo.hasMetrics ? demo.t("band.battery", demo.percent(0.78)) : demo.t("band.noBattery"), systemImage: "battery.75percent").font(.caption)
                }
            }.frame(maxWidth: .infinity)
            Card {
                Button { sheet = .faces } label: { RowLabel(title: demo.t("band.style"), symbol: "paintpalette") }
                    .accessibilityIdentifier("faces.open")
                Divider()
                Button { sheet = .sync } label: { RowLabel(title: demo.t("band.sync"), symbol: "arrow.triangle.2.circlepath") }
                    .accessibilityIdentifier("sync.open")
            }.buttonStyle(.plain)
            DemoNote()
        }
    }
}

struct RowLabel: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    let symbol: String
    var body: some View {
        HStack(spacing: 12) {
            Label(title, systemImage: symbol); Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Palette(scheme).muted)
        }.font(.subheadline).frame(minHeight: 44).contentShape(Rectangle())
    }
}

struct ProfileScreen: View {
    @EnvironmentObject private var demo: DemoStore
    @Environment(\.colorScheme) private var scheme
    @Binding var sheet: FitSheet?
    var body: some View {
        Page {
            Kicker(text: demo.t("profile.kicker"))
            Text(demo.t("profile.title")).font(.largeTitle.weight(.semibold)).tracking(-1.2)
                .accessibilityIdentifier("profile.title")
            Button { sheet = .name } label: {
                HStack(spacing: 15) {
                    Image(systemName: "person.crop.circle.fill").font(.system(size: 54))
                    VStack(alignment: .leading, spacing: 7) {
                        Text(demo.name).font(.title2.weight(.semibold))
                        Text(demo.t("profile.subtitle")).font(.caption).foregroundStyle(Palette(scheme).muted)
                    }
                    Spacer(); Image(systemName: "pencil")
                }
            }.buttonStyle(.plain).accessibilityIdentifier("name.open")
            Kicker(text: demo.t("profile.daily"))
            Card {
                Button { sheet = .goal } label: { RowLabel(title: demo.t("profile.goal", demo.number(Int(demo.goal))), symbol: "target") }
                    .accessibilityIdentifier("profile.goal")
                Divider()
                Toggle(demo.t("profile.dark"), isOn: $demo.isDark)
                    .accessibilityIdentifier("profile.dark-mode")
                Divider()
                Toggle(demo.t("profile.reminders"), isOn: $demo.reminders)
                    .accessibilityIdentifier("profile.reminders")
                Text(demo.t("profile.remindersNote")).font(.caption).foregroundStyle(Palette(scheme).muted)
            }.buttonStyle(.plain).font(.subheadline)
            Card {
                Button { sheet = .language } label: {
                    RowLabel(title: demo.t("profile.language", demo.language.nativeName), symbol: "globe")
                }.accessibilityIdentifier("language.open")
                Divider()
                Button { sheet = .permissions } label: {
                    RowLabel(title: demo.t("permissions.title"), symbol: "hand.raised")
                }.accessibilityIdentifier("permissions.open")
                Divider()
                Button { sheet = .scenarios } label: {
                    RowLabel(title: demo.t("scenarios.title"), symbol: "square.stack.3d.up")
                }.accessibilityIdentifier("scenarios.open")
            }.buttonStyle(.plain)
            Kicker(text: demo.t("profile.data"))
            Card {
                Button { sheet = .health } label: { RowLabel(title: demo.t("health.planned"), symbol: "heart") }
                    .accessibilityIdentifier("health.open")
                Divider()
                Button { sheet = .privacy } label: { RowLabel(title: demo.t("profile.privacy"), symbol: "hand.raised") }
                    .accessibilityIdentifier("privacy.open")
                Divider()
                Button { sheet = .welcome } label: { RowLabel(title: demo.t("profile.welcome"), symbol: "sparkles") }
                    .accessibilityIdentifier("welcome.open")
            }.buttonStyle(.plain)
            Text(demo.t("profile.version")).font(.caption).foregroundStyle(Palette(scheme).muted).multilineTextAlignment(.center).frame(maxWidth: .infinity)
            DemoNote()
        }
    }
}
