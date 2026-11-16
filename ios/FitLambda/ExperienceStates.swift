import SwiftUI

enum PreviewScenario: String, CaseIterable, Identifiable {
    case standard, firstUse, permissionNeeded, permissionDenied, bluetoothOff
    case notFound, disconnected, syncFailed, partial
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .standard: "sparkles"
        case .firstUse: "tray"
        case .permissionNeeded, .permissionDenied: "hand.raised"
        case .bluetoothOff: "antenna.radiowaves.left.and.right.slash"
        case .notFound: "magnifyingglass"
        case .disconnected: "link"
        case .syncFailed: "exclamationmark.arrow.triangle.2.circlepath"
        case .partial: "moon"
        }
    }
    var actionKey: String {
        switch self {
        case .standard, .partial, .syncFailed: "state.retry"
        case .firstUse: "band.connect"
        case .permissionNeeded: "state.reviewPermission"
        case .permissionDenied, .bluetoothOff: "state.guidance"
        case .notFound: "state.searchAgain"
        case .disconnected: "state.reconnect"
        }
    }
}

struct SheetFrame<Content: View>: View {
    @EnvironmentObject private var demo: DemoStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    let title: String
    let identifier: String
    @ViewBuilder var content: Content
    var body: some View {
        NavigationStack {
            Page {
                Text(title).font(.largeTitle.weight(.semibold)).tracking(-1)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(identifier)
                content
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").frame(minWidth: 44, minHeight: 44)
                    }.accessibilityLabel(demo.t("common.close"))
                        .accessibilityIdentifier("sheet.close")
                }
            }
        }.tint(Palette(scheme).accent)
    }
}

struct LanguagePickerScreen: View {
    @EnvironmentObject private var demo: DemoStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var draft: AppLanguage = .english
    let isFirstLaunch: Bool
    private var p: Palette { Palette(scheme) }
    var body: some View {
        NavigationStack {
            Page {
                HStack {
                    Text("FitΛ").font(.title2.weight(.semibold))
                    Spacer()
                    Image(systemName: "globe").font(.title2).foregroundStyle(p.accent)
                }.padding(.top, 10)
                Text(draft.text("language.title")).font(.largeTitle.weight(.semibold)).tracking(-1)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("language.title")
                Text(draft.text("language.subtitle")).font(.subheadline).foregroundStyle(p.muted)
                VStack(spacing: 10) {
                    ForEach(AppLanguage.allCases) { language in
                        Button { draft = language } label: {
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(language.nativeName).font(.body.weight(.medium))
                                        .fixedSize(horizontal: false, vertical: true)
                                    if language == AppLanguage.recommended() {
                                        Text(draft.text("language.recommended")).font(.caption).foregroundStyle(p.muted)
                                    }
                                }
                                Spacer(minLength: 8)
                                Image(systemName: draft == language ? "checkmark.circle.fill" : "circle")
                                    .font(.title3).foregroundStyle(draft == language ? p.accent : p.muted)
                            }.padding(18).frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                                .background(p.surface, in: RoundedRectangle(cornerRadius: 20))
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(draft == language ? p.accent : p.line, lineWidth: 1))
                        }.buttonStyle(.plain)
                            .accessibilityLabel(language.nativeName)
                            .accessibilityAddTraits(draft == language ? .isSelected : [])
                            .accessibilityIdentifier("language.\(language.rawValue)")
                    }
                }
                Text(draft.text("language.changeLater")).font(.caption).foregroundStyle(p.muted)
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryAction(title: draft.text(isFirstLaunch ? "language.continue" : "language.save"), symbol: "arrow.right") {
                    demo.selectLanguage(draft)
                    if !isFirstLaunch { dismiss() }
                }.accessibilityIdentifier("language.save")
                    .padding(.horizontal, 22).padding(.vertical, 12).background(p.background)
            }
            .toolbar {
                if !isFirstLaunch {
                    ToolbarItem(placement: .confirmationAction) {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").frame(minWidth: 44, minHeight: 44)
                        }.accessibilityLabel(draft.text("common.close"))
                            .accessibilityIdentifier("sheet.close")
                    }
                }
            }
        }.tint(p.accent)
            .onAppear { draft = demo.language }
    }
}

struct ScenarioPickerScreen: View {
    @EnvironmentObject private var demo: DemoStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        SheetFrame(title: demo.t("scenarios.title"), identifier: "sheet.scenarios.title") {
            Text(demo.t("scenarios.subtitle")).foregroundStyle(Palette(scheme).muted)
            ForEach(PreviewScenario.allCases) { scenario in
                Button { demo.setScenario(scenario); dismiss() } label: {
                    Card {
                        Label(demo.t("state.\(scenario.rawValue).title"), systemImage: scenario.symbol)
                            .font(.headline)
                        Text(demo.t("state.\(scenario.rawValue).body")).font(.caption).foregroundStyle(Palette(scheme).muted)
                        if demo.scenario == scenario {
                            Label(demo.t("common.selected"), systemImage: "checkmark.circle.fill")
                                .font(.caption).foregroundStyle(Palette(scheme).accent)
                        }
                    }
                }.buttonStyle(.plain).accessibilityIdentifier("scenario.\(scenario.rawValue)")
            }
        }
    }
}

struct ScenarioStatusCard: View {
    @EnvironmentObject private var demo: DemoStore
    @Environment(\.colorScheme) private var scheme
    @Binding var sheet: FitSheet?
    var body: some View {
        Card {
            Kicker(text: demo.t("state.preview"))
            Label(demo.t("state.\(demo.scenario.rawValue).title"), systemImage: demo.scenario.symbol)
                .font(.headline).accessibilityIdentifier("state.title")
            Text(demo.t("state.\(demo.scenario.rawValue).body"))
                .font(.subheadline).foregroundStyle(Palette(scheme).muted)
                .accessibilityIdentifier("state.body")
            if demo.hasMetrics {
                Text(demo.t("state.lastSample", demo.date("dMMMyjm")))
                    .font(.caption).foregroundStyle(Palette(scheme).muted)
            }
            PrimaryAction(title: demo.t(demo.scenario.actionKey), symbol: "arrow.right") {
                switch demo.scenario {
                case .permissionNeeded, .permissionDenied, .bluetoothOff: sheet = .permissions
                case .standard, .partial, .syncFailed: demo.retryPreview()
                case .firstUse, .notFound, .disconnected: sheet = .pairing
                }
            }.accessibilityIdentifier("state.action")
        }
    }
}

struct EmptyMetricsCard: View {
    @EnvironmentObject private var demo: DemoStore
    @Environment(\.colorScheme) private var scheme
    let kind: String
    let action: () -> Void
    var body: some View {
        Card {
            Image(systemName: kind == "sleep" ? "moon" : "chart.xyaxis.line")
                .font(.largeTitle).foregroundStyle(Palette(scheme).accent).padding(.vertical, 8)
            Text(demo.t("empty.\(kind).title")).font(.title2.weight(.semibold))
                .accessibilityIdentifier("empty.\(kind).title")
            Text(demo.t("empty.\(kind).body")).font(.subheadline).foregroundStyle(Palette(scheme).muted)
            Button(action: action) {
                Label(demo.t(kind == "sleep" ? "sync.details" : "empty.connect"), systemImage: "arrow.right")
                    .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
            }.foregroundStyle(Palette(scheme).accent).accessibilityIdentifier("empty.\(kind).action")
        }
    }
}

struct PermissionsScreen: View {
    @EnvironmentObject private var demo: DemoStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        SheetFrame(title: demo.t("permissions.title"), identifier: "sheet.permissions.title") {
            Text(demo.t("permissions.subtitle")).foregroundStyle(Palette(scheme).muted)
            Card {
                Label("Bluetooth", systemImage: "antenna.radiowaves.left.and.right").font(.headline)
                Text(demo.t("permissions.bluetooth")).font(.subheadline)
                if demo.scenario == .bluetoothOff {
                    Text(demo.t("permissions.offHelp")).foregroundStyle(Palette(scheme).muted)
                } else if demo.scenario == .permissionDenied {
                    Text(demo.t("permissions.deniedHelp")).foregroundStyle(Palette(scheme).muted)
                }
            }
            Card {
                Label(demo.t("health.planned"), systemImage: "heart").font(.headline)
                Text(demo.t("permissions.health")).font(.subheadline).foregroundStyle(Palette(scheme).muted)
            }
            PrimaryAction(title: demo.t("permissions.allowDemo"), symbol: "checkmark") {
                demo.setPermissionPreview(granted: true)
                dismiss()
            }.accessibilityIdentifier("permissions.allow")
            Button(demo.t("permissions.denyDemo")) {
                demo.setPermissionPreview(granted: false)
                dismiss()
            }.frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("permissions.deny")
            Text(demo.t("permissions.demoNote")).font(.caption).foregroundStyle(Palette(scheme).muted)
        }
    }
}
