import SwiftUI

struct BandConnectionPanel: View {
    @EnvironmentObject private var demo: DemoStore
    @Binding var sheet: FitSheet?

    var body: some View {
        Card {
            Kicker(text: demo.t("state.preview"))
            Label(demo.t("band.connection.title"), systemImage: "antenna.radiowaves.left.and.right")
                .font(.headline)
            BandConnectionSummary()

            if demo.isSyncingPreview {
                PrimaryAction(title: demo.t("band.sync.finish"), symbol: "checkmark") { demo.retryPreview() }
                    .accessibilityIdentifier("band.sync.finish")
            } else if demo.connectionPreview {
                PrimaryAction(title: demo.t("band.sync.now"), symbol: "arrow.triangle.2.circlepath") {
                    demo.startSyncPreview()
                }.accessibilityIdentifier("band.sync.now")
            } else {
                PrimaryAction(
                    title: demo.t(demo.scenario == .standard ? "band.connect" : demo.scenario.actionKey),
                    symbol: "link"
                ) {
                    switch demo.scenario {
                    case .permissionNeeded, .permissionDenied, .bluetoothOff: sheet = .permissions
                    default: sheet = .pairing
                    }
                }.accessibilityIdentifier("pairing.open")
            }
            Divider()
            Button { sheet = .diagnostics } label: {
                RowLabel(title: demo.t("band.diagnostics"), symbol: "stethoscope")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("band.diagnostics.open")
        }
    }
}

private struct BandConnectionSummary: View {
    @EnvironmentObject private var demo: DemoStore
    @Environment(\.colorScheme) private var scheme

    private var syncLabel: String {
        if demo.isSyncingPreview { return demo.t("band.sync.running") }
        switch demo.scenario {
        case .standard: return demo.t(demo.connectionPreview ? "band.sync.current" : "band.sync.noDevice")
        default: return demo.t("state.\(demo.scenario.rawValue).title")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(demo.t(demo.connectionPreview ? "band.simulated" : "band.connection.none"),
                  systemImage: demo.connectionPreview ? "link" : "link.badge.plus")
                .accessibilityIdentifier("band.status")
            HStack(spacing: 8) {
                if demo.isSyncingPreview { ProgressView().accessibilityHidden(true) }
                Text(syncLabel).accessibilityIdentifier("band.sync.status")
            }
            if demo.hasMetrics && (demo.connectionPreview || demo.scenario != .standard) {
                Text(demo.t("state.lastSample", demo.date("dMMMyjm")))
                    .accessibilityIdentifier("band.sync.history")
            }
        }
        .font(.subheadline)
        .foregroundStyle(Palette(scheme).muted)
    }
}

struct BandDiagnosticsScreen: View {
    @EnvironmentObject private var demo: DemoStore

    var body: some View {
        SheetFrame(title: demo.t("band.diagnostics"), identifier: "sheet.diagnostics.title") {
            Card {
                BandConnectionSummary()
                if demo.scenario != .standard {
                    Text(demo.t("state.\(demo.scenario.rawValue).body"))
                }
            }
            DemoNote()
        }
    }
}
