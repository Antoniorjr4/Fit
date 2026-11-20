import SwiftUI
import UIKit

extension DemoStore {
    /// Time of a real reading in the device's own time zone; adds the date when it is not today.
    func stamp(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return date.formatted(.dateTime.hour().minute().second().locale(language.locale))
        }
        return date.formatted(.dateTime.day().month(.abbreviated).hour().minute().locale(language.locale))
    }

    func liveStatus(_ phase: BandPhase) -> String {
        switch phase {
        case .idle: return self.t("live.phase.idle")
        case .poweredOff: return self.t("live.phase.off")
        case .unauthorized: return self.t("live.phase.denied")
        case .unsupported: return self.t("live.phase.unsupported")
        case .scanning: return self.t("live.phase.scanning")
        case .connecting: return self.t("live.phase.connecting")
        case .discovering: return self.t("live.phase.discovering")
        case .connected: return self.t("live.phase.connected")
        case .reconnecting: return self.t("live.phase.reconnecting")
        case .failed: return self.t("live.phase.failed")
        }
    }
}

/// Entry point on the Band tab. Everything it shows comes from the real radio.
struct LiveBandCard: View {
    @EnvironmentObject private var demo: DemoStore
    @EnvironmentObject private var link: BandLink
    @Environment(\.colorScheme) private var scheme
    @Binding var sheet: FitSheet?

    var body: some View {
        Card {
            Kicker(text: demo.t("live.kicker"))
            Label(link.deviceName ?? demo.t("live.card.title"), systemImage: "dot.radiowaves.left.and.right")
                .font(.headline)
            Text(demo.liveStatus(link.phase))
                .font(.subheadline).foregroundStyle(Palette(scheme).muted)
                .accessibilityIdentifier("live.status")
            if let heart = link.heart {
                Text(demo.t("live.heart.line", demo.number(heart.bpm), demo.stamp(heart.at)))
                    .font(.subheadline).foregroundStyle(Palette(scheme).pink)
            }
            PrimaryAction(title: demo.t(link.hasRememberedBand ? "live.open" : "live.find"),
                          symbol: "antenna.radiowaves.left.and.right") { sheet = .live }
                .accessibilityIdentifier("live.open")
        }
    }
}

struct LiveBandScreen: View {
    @EnvironmentObject private var demo: DemoStore
    @EnvironmentObject private var link: BandLink
    @Environment(\.colorScheme) private var scheme
    private var p: Palette { Palette(scheme) }

    var body: some View {
        SheetFrame(title: demo.t("live.title"), identifier: "sheet.live.title") {
            Text(demo.t("live.intro")).foregroundStyle(p.muted)
            statusCard
            if link.phase == .connected || link.heart != nil { heartCard }
            if link.phase == .connected { detailsCard }
            if link.hasRememberedBand { listenCard }
            logCard
        }
    }

    @ViewBuilder private var statusCard: some View {
        Card {
            HStack(spacing: 10) {
                if link.phase == .scanning || link.phase == .connecting
                    || link.phase == .discovering || link.phase == .reconnecting {
                    ProgressView().accessibilityHidden(true)
                }
                Text(demo.liveStatus(link.phase)).font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("live.phase")
            }
            if let name = link.deviceName, link.phase != .scanning {
                Label(name, systemImage: "applewatch").font(.subheadline).foregroundStyle(p.muted)
            }
            if let seen = link.lastSeen, link.phase != .connected {
                Text(demo.t("live.lastSeen", demo.stamp(seen))).font(.caption).foregroundStyle(p.muted)
            }
            phaseActions
        }
    }

    @ViewBuilder private var phaseActions: some View {
        switch link.phase {
        case .idle, .failed:
            if link.phase == .failed {
                Text(demo.t(link.needsForgetInSettings ? "live.pairing.help" : "live.failed.help"))
                    .font(.subheadline).foregroundStyle(p.muted)
                    .accessibilityIdentifier("live.failed.help")
            }
            if !link.found.isEmpty {
                foundList
            } else if link.scanEnded {
                Text(demo.t("live.scan.empty")).font(.subheadline).foregroundStyle(p.muted)
            }
            if link.hasRememberedBand {
                PrimaryAction(title: demo.t("live.reconnect"), symbol: "link") { link.reconnect() }
                    .accessibilityIdentifier("live.reconnect")
            }
            PrimaryAction(title: demo.t(link.scanEnded || !link.found.isEmpty ? "live.scan.again" : "live.scan"),
                          symbol: "magnifyingglass") { link.startScan() }
                .accessibilityIdentifier("live.scan")
            if link.hasRememberedBand { forgetButton }
        case .scanning:
            if link.found.isEmpty {
                Text(demo.t("live.scan.hint")).font(.subheadline).foregroundStyle(p.muted)
            } else {
                foundList
            }
            secondary(demo.t("live.scan.stop")) { link.stopScan() }
        case .poweredOff:
            Text(demo.t("live.off.help")).font(.subheadline).foregroundStyle(p.muted)
        case .unauthorized:
            Text(demo.t("live.denied.help")).font(.subheadline).foregroundStyle(p.muted)
            PrimaryAction(title: demo.t("live.settings"), symbol: "gearshape") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
        case .unsupported:
            Text(demo.t("live.unsupported.help")).font(.subheadline).foregroundStyle(p.muted)
        case .connecting, .discovering, .reconnecting:
            secondary(demo.t("live.cancel")) { link.disconnect() }
        case .connected:
            secondary(demo.t("live.disconnect")) { link.disconnect() }
            forgetButton
        }
    }

    @ViewBuilder private var foundList: some View {
        Text(demo.t("live.scan.pick")).font(.caption).foregroundStyle(p.muted)
        ForEach(link.found.prefix(12)) { band in
            Button { link.connect(band.id) } label: {
                HStack(spacing: 12) {
                    Image(systemName: band.isLikelyFit ? "applewatch" : "dot.radiowaves.right")
                        .foregroundStyle(band.isLikelyFit ? p.accent : p.muted)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(band.name).font(.body.weight(band.isLikelyFit ? .semibold : .regular))
                        if band.isLikelyFit {
                            Text(demo.t("live.scan.likely")).font(.caption).foregroundStyle(p.accent)
                        } else if band.alreadyLinked {
                            Text(demo.t("live.scan.linked")).font(.caption).foregroundStyle(p.muted)
                        }
                    }
                    Spacer(minLength: 8)
                    if let rssi = band.rssi {
                        Text(demo.t("live.signal.value", demo.number(rssi)))
                            .font(.caption).monospacedDigit().foregroundStyle(p.muted)
                    }
                }.frame(minHeight: 48).contentShape(Rectangle())
            }.buttonStyle(.plain)
            Divider()
        }
    }

    @ViewBuilder private var heartCard: some View {
        Card {
            Label(demo.t("live.heart.title"), systemImage: "heart.fill").font(.subheadline).foregroundStyle(p.pink)
            if let heart = link.heart {
                (Text(demo.number(heart.bpm)).font(.system(size: 56, weight: .semibold, design: .rounded))
                    + Text(" " + demo.t("unit.bpm")).font(.title3))
                    .monospacedDigit()
                    .accessibilityIdentifier("live.heart.value")
                Text(demo.t("live.heart.detail", demo.stamp(heart.at))).font(.caption).foregroundStyle(p.muted)
                if link.sessionHeartCount > 0 {
                    Text(demo.t("live.heart.count", demo.number(link.sessionHeartCount)))
                        .font(.caption).foregroundStyle(p.muted)
                }
            } else {
                Text(demo.t("live.heart.waiting")).font(.subheadline).foregroundStyle(p.muted)
            }
        }
    }

    @ViewBuilder private var detailsCard: some View {
        Card {
            Text(demo.t("live.info.title")).font(.headline)
            if let rssi = link.rssi {
                row(demo.t("live.signal"), demo.t("live.signal.value", demo.number(rssi)))
            }
            if let battery = link.battery {
                row(demo.t("live.battery.label"), demo.percent(Double(battery) / 100))
            }
            if let value = link.info[.manufacturer] { row(demo.t("live.info.manufacturer"), value) }
            if let value = link.info[.model] { row(demo.t("live.info.model"), value) }
            if let value = link.info[.firmware] { row(demo.t("live.info.firmware"), value) }
            if let value = link.info[.hardware] { row(demo.t("live.info.hardware"), value) }
            if let value = link.info[.software] { row(demo.t("live.info.software"), value) }
            Text(demo.t("live.services", demo.number(link.services.count),
                        demo.number(link.services.reduce(0) { $0 + $1.characteristics.count })))
                .font(.caption).foregroundStyle(p.muted)
        }
    }

    @ViewBuilder private var listenCard: some View {
        Card {
            Toggle(demo.t("live.listen"), isOn: Binding(
                get: { link.listenProprietary },
                set: { link.setListenProprietary($0) }))
                .font(.subheadline)
            Text(demo.t("live.listen.note")).font(.caption).foregroundStyle(p.muted)
            Divider()
            Toggle(demo.t("live.listen.sap"), isOn: Binding(
                get: { link.listenSAP },
                set: { link.setListenSAP($0) }))
                .font(.subheadline)
            Text(demo.t("live.listen.sap.note")).font(.caption).foregroundStyle(p.muted)
            if link.listenAutoDisabled {
                Text(demo.t("live.listen.autoOff")).font(.caption).foregroundStyle(p.pink)
            }
            if link.proprietaryFrames > 0 {
                Text(demo.t("live.frames", demo.number(link.proprietaryFrames)))
                    .font(.caption).foregroundStyle(p.accent)
            }
        }
    }

    @ViewBuilder private var logCard: some View {
        Card {
            Text(demo.t("live.log.title")).font(.headline)
            if link.log.isEmpty {
                Text(demo.t("live.log.empty")).font(.caption).foregroundStyle(p.muted)
            } else {
                ForEach(link.log.suffix(14)) { line in
                    Text(demo.stamp(line.at) + "  " + line.text)
                        .font(.caption2.monospaced()).foregroundStyle(p.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ShareLink(item: link.exportText()) {
                    Label(demo.t("live.log.share"), systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                }.foregroundStyle(p.accent)
            }
        }
    }

    private var forgetButton: some View {
        Button(role: .destructive) { link.forget() } label: {
            Text(demo.t("live.forget")).font(.subheadline).frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private func secondary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
        }.foregroundStyle(p.accent)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(p.muted)
            Spacer(minLength: 12)
            Text(value).multilineTextAlignment(.trailing)
        }.font(.subheadline).accessibilityElement(children: .combine)
    }
}
