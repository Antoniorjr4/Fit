import Foundation
import CoreBluetooth
import Combine

/// Real Bluetooth LE link to the band. Nothing in this file is simulated.
///
/// Scope, on purpose: discovery, connection, GATT enumeration, the standard
/// Heart Rate / Battery / Device Information services, signal strength,
/// reconnection and an exportable event log. Proprietary characteristics are
/// only listened to (opt-in). The single exception is the opt-in Samsung accessory
/// session, which answers the band's greeting and asks for the battery level.
enum BandPhase: Equatable {
    case idle, poweredOff, unauthorized, unsupported
    case scanning, connecting, discovering, connected, reconnecting, failed
}

struct FoundBand: Identifiable, Equatable {
    let id: UUID
    var name: String
    var rssi: Int?
    var isLikelyFit: Bool
    var alreadyLinked: Bool
}

struct HeartReading: Equatable {
    let bpm: Int
    let at: Date
}

struct BandLogLine: Identifiable {
    let id: Int
    let at: Date
    let text: String
}

struct BandCharacteristicInfo: Identifiable {
    let id: String
    let properties: String
}

struct BandServiceInfo: Identifiable {
    let id: String
    var characteristics: [BandCharacteristicInfo]
}

enum BandInfoField: String, CaseIterable {
    case manufacturer, model, firmware, hardware, software
}

final class BandLink: NSObject, ObservableObject {
    @Published private(set) var phase: BandPhase = .idle
    @Published private(set) var found: [FoundBand] = []
    @Published private(set) var scanEnded = false
    @Published private(set) var deviceName: String?
    @Published private(set) var rssi: Int?
    @Published private(set) var battery: Int?
    @Published private(set) var heart: HeartReading?
    @Published private(set) var sessionHeartCount = 0
    @Published private(set) var info: [BandInfoField: String] = [:]
    @Published private(set) var services: [BandServiceInfo] = []
    @Published private(set) var log: [BandLogLine] = []
    @Published private(set) var proprietaryFrames = 0
    @Published private(set) var lastSeen: Date?
    @Published private(set) var hasRememberedBand = false
    @Published private(set) var listenProprietary = false
    /// The Samsung accessory channel (service 1A1A) is opt-in on its own: the band
    /// greets a listener there and drops the link when nobody answers.
    @Published private(set) var listenSAP = false
    @Published private(set) var listenAutoDisabled = false
    /// The band accepted the session greeting; requests can be sent on the accessory channel.
    @Published private(set) var sapReady = false
    /// Make the band ring while the phone is ringing (needs the accessory session).
    @Published private(set) var callAlerts = false
    /// iOS holds a stale bond for this band; only the user can clear it in Settings.
    @Published private(set) var needsForgetInSettings = false

    private enum Keys {
        static let device = "fitlambda.band.identifier"
        static let name = "fitlambda.band.name"
        static let heartBPM = "fitlambda.band.heart.bpm"
        static let heartAt = "fitlambda.band.heart.at"
        static let listen = "fitlambda.band.listen-proprietary"
        static let listenSAP = "fitlambda.band.listen-sap"
        static let sapMTU = "fitlambda.band.sap-mtu"
        static let callAlerts = "fitlambda.band.call-alerts"
    }

    private static let heartService = CBUUID(string: "180D")
    private static let batteryService = CBUUID(string: "180F")
    private static let deviceInfoService = CBUUID(string: "180A")
    private static let samsungLinkService = CBUUID(string: "1A1A")
    private static let heartMeasurement = CBUUID(string: "2A37")
    private static let sapNotify = CBUUID(string: "797AE4E9-2E58-4FE8-B48D-B5C79599FB9B")
    private static let sapWrite = CBUUID(string: "63E30BAD-4206-4596-839F-E47CBF7A4B5D")
    private static let batteryLevel = CBUUID(string: "2A19")
    private static let infoFields: [CBUUID: BandInfoField] = [
        CBUUID(string: "2A29"): .manufacturer,
        CBUUID(string: "2A24"): .model,
        CBUUID(string: "2A26"): .firmware,
        CBUUID(string: "2A27"): .hardware,
        CBUUID(string: "2A28"): .software
    ]
    /// Services with a Bluetooth SIG meaning. Everything else is treated as proprietary.
    private static let standardServices: Set<CBUUID> = [
        CBUUID(string: "1800"), CBUUID(string: "1801"),
        deviceInfoService, heartService, batteryService
    ]
    private static let restoreIdentifier = "com.annalabs.fitlambda.central"
    private static let maxLogLines = 400

    private let defaults = UserDefaults.standard
    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var candidates: [UUID: CBPeripheral] = [:]
    private var wantsScan = false
    private var userDisconnected = false
    private var pendingServices = 0
    private var logCounter = 0
    private var proprietarySubscribedAt: Date?
    private var quickDrops = 0
    private var scanTimer: Timer?
    private var connectTimer: Timer?
    private var rssiTimer: Timer?
    private var sapWriteCharacteristic: CBCharacteristic?
    private var sapMTU: Int?
    private var sapPending: [UInt8] = []
    private var sapPendingService: UInt8?
    private var sapResumeTimer: Timer?
    private var sapBatteryTimer: Timer?
    private var callMonitor: CallMonitor?
    private var bandRinging = false
    private var testRingTimer: Timer?
    /// Text the band shows for a call; iOS does not reveal the caller.
    var incomingCallTitle = "Incoming call"

    override init() {
        super.init()
        listenProprietary = defaults.bool(forKey: Keys.listen)
        listenSAP = defaults.bool(forKey: Keys.listenSAP)
        callAlerts = defaults.bool(forKey: Keys.callAlerts)
        if callAlerts { startCallMonitor() }
        let bpm = defaults.integer(forKey: Keys.heartBPM)
        let at = defaults.double(forKey: Keys.heartAt)
        if bpm > 0, at > 0 { heart = HeartReading(bpm: bpm, at: Date(timeIntervalSince1970: at)) }
        if rememberedID != nil {
            hasRememberedBand = true
            deviceName = defaults.string(forKey: Keys.name)
            // Bluetooth access was already granted when this band was chosen,
            // so resuming here does not surprise the user with a system prompt.
            ensureCentral()
        }
    }

    // MARK: Intentions sent by the interface

    func startScan() {
        wantsScan = true
        scanEnded = false
        userDisconnected = false
        needsForgetInSettings = false
        ensureCentral()
        guard let central else { return }
        switch central.state {
        case .poweredOn: beginScan()
        case .poweredOff: phase = .poweredOff
        case .unauthorized: phase = .unauthorized
        case .unsupported: phase = .unsupported
        default: phase = .scanning // The radio state arrives in centralManagerDidUpdateState.
        }
    }

    func stopScan() {
        finishScan()
    }

    func connect(_ id: UUID) {
        guard let central, central.state == .poweredOn, let target = candidates[id] else { return }
        scanTimer?.invalidate()
        central.stopScan()
        wantsScan = false
        userDisconnected = false
        attach(target)
        deviceName = found.first(where: { $0.id == id })?.name ?? target.name
        phase = .connecting
        note("Connecting to \(deviceName ?? "band")")
        central.connect(target, options: nil)
        connectTimer?.invalidate()
        connectTimer = Timer.scheduledTimer(withTimeInterval: 25, repeats: false) { [weak self] _ in
            guard let self, self.phase == .connecting, let pending = self.peripheral else { return }
            self.userDisconnected = true
            self.central?.cancelPeripheralConnection(pending)
            self.note("Connection attempt timed out after 25 s")
            self.phase = .failed
        }
    }

    /// Ends the current session but keeps the band remembered.
    func disconnect() {
        userDisconnected = true
        stopTimers()
        if let peripheral { central?.cancelPeripheralConnection(peripheral) }
        rssi = nil
        phase = .idle
        note("Disconnected by the user")
    }

    func reconnect() {
        userDisconnected = false
        ensureCentral()
        guard let central, central.state == .poweredOn else { return }
        resumeRememberedBand(on: central)
    }

    func forget() {
        disconnect()
        peripheral = nil
        for key in [Keys.device, Keys.name, Keys.heartBPM, Keys.heartAt] { defaults.removeObject(forKey: key) }
        hasRememberedBand = false
        deviceName = nil
        battery = nil
        heart = nil
        sessionHeartCount = 0
        info = [:]
        services = []
        proprietaryFrames = 0
        lastSeen = nil
        needsForgetInSettings = false
        defaults.removeObject(forKey: Keys.sapMTU)
        sapMTU = nil
        note("Band forgotten on this iPhone")
    }

    func setListenProprietary(_ enabled: Bool) {
        listenProprietary = enabled
        defaults.set(enabled, forKey: Keys.listen)
        listenAutoDisabled = false
        quickDrops = 0
        applyListening(sap: false, enabled: enabled)
        note(enabled ? "Listening to proprietary channels (read-only)" : "Stopped listening to proprietary channels")
    }

    func setListenSAP(_ enabled: Bool) {
        listenSAP = enabled
        defaults.set(enabled, forKey: Keys.listenSAP)
        listenAutoDisabled = false
        quickDrops = 0
        if !enabled { endSAPSession() }
        applyListening(sap: true, enabled: enabled)
        note(enabled ? "Listening to the Samsung accessory channel (read-only)" : "Stopped listening to the Samsung accessory channel")
    }

    private func wantsListening(to service: CBUUID) -> Bool {
        service == Self.samsungLinkService ? listenSAP : listenProprietary
    }

    private func applyListening(sap: Bool, enabled: Bool) {
        guard let peripheral, peripheral.state == .connected else { return }
        for service in peripheral.services ?? [] where !Self.standardServices.contains(service.uuid) {
            guard (service.uuid == Self.samsungLinkService) == sap else { continue }
            for characteristic in service.characteristics ?? [] {
                if Self.canNotify(characteristic) {
                    peripheral.setNotifyValue(enabled, for: characteristic)
                } else if enabled, characteristic.properties.contains(.read) {
                    peripheral.readValue(for: characteristic)
                }
            }
        }
    }

    /// Plain-text report for sharing. Contains no keys, accounts or location.
    func exportText() -> String {
        let stamp = ISO8601DateFormatter()
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        var lines = ["FitLambda \(version) - Bluetooth report", "Generated: \(stamp.string(from: Date()))"]
        lines.append("Band: \(deviceName ?? "none")")
        for field in BandInfoField.allCases {
            if let value = info[field] { lines.append("\(field.rawValue): \(value)") }
        }
        if let battery { lines.append("battery: \(battery)%") }
        if let rssi { lines.append("rssi: \(rssi) dBm") }
        if let heart { lines.append("last heart rate: \(heart.bpm) bpm at \(stamp.string(from: heart.at))") }
        lines.append("")
        lines.append("GATT")
        for service in services {
            lines.append("SERVICE \(service.id)")
            for characteristic in service.characteristics {
                lines.append("  CHAR \(characteristic.id) [\(characteristic.properties)]")
            }
        }
        lines.append("")
        lines.append("EVENTS")
        for line in log { lines.append("\(stamp.string(from: line.at))  \(line.text)") }
        return lines.joined(separator: "\n")
    }

    // MARK: Internals

    private var rememberedID: UUID? {
        defaults.string(forKey: Keys.device).flatMap(UUID.init(uuidString:))
    }

    private func ensureCentral() {
        guard central == nil else { return }
        central = CBCentralManager(delegate: self, queue: nil,
                                   options: [CBCentralManagerOptionRestoreIdentifierKey: Self.restoreIdentifier])
    }

    private func attach(_ target: CBPeripheral) {
        peripheral = target
        target.delegate = self
    }

    private func beginScan() {
        guard let central else { return }
        scanTimer?.invalidate()
        found = []
        candidates = [:]
        scanEnded = false
        phase = .scanning
        note("Scan started")
        // A band already linked to this iPhone may not advertise, so ask iOS for it as well.
        let linked = central.retrieveConnectedPeripherals(
            withServices: [Self.heartService, Self.samsungLinkService, Self.deviceInfoService])
        for item in linked { register(item, rssi: nil, linked: true, advertisedName: nil) }
        central.scanForPeripherals(withServices: nil, options: nil)
        scanTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
            self?.finishScan()
        }
    }

    private func finishScan() {
        scanTimer?.invalidate()
        wantsScan = false
        if let central, central.state == .poweredOn { central.stopScan() }
        guard phase == .scanning else { return }
        scanEnded = true
        phase = .idle
        note("Scan finished: \(found.count) named device(s)")
    }

    private func register(_ item: CBPeripheral, rssi: Int?, linked: Bool, advertisedName: String?) {
        let name = (advertisedName ?? item.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        candidates[item.identifier] = item
        let lowered = name.lowercased()
        let likely = lowered.contains("fit3") || lowered.contains("fit 3") || lowered.contains("galaxy fit")
        if let index = found.firstIndex(where: { $0.id == item.identifier }) {
            found[index].name = name
            if let rssi { found[index].rssi = rssi }
            found[index].alreadyLinked = found[index].alreadyLinked || linked
        } else {
            found.append(FoundBand(id: item.identifier, name: name, rssi: rssi,
                                   isLikelyFit: likely, alreadyLinked: linked))
            if likely { note("Found \(name)") }
        }
        found.sort { first, second in
            if first.isLikelyFit != second.isLikelyFit { return first.isLikelyFit }
            return (first.rssi ?? -200) > (second.rssi ?? -200)
        }
    }

    private func resumeRememberedBand(on central: CBCentralManager) {
        if let current = peripheral, current.state == .connected {
            phase = .discovering
            current.discoverServices(nil)
            return
        }
        guard let id = rememberedID else { return }
        guard let known = peripheral ?? central.retrievePeripherals(withIdentifiers: [id]).first else {
            note("iOS no longer knows the remembered band; search again")
            phase = .idle
            return
        }
        attach(known)
        phase = .reconnecting
        // A pending connection has no timeout: iOS completes it when the band is back in range.
        central.connect(known, options: nil)
        note("Waiting for \(deviceName ?? "the band") to come back in range")
    }

    private func stopTimers() {
        scanTimer?.invalidate()
        connectTimer?.invalidate()
        rssiTimer?.invalidate()
        sapResumeTimer?.invalidate()
        sapBatteryTimer?.invalidate()
    }

    // MARK: Samsung accessory session (the only place this client writes to the band)

    func setCallAlerts(_ enabled: Bool) {
        callAlerts = enabled
        defaults.set(enabled, forKey: Keys.callAlerts)
        if enabled {
            startCallMonitor()
        } else {
            callMonitor = nil
            stopBandRinging()
        }
        note(enabled ? "Call alerts on the band enabled" : "Call alerts on the band disabled")
    }

    /// Rings the band for a few seconds so the feature can be checked without a real call.
    func testRing() {
        startBandRinging(title: "FitLambda")
        testRingTimer?.invalidate()
        testRingTimer = Timer.scheduledTimer(withTimeInterval: 6, repeats: false) { [weak self] _ in
            self?.stopBandRinging()
        }
    }

    private func startCallMonitor() {
        guard callMonitor == nil else { return }
        let monitor = CallMonitor()
        monitor.onEvent = { [weak self] event in
            guard let self, self.callAlerts else { return }
            switch event {
            case .ringing:
                self.note("Phone is ringing")
                self.startBandRinging(title: self.incomingCallTitle)
            case .answered:
                self.note("Call answered on the phone")
                if self.bandRinging {
                    self.sendSAP(service: SapTransport.callService, payload: SapTransport.callAnswered, label: "call answered")
                }
            case .ended:
                self.note("Call ended")
                self.stopBandRinging()
            }
        }
        callMonitor = monitor
    }

    private func startBandRinging(title: String) {
        guard sapReady else {
            note("Cannot ring the band: the Samsung session is not active")
            return
        }
        bandRinging = true
        sendSAP(service: SapTransport.callService, payload: SapTransport.callEnable, label: "call enable")
        sendSAP(service: SapTransport.callService,
                payload: SapTransport.callContact(name: title, number: "", at: Date()), label: "call contact")
        sendSAP(service: SapTransport.callService, payload: SapTransport.callRinging, label: "call ringing")
    }

    private func stopBandRinging() {
        testRingTimer?.invalidate()
        guard bandRinging else { return }
        bandRinging = false
        sendSAP(service: SapTransport.callService, payload: SapTransport.callIdle, label: "call idle")
    }

    private func endSAPSession() {
        sapReady = false
        bandRinging = false
        testRingTimer?.invalidate()
        sapPending = []
        sapPendingService = nil
        sapResumeTimer?.invalidate()
        sapBatteryTimer?.invalidate()
    }

    private func handleSAP(_ bytes: [UInt8], from peripheral: CBPeripheral) {
        if SapTransport.isHello(bytes) {
            guard SapTransport.selfCheckPasses else {
                note("SAP self-check failed; nothing was sent to the band")
                return
            }
            guard let target = sapWriteCharacteristic else {
                note("SAP greeting received but the write channel was not found")
                return
            }
            let mtu = SapTransport.helloMTU(bytes)
            sapMTU = mtu
            defaults.set(mtu, forKey: Keys.sapMTU)
            let kind: CBCharacteristicWriteType = target.properties.contains(.write) ? .withResponse : .withoutResponse
            peripheral.writeValue(Data(SapTransport.helloReply(bytes)), for: target, type: kind)
            note("SAP greeting answered (transport MTU \(mtu))")
            startSAPSession()
            return
        }
        guard let mtu = sapMTU, let fragment = SapTransport.parse(bytes, mtu: mtu) else {
            note("SAP frame not understood (length or checksum)")
            return
        }
        switch fragment.kind {
        case 0:
            if let service = fragment.service { deliverSAP(service: service, payload: fragment.payload) }
        case 1:
            sapPendingService = fragment.service
            sapPending = fragment.payload
        case 2:
            if sapPending.count + fragment.payload.count <= 4096 { sapPending += fragment.payload }
        default:
            if let service = sapPendingService {
                deliverSAP(service: service, payload: sapPending + fragment.payload)
            }
            sapPending = []
            sapPendingService = nil
        }
    }

    private func startSAPSession() {
        sapResumeTimer?.invalidate()
        sapReady = true
        // The band is being answered now, so the hang-up guard no longer applies.
        proprietarySubscribedAt = nil
        quickDrops = 0
        sendSAP(service: SapTransport.setupService, payload: SapTransport.watchInfoRequest, label: "watch info")
        requestBattery()
        // Read-only questions about the watch faces already on the band. The answers are
        // only logged for now; the face picker will be built from what a real band reports.
        sendSAP(service: SapTransport.faceService, payload: SapTransport.faceCurrentRequest, label: "current face")
        sendSAP(service: SapTransport.faceService, payload: SapTransport.faceInstalledRequest, label: "installed faces")
        sendSAP(service: SapTransport.faceService, payload: SapTransport.faceAllInfoRequest, label: "face summary")
        sapBatteryTimer?.invalidate()
        sapBatteryTimer = Timer.scheduledTimer(withTimeInterval: 180, repeats: true) { [weak self] _ in
            self?.requestBattery()
        }
    }

    func requestBattery() {
        sendSAP(service: SapTransport.settingsService, payload: SapTransport.batteryRequest, label: "battery")
    }

    private func sendSAP(service: UInt8, payload: [UInt8], label: String) {
        guard sapReady, SapTransport.selfCheckPasses, let mtu = sapMTU,
              let target = sapWriteCharacteristic,
              let peripheral, peripheral.state == .connected else { return }
        let frame = SapTransport.frame(service: service, payload: payload, mtu: mtu)
        let kind: CBCharacteristicWriteType = target.properties.contains(.write) ? .withResponse : .withoutResponse
        peripheral.writeValue(Data(frame), for: target, type: kind)
        note("SAP TX \(label) (service \(service)) \(Self.hex(Data(frame)))")
    }

    private func deliverSAP(service: UInt8, payload: [UInt8]) {
        note("SAP RX service \(service) [\(payload.count)] \(Self.hex(Data(payload), limit: 2048))")
        if service == SapTransport.settingsService,
           let level = SapTransport.batteryLevel(fromSettingsReply: payload) {
            if battery != level { note("Battery from the band: \(level)%") }
            battery = level
        }
        // The wearer pressed silence (1) or reject (5) on the band: stop its ringing.
        // iOS does not let an app reject the call itself.
        if service == SapTransport.callService, bandRinging, let header = payload.first,
           header & 0x40 == 0, [1, 5].contains(Int(header & 0x3F)) {
            note("Ringing dismissed on the band")
            stopBandRinging()
        }
    }

    private func note(_ text: String) {
        logCounter += 1
        log.append(BandLogLine(id: logCounter, at: Date(), text: text))
        if log.count > Self.maxLogLines { log.removeFirst(log.count - Self.maxLogLines) }
    }

    private static func canNotify(_ characteristic: CBCharacteristic) -> Bool {
        characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate)
    }

    private static func describe(_ properties: CBCharacteristicProperties) -> String {
        var names: [String] = []
        if properties.contains(.read) { names.append("read") }
        if properties.contains(.write) { names.append("write") }
        if properties.contains(.writeWithoutResponse) { names.append("write-no-response") }
        if properties.contains(.notify) { names.append("notify") }
        if properties.contains(.indicate) { names.append("indicate") }
        return names.joined(separator: ", ")
    }

    private static func hex(_ data: Data, limit: Int = 512) -> String {
        let shown = data.prefix(limit).map { String(format: "%02X", $0) }.joined(separator: " ")
        return data.count > limit ? shown + " ..." : shown
    }

    /// Bluetooth SIG Heart Rate Measurement: flags byte, then 8- or 16-bit beats per minute.
    static func parseHeartRate(_ data: Data) -> Int? {
        let bytes = [UInt8](data)
        guard bytes.count >= 2 else { return nil }
        if bytes[0] & 0x01 == 0 { return Int(bytes[1]) }
        guard bytes.count >= 3 else { return nil }
        return Int(bytes[1]) | (Int(bytes[2]) << 8)
    }
}

extension BandLink: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            note("Bluetooth is on")
            if wantsScan {
                beginScan()
            } else if !userDisconnected, peripheral != nil || rememberedID != nil {
                resumeRememberedBand(on: central)
            } else if phase == .poweredOff || phase == .unauthorized || phase == .unsupported {
                phase = .idle
            }
        case .poweredOff:
            note("Bluetooth is off")
            stopTimers()
            endSAPSession()
            sapWriteCharacteristic = nil
            peripheral = nil
            rssi = nil
            phase = .poweredOff
        case .unauthorized:
            note("Bluetooth access is not allowed for FitLambda")
            phase = .unauthorized
        case .unsupported:
            note("This device has no Bluetooth LE radio")
            phase = .unsupported
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        guard let restored = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral],
              let first = restored.first else { return }
        attach(first)
        note("Session restored by iOS")
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let advertised = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let level = RSSI.intValue
        register(peripheral, rssi: level == 127 ? nil : level, linked: false, advertisedName: advertised)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectTimer?.invalidate()
        attach(peripheral)
        defaults.set(peripheral.identifier.uuidString, forKey: Keys.device)
        let name = deviceName ?? peripheral.name
        if let name {
            deviceName = name
            defaults.set(name, forKey: Keys.name)
        }
        hasRememberedBand = true
        lastSeen = Date()
        sessionHeartCount = 0
        phase = .discovering
        note("Connected; reading services")
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectTimer?.invalidate()
        note("Connection failed: \(error?.localizedDescription ?? "no reason given")")
        if let failure = error as? CBError, failure.code == .peerRemovedPairingInformation {
            needsForgetInSettings = true
            note("iOS keeps an old pairing for this band: forget it in Settings > Bluetooth, restart the iPhone and search again")
        }
        phase = .failed
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        rssiTimer?.invalidate()
        endSAPSession()
        sapWriteCharacteristic = nil
        rssi = nil
        lastSeen = Date()
        if userDisconnected {
            if phase != .failed { phase = .idle }
            return
        }
        note("Link lost: \(error?.localizedDescription ?? "band out of range")")
        // The band hangs up about ten seconds after a proprietary subscription it gets
        // no answer to. Two such drops in a row end the experiment instead of looping.
        if let since = proprietarySubscribedAt, Date().timeIntervalSince(since) < 20 {
            quickDrops += 1
        } else {
            quickDrops = 0
        }
        proprietarySubscribedAt = nil
        if quickDrops >= 2, listenProprietary || listenSAP {
            listenProprietary = false
            listenSAP = false
            defaults.set(false, forKey: Keys.listen)
            defaults.set(false, forKey: Keys.listenSAP)
            listenAutoDisabled = true
            quickDrops = 0
            note("The band dropped the link twice right after a proprietary subscription; listening was turned off")
        }
        guard central.state == .poweredOn else { return }
        phase = .reconnecting
        central.connect(peripheral, options: nil)
    }
}

extension BandLink: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            note("Service discovery failed: \(error.localizedDescription)")
            phase = .failed
            return
        }
        let list = peripheral.services ?? []
        services = list.map { BandServiceInfo(id: $0.uuid.uuidString, characteristics: []) }
        pendingServices = list.count
        note("\(list.count) service(s) found")
        if list.isEmpty { becomeConnected(peripheral) }
        for service in list { peripheral.discoverCharacteristics(nil, for: service) }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let list = service.characteristics ?? []
        if let index = services.firstIndex(where: { $0.id == service.uuid.uuidString }) {
            services[index].characteristics = list.map {
                BandCharacteristicInfo(id: $0.uuid.uuidString, properties: Self.describe($0.properties))
            }
        }
        let proprietary = !Self.standardServices.contains(service.uuid)
        if service.uuid == Self.samsungLinkService {
            sapWriteCharacteristic = list.first(where: { $0.uuid == Self.sapWrite })
        }
        for characteristic in list {
            if characteristic.uuid == Self.heartMeasurement, Self.canNotify(characteristic) {
                peripheral.setNotifyValue(true, for: characteristic)
            } else if characteristic.uuid == Self.batteryLevel {
                if characteristic.properties.contains(.read) { peripheral.readValue(for: characteristic) }
                if Self.canNotify(characteristic) { peripheral.setNotifyValue(true, for: characteristic) }
            } else if Self.infoFields[characteristic.uuid] != nil, characteristic.properties.contains(.read) {
                peripheral.readValue(for: characteristic)
            } else if proprietary, wantsListening(to: service.uuid) {
                if Self.canNotify(characteristic) {
                    peripheral.setNotifyValue(true, for: characteristic)
                } else if characteristic.properties.contains(.read) {
                    peripheral.readValue(for: characteristic)
                }
            }
        }
        pendingServices -= 1
        if pendingServices <= 0 { becomeConnected(peripheral) }
    }

    private func becomeConnected(_ peripheral: CBPeripheral) {
        guard phase == .discovering else { return }
        phase = .connected
        let total = services.reduce(0) { $0 + $1.characteristics.count }
        note("Ready: \(services.count) service(s), \(total) characteristic(s)")
        peripheral.readRSSI()
        rssiTimer?.invalidate()
        rssiTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self, let current = self.peripheral, current.state == .connected else { return }
            current.readRSSI()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            note("Read failed on \(characteristic.uuid.uuidString): \(error.localizedDescription)")
            return
        }
        guard let data = characteristic.value else { return }
        lastSeen = Date()
        if characteristic.uuid == Self.heartMeasurement {
            guard let bpm = Self.parseHeartRate(data) else { return }
            // Zero means the sensor has no reading yet; it is not a heart rate.
            guard bpm > 0 else {
                note("Heart rate channel active, no reading yet")
                return
            }
            let reading = HeartReading(bpm: bpm, at: Date())
            if sessionHeartCount == 0 { note("First heart rate received: \(bpm) bpm") }
            heart = reading
            sessionHeartCount += 1
            defaults.set(bpm, forKey: Keys.heartBPM)
            defaults.set(reading.at.timeIntervalSince1970, forKey: Keys.heartAt)
        } else if characteristic.uuid == Self.batteryLevel {
            guard let level = data.first, level <= 100 else { return }
            if battery != Int(level) { note("Battery: \(level)%") }
            battery = Int(level)
        } else if let field = Self.infoFields[characteristic.uuid] {
            let text = String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
            if !text.isEmpty {
                info[field] = text
                note("\(field.rawValue): \(text)")
            }
        } else {
            proprietaryFrames += 1
            if characteristic.uuid == Self.sapNotify, listenSAP {
                if SapTransport.isHello([UInt8](data)) {
                    note("RX \(characteristic.uuid.uuidString) [\(data.count)] \(Self.hex(data))")
                }
                handleSAP([UInt8](data), from: peripheral)
                return
            }
            note("RX \(characteristic.uuid.uuidString) [\(data.count)] \(Self.hex(data))")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            note("Subscribe failed on \(characteristic.uuid.uuidString): \(error.localizedDescription)")
        } else {
            note("\(characteristic.isNotifying ? "Subscribed to" : "Unsubscribed from") \(characteristic.uuid.uuidString)")
            if characteristic.isNotifying, let owner = characteristic.service,
               !Self.standardServices.contains(owner.uuid) {
                proprietarySubscribedAt = Date()
            }
            if characteristic.isNotifying, characteristic.uuid == Self.sapNotify, listenSAP, !sapReady {
                // A link restored by iOS is already subscribed and the band does not greet
                // again; continue with the transport size agreed last time.
                sapResumeTimer?.invalidate()
                sapResumeTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { [weak self] _ in
                    guard let self, !self.sapReady, self.listenSAP else { return }
                    let stored = self.defaults.integer(forKey: Keys.sapMTU)
                    guard stored > 0, self.sapWriteCharacteristic != nil else { return }
                    self.sapMTU = stored
                    self.note("No greeting after subscribing; resuming the session with MTU \(stored)")
                    self.startSAPSession()
                }
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            note("Write failed on \(characteristic.uuid.uuidString): \(error.localizedDescription)")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        guard error == nil else { return }
        rssi = RSSI.intValue
        lastSeen = Date()
    }

    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        note("The band changed its services; reading them again")
        peripheral.discoverServices(nil)
    }
}
