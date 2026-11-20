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

/// What is known about a face the band reports: its name in the band maker's catalogue and
/// which generic layout the tile should sketch. The tiles are FitΛ's own drawings, not the original artwork.
struct BandFaceInfo {
    enum Sketch { case analog, stacked, bars, ring, stats, photo, trail }
    let name: String
    let sketch: Sketch

    static let known: [Int: BandFaceInfo] = [
        22: BandFaceInfo(name: "Dynamic digital", sketch: .stacked),
        28: BandFaceInfo(name: "Info brick", sketch: .bars),
        46: BandFaceInfo(name: "Minimalist", sketch: .analog),
        79: BandFaceInfo(name: "Step streak", sketch: .trail),
        106: BandFaceInfo(name: "Fitness pro 3", sketch: .stats),
        108: BandFaceInfo(name: "Step count", sketch: .ring),
        254: BandFaceInfo(name: "Photo", sketch: .photo),
    ]
}

/// A small generic sketch of a face layout showing the current time.
struct BandFaceSketch: View {
    let sketch: BandFaceInfo.Sketch
    let tint: Color
    let now: Date

    private var hour: Int { Calendar.current.component(.hour, from: now) }
    private var minute: Int { Calendar.current.component(.minute, from: now) }
    private func two(_ value: Int) -> String { String(format: "%02d", value) }
    private var clock: String { two(hour) + ":" + two(minute) }

    var body: some View {
        switch sketch {
        case .analog:
            ZStack {
                ForEach(0..<12, id: \.self) { tick in
                    Capsule().fill(Color.white.opacity(0.5)).frame(width: 1.5, height: 5)
                        .offset(y: -30).rotationEffect(.degrees(Double(tick) * 30))
                }
                Capsule().fill(Color.white).frame(width: 3, height: 16).offset(y: -8)
                    .rotationEffect(.degrees(Double(hour % 12) * 30 + Double(minute) / 2))
                Capsule().fill(tint).frame(width: 2, height: 24).offset(y: -12)
                    .rotationEffect(.degrees(Double(minute) * 6))
            }
        case .stacked:
            VStack(spacing: -4) {
                Text(two(hour)).foregroundStyle(tint)
                Text(two(minute)).foregroundStyle(Color.white)
            }.font(.system(size: 26, weight: .heavy, design: .rounded).italic())
        case .bars:
            VStack(alignment: .leading, spacing: 4) {
                Text(two(hour)).foregroundStyle(tint)
                Text(two(minute)).foregroundStyle(Color.white)
                ForEach(0..<3, id: \.self) { row in
                    Capsule().fill(tint.opacity(0.7)).frame(width: CGFloat(40 - row * 8), height: 3)
                }
            }.font(.system(size: 18, weight: .semibold, design: .rounded))
        case .ring:
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 10).trim(from: 0, to: 0.6)
                    .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round)).frame(width: 34, height: 34)
                Text(clock).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(Color.white)
            }
        case .stats:
            VStack(spacing: 8) {
                HStack { Capsule().frame(width: 12, height: 3); Spacer(); Capsule().frame(width: 12, height: 3) }
                Text(clock).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(tint)
                HStack { Capsule().frame(width: 12, height: 3); Spacer(); Capsule().frame(width: 12, height: 3) }
            }.foregroundStyle(Color.white.opacity(0.7)).padding(.horizontal, 9)
        case .photo:
            VStack(spacing: 6) {
                Image(systemName: "photo").font(.system(size: 22)).foregroundStyle(tint)
                Text(clock).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(Color.white)
            }
        case .trail:
            VStack(alignment: .leading, spacing: 2) {
                Text(two(hour)).foregroundStyle(tint.opacity(0.7))
                Text(two(minute)).foregroundStyle(Color.white)
                Image(systemName: "figure.walk").font(.system(size: 18)).foregroundStyle(tint).padding(.top, 4)
            }.font(.system(size: 18, weight: .bold, design: .rounded))
        }
    }
}

/// The faces the band itself reports, as tiles. Choosing one switches the band at once.
struct BandFacesGrid: View {
    @EnvironmentObject private var demo: DemoStore
    @EnvironmentObject private var link: BandLink
    @Environment(\.colorScheme) private var scheme
    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 12)]

    var body: some View {
        let p = Palette(scheme)
        TimelineView(.everyMinute) { context in
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(link.faces) { face in
                    let current = face.id == link.currentFaceID
                    let info = BandFaceInfo.known[face.id]
                    let title = info?.name ?? demo.t("band.faces.item", demo.number(face.id))
                    Button { link.selectFace(face) } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16).fill(Color.black)
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(current ? p.accent : p.muted.opacity(0.4), lineWidth: current ? 3 : 1)
                                if let info {
                                    BandFaceSketch(sketch: info.sketch, tint: Color(hex: 0xD4F68A), now: context.date)
                                } else {
                                    Text(demo.number(face.id))
                                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Color.white)
                                }
                            }.frame(width: 76, height: 110).clipShape(RoundedRectangle(cornerRadius: 16))
                            Text(title).font(.caption2.weight(current ? .semibold : .regular))
                                .foregroundStyle(current ? p.accent : p.muted)
                                .lineLimit(1).minimumScaleFactor(0.7)
                            if current {
                                Label(demo.t("band.faces.current"), systemImage: "checkmark.circle.fill")
                                    .font(.caption2).foregroundStyle(p.accent)
                            }
                        }.frame(maxWidth: .infinity, minHeight: 44, alignment: .top).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .accessibilityLabel(title)
                        .accessibilityAddTraits(current ? .isSelected : [])
                }
            }
        }
        Text(demo.t("band.faces.note")).font(.caption).foregroundStyle(p.muted)
    }
}

/// Sleep the band sent for last night, on the Today screen.
struct RealSleepCard: View {
    @EnvironmentObject private var demo: DemoStore
    @EnvironmentObject private var link: BandLink
    @Environment(\.colorScheme) private var scheme

    private func duration(_ seconds: Int) -> String {
        demo.t("duration.hm", demo.number(seconds / 3600), demo.number(seconds % 3600 / 60))
    }

    var body: some View {
        let p = Palette(scheme)
        let stages = [
            SleepStageRow(kind: SapHealth.stageAwake, key: "sleep.awake", color: p.pink),
            SleepStageRow(kind: SapHealth.stageREM, key: "sleep.rem", color: p.accent),
            SleepStageRow(kind: SapHealth.stageLight, key: "sleep.light", color: p.purple.opacity(0.55)),
            SleepStageRow(kind: SapHealth.stageDeep, key: "sleep.deep", color: p.purple),
        ]
        Card {
            Label(demo.t("vital.sleep"), systemImage: "moon.fill").font(.subheadline.weight(.medium)).foregroundStyle(p.purple)
            if let sleep = link.sleepSummary() {
                HStack(alignment: .firstTextBaseline) {
                    Text(duration(sleep.asleepSeconds)).font(.system(size: 34, weight: .semibold, design: .rounded))
                    Spacer()
                    if let score = sleep.score {
                        Text(demo.t("sleep.real.score", demo.number(score))).font(.subheadline).foregroundStyle(p.muted)
                    }
                }
                Text(demo.stamp(sleep.start) + " – " + demo.stamp(sleep.end)).font(.caption).foregroundStyle(p.muted)
                let total = max(1, sleep.stageSeconds.values.reduce(0, +))
                if !sleep.stageSeconds.isEmpty {
                    GeometryReader { area in
                        HStack(spacing: 2) {
                            ForEach(stages) { stage in
                                let share = CGFloat(sleep.stageSeconds[stage.kind] ?? 0) / CGFloat(total)
                                if share > 0 {
                                    RoundedRectangle(cornerRadius: 4).fill(stage.color)
                                        .frame(width: max(2, (area.size.width - 6) * share))
                                }
                            }
                        }
                    }.frame(height: 14)
                    ForEach(stages) { stage in
                        HStack {
                            Circle().fill(stage.color).frame(width: 8, height: 8)
                            Text(demo.t(stage.key)).font(.caption)
                            Spacer()
                            Text(duration(sleep.stageSeconds[stage.kind] ?? 0)).font(.caption).foregroundStyle(p.muted)
                        }
                    }
                } else {
                    Text(demo.t("sleep.real.periodOnly")).font(.caption).foregroundStyle(p.muted)
                }
            } else {
                Text(demo.t("sleep.real.empty")).font(.caption).foregroundStyle(p.muted)
            }
        }.accessibilityIdentifier("sleep.real")
    }
}

/// Full-screen, searchable list of the languages the band firmware offers.
struct BandLanguageList: View {
    @EnvironmentObject private var demo: DemoStore
    @EnvironmentObject private var link: BandLink
    @Environment(\.dismiss) private var dismiss
    let options: [BandLanguageOption]
    let selected: String
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List(options.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }) { item in
                Button {
                    link.setBandLanguage(item.code)
                    dismiss()
                } label: {
                    HStack {
                        Text(item.name).foregroundStyle(Color.primary)
                        Spacer()
                        if item.code == selected { Image(systemName: "checkmark") }
                    }.frame(minHeight: 44).contentShape(Rectangle())
                }
            }
            .searchable(text: $query)
            .navigationTitle(demo.t("live.language"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel(demo.t("common.close"))
                }
            }
        }
    }
}

struct LiveBandScreen: View {
    @EnvironmentObject private var demo: DemoStore
    @EnvironmentObject private var link: BandLink
    @Environment(\.colorScheme) private var scheme
    private var p: Palette { Palette(scheme) }
    @State private var showLanguages = false
    private var chosenBandLanguage: String {
        link.bandLanguage ?? SapTransport.bandLanguage(forAppLanguage: demo.language.rawValue)
    }

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
            if link.sapReady {
                Label(demo.t("live.sap.ready"), systemImage: "checkmark.seal")
                    .font(.caption).foregroundStyle(p.accent)
                    .accessibilityIdentifier("live.sap.ready")
                Divider()
                Toggle(demo.t("live.calls"), isOn: Binding(
                    get: { link.callAlerts },
                    set: {
                        link.incomingCallTitle = demo.t("live.calls.name")
                        link.setCallAlerts($0)
                    }))
                    .font(.subheadline)
                Text(demo.t("live.calls.note")).font(.caption).foregroundStyle(p.muted)
                secondary(demo.t("live.calls.test")) { link.testRing() }
                    .accessibilityIdentifier("live.calls.test")
                Divider()
                Text(demo.t("live.notify.title")).font(.subheadline)
                Text(demo.t("live.notify.note")).font(.caption).foregroundStyle(p.muted)
                secondary(demo.t("live.notify.test")) {
                    link.sendNotification(title: "FitLambda", text: demo.t("live.notify.sample"), kind: .other)
                }.accessibilityIdentifier("live.notify.test")
                Divider()
                if link.bandInitialized == false {
                    Label(demo.t("live.setup.new"), systemImage: "exclamationmark.circle")
                        .font(.caption).foregroundStyle(p.pink)
                }
                HStack(spacing: 12) {
                    Image(systemName: "hand.raised.fill")
                        .font(.title2).foregroundStyle(p.accent)
                        .scaleEffect(x: link.rightWrist ? -1 : 1, y: 1)
                        .accessibilityHidden(true)
                    Picker(demo.t("live.wrist"), selection: Binding(
                        get: { link.rightWrist },
                        set: { link.setRightWrist($0) })) {
                        Text(demo.t("live.wrist.left")).tag(false)
                        Text(demo.t("live.wrist.right")).tag(true)
                    }.pickerStyle(.segmented)
                }
                Text(demo.t("live.wrist")).font(.caption).foregroundStyle(p.muted)
                Button { showLanguages = true } label: {
                    HStack {
                        Text(demo.t("live.language")).font(.subheadline)
                        Spacer()
                        Text(bandLanguages.first { $0.code == chosenBandLanguage }?.name ?? chosenBandLanguage)
                            .font(.subheadline).foregroundStyle(p.accent)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(p.muted)
                    }.frame(minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .accessibilityIdentifier("live.language")
                    .sheet(isPresented: $showLanguages) {
                        BandLanguageList(options: bandLanguages, selected: chosenBandLanguage)
                            .environmentObject(demo).environmentObject(link)
                    }
                secondary(demo.t("live.setup")) { link.configureBand(languageCode: demo.language.rawValue) }
                    .accessibilityIdentifier("live.setup")
                Text(demo.t("live.setup.note")).font(.caption).foregroundStyle(p.muted)
                Divider()
                Toggle(demo.t("live.health"), isOn: Binding(
                    get: { link.healthEnabled },
                    set: { link.setHealthEnabled($0) }))
                    .font(.subheadline)
                Text(demo.t("live.health.note")).font(.caption).foregroundStyle(p.muted)
                Divider()
                Toggle(demo.t("live.music"), isOn: Binding(
                    get: { link.musicControl },
                    set: { link.setMusicControl($0) }))
                    .font(.subheadline)
                    .accessibilityIdentifier("live.music")
                Text(demo.t("live.music.note")).font(.caption).foregroundStyle(p.muted)
                if link.healthBatches > 0 {
                    Text(demo.t("live.health.batches", demo.number(link.healthBatches)))
                        .font(.caption).foregroundStyle(p.accent)
                }
            }
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

    /// Languages the band firmware offers, named in the app's language and sorted by name.
    private var bandLanguages: [BandLanguageOption] {
        let locale = demo.language.locale
        return SapTransport.localeIDs.keys
            .map { BandLanguageOption(code: $0, name: (locale.localizedString(forIdentifier: $0) ?? $0).capitalized(with: locale)) }
            .sorted { $0.name < $1.name }
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

struct BandLanguageOption: Identifiable {
    let code: String
    let name: String
    var id: String { code }
}

struct SleepStageRow: Identifiable {
    let kind: Int
    let key: String
    let color: Color
    var id: Int { kind }
}
