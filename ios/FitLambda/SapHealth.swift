import Foundation

// Ported from Fit3HealthCodec.kt in yuriyurin/Fit3-App (GPL-3.0). See NOTICE.md.

/// Health channel of the accessory protocol (service 10): the capability exchange the band
/// insists on before it sends activity data. The phone presents itself as the health host.
enum SapHealth {
    static let service: UInt8 = 10

    enum Command: Int {
        case checkStatus = 1, syncData = 2, requestData = 3, wearableMessage = 4
        case wearableCapability = 32, gmCapability = 34
    }

    struct Header {
        let variable: Bool
        let isRequest: Bool
        let id: Int
    }

    private static let hostHealthVersion: UInt32 = 7_006_011
    private static let minimumHealthVersion: UInt32 = 6_040_000

    static func header(_ payload: [UInt8]) -> Header? {
        guard let first = payload.first else { return nil }
        return Header(variable: first & 0x80 != 0, isRequest: first & 0x40 == 0, id: Int(first & 0x3F))
    }

    struct StepInterval: Codable, Equatable {
        /// Seconds since 1970 at the start of the interval.
        let start: Int
        let steps: Int
        let distanceMeters: Double
        let calories: Double
        let durationMillis: Int
    }

    /// Tells the band a data batch was stored: 42 02 E0 <sequence> 04 02 01 01.
    static func syncAcknowledgement(for payload: [UInt8]) -> [UInt8]? {
        guard payload.count >= 5, payload[2] == 0xE0 else { return nil }
        return [0x42, 0x02, 0xE0, payload[3], payload[4], 0x04, 0x02, 0x01, 0x01]
    }

    /// The band asks the phone for data; this host has none to give back.
    private static func requestDataEmptyResponse(for payload: [UInt8]) -> [UInt8]? {
        guard payload.count >= 4, payload[1] == 0xE0 else { return nil }
        return [0x43, 0xE0, payload[2], payload[3], 0x04, 0x02, 0x01, 0x01]
    }

    private static func int32(_ bytes: [UInt8], at offset: Int) -> UInt32 {
        UInt32(bytes[offset]) | UInt32(bytes[offset + 1]) << 8
            | UInt32(bytes[offset + 2]) << 16 | UInt32(bytes[offset + 3]) << 24
    }

    /// Step-count batch (data type 7): one record per interval, each a fixed run of fields.
    /// Times count seconds from 1990-01-01 UTC.
    static func stepIntervals(from payload: [UInt8]) -> [StepInterval]? {
        guard payload.count >= 8, payload[0] == 0x82, payload[2] == 0xE0, payload[5] == 7 else { return nil }
        let order: [UInt8] = [5, 1, 2, 3, 16, 17, 18, 19, 20, 21, 22, 23]
        var out: [StepInterval] = []
        var index = 6
        for _ in 0..<128 {
            guard index < payload.count else { break }
            let more = payload[index]
            index += 1
            guard more <= 1 else { return nil }
            var start: Int?
            var steps: Int?
            var distance = 0.0
            var calories = 0.0
            var duration = 0
            for field in order {
                guard index < payload.count, payload[index] == field else { return nil }
                index += 1
                let width = field == 23 ? 1 : 4
                guard index + width <= payload.count else { return nil }
                if width == 4 {
                    let raw = int32(payload, at: index)
                    switch field {
                    case 1: start = Int(raw) + 631_152_000
                    case 16: steps = raw <= 100_000 ? Int(raw) : nil
                    case 17: distance = Double(Float(bitPattern: raw))
                    case 19: calories = Double(Float(bitPattern: raw))
                    case 22: duration = Int(raw)
                    default: break
                    }
                }
                index += width
            }
            guard let begin = start, let count = steps,
                  distance.isFinite, (0...100_000).contains(distance),
                  calories.isFinite, (0...10_000).contains(calories),
                  (0...86_400_000).contains(duration) else { return nil }
            out.append(StepInterval(start: begin, steps: count, distanceMeters: distance,
                                    calories: calories, durationMillis: duration))
            if more == 0 { break }
        }
        return out.isEmpty ? nil : out
    }

    /// Reassembles large-data chunks (message 63): 3F <flag> <chunk number, 4 bytes> <bytes>.
    struct LargeData {
        private var bytes: [UInt8] = []
        private var next = 0

        static func isChunk(_ payload: [UInt8]) -> Bool {
            guard let first = payload.first else { return false }
            return first & 0x3F == 63
        }

        private static func acknowledgement(_ count: Int, accepted: Bool) -> [UInt8] {
            [0x3E, accepted ? 0x09 : 0x08, UInt8(count & 0xFF), UInt8((count >> 8) & 0xFF),
             UInt8((count >> 16) & 0xFF), UInt8((count >> 24) & 0xFF)]
        }

        /// Returns the complete message once the last chunk arrives, and the reply to send, if any.
        mutating func accept(_ payload: [UInt8]) -> (message: [UInt8]?, reply: [UInt8]?) {
            guard payload.count >= 6 else {
                bytes = []; next = 0
                return (nil, Self.acknowledgement(0, accepted: false))
            }
            let flag = Int(payload[1] & 0x03)
            let number = Int(SapHealth.int32(payload, at: 2))
            if flag == 0 && number == 0 { bytes = []; next = 0 }
            guard flag <= 2, (flag == 0) == (number == 0), number == next,
                  next < 256, bytes.count + payload.count - 6 <= 1_048_576 else {
                bytes = []; next = 0
                return (nil, Self.acknowledgement(number, accepted: false))
            }
            bytes += payload[6...]
            next += 1
            guard flag == 2 else { return (nil, nil) }
            let message = bytes
            let reply = Self.acknowledgement(next, accepted: true)
            bytes = []; next = 0
            return (message, reply)
        }
    }

    /// What to send back for a message from the band, or nil when no answer is defined here.
    /// Data batches (syncData) are acknowledged by the caller, after it has stored them.
    static func reply(to payload: [UInt8]) -> [UInt8]? {
        guard let head = header(payload), head.isRequest else { return nil }
        switch Command(rawValue: head.id) {
        case .gmCapability:
            guard let request = gmRequest(payload) else { return nil }
            return gmCapabilityResponse(sequence: request.sequence, version: request.version)
        case .wearableCapability:
            guard let sequence = capabilitySequence(payload) else { return nil }
            return wearableCapabilityResponse(sequence: sequence)
        case .checkStatus:
            return [0x41]
        case .wearableMessage:
            return [0x44]
        case .requestData:
            return requestDataEmptyResponse(for: payload)
        default:
            return nil
        }
    }

    // MARK: Heart-rate history and sleep
    // Record layouts from Fit3VitalCodec.kt and Fit3Sleep.kt in yuriyurin/Fit3-App (GPL-3.0).
    // Anything that does not match the known layout is rejected, never guessed.

    struct HeartSample: Codable, Equatable {
        let at: Int
        let bpm: Int
        let min: Int?
        let max: Int?
    }
    struct SleepEpisode: Codable, Equatable {
        let id: String
        let start: Int
        let end: Int
        let score: Int?
    }
    struct SleepStage: Codable, Hashable {
        let sleepID: String
        let start: Int
        let end: Int
        let kind: Int
    }
    static let stageAwake = 40001, stageLight = 40002, stageDeep = 40003, stageREM = 40004
    static let typeHeart = 10, typeSleep = 16, typeSleepStage = 17, typeStress = 19, typeOxygen = 112

    /// Field width for a record of the given type: 0 = unknown field, -1 = length-prefixed blob.
    private static func vitalWidth(type: Int, id: Int) -> Int {
        if [1, 2, 3, 5, 151, 153].contains(id) { return 4 }
        switch type {
        case typeHeart:
            if (32...35).contains(id) { return 1 }
            if id == 36 { return -1 }
            return id == 37 ? 2 : 0
        case typeSleep:
            if (28...37).contains(id) { return 2 }
            if id == 40 || id == 80 { return 4 }
            if [81, 83, 86].contains(id) { return 1 }
            return (id == 82 || id == 117) ? 16 : 0
        case typeStress:
            if [96, 102, 103].contains(id) { return 1 }
            if id == 97 { return 4 }
            return id == 98 ? -1 : 0
        case typeOxygen:
            if id == 117 { return 16 }
            if (169...172).contains(id) { return 1 }
            if id == 173 { return 2 }
            if id == 174 { return 4 }
            return id == 175 ? -1 : 0
        default: return 0
        }
    }

    private static func healthSeconds(_ bytes: [UInt8]) -> Int { Int(int32(bytes, at: 0)) + 631_152_000 }
    private static func hexText(_ bytes: [UInt8]) -> String { bytes.map { String(format: "%02x", $0) }.joined() }

    /// Length-prefixed records of one data batch, each as field id -> raw bytes.
    private static func vitalRecords(from payload: [UInt8], type: Int) -> [[Int: [UInt8]]]? {
        guard payload.count >= 12, payload[0] == 0x82, payload[2] == 0xE0, Int(payload[5]) == type else { return nil }
        var offset = 6
        var records: [[Int: [UInt8]]] = []
        for _ in 0..<128 {
            guard offset + 5 <= payload.count else { return nil }
            let more = payload[offset]
            guard more <= 1 else { return nil }
            let length = Int(int32(payload, at: offset + 1))
            offset += 5
            guard length > 0, length <= 65_536, offset + length <= payload.count else { return nil }
            let end = offset + length
            var fields: [Int: [UInt8]] = [:]
            while offset < end {
                let id = Int(payload[offset])
                offset += 1
                let width = vitalWidth(type: type, id: id)
                if width == 0 { return nil }
                if width < 0 {
                    guard offset + 4 <= end else { return nil }
                    let blob = Int(int32(payload, at: offset))
                    offset += 4
                    guard blob >= 0, blob <= 65_536, offset + blob <= end else { return nil }
                    offset += blob
                } else {
                    guard offset + width <= end else { return nil }
                    fields[id] = Array(payload[offset..<(offset + width)])
                    offset += width
                }
            }
            records.append(fields)
            if more == 0 { return records }
        }
        return nil
    }

    static func heartSamples(from payload: [UInt8]) -> [HeartSample]? {
        guard let records = vitalRecords(from: payload, type: typeHeart) else { return nil }
        return records.compactMap { fields in
            guard let time = fields[2] ?? fields[1], let bpm = fields[32]?.first, bpm > 0 else { return nil }
            return HeartSample(at: healthSeconds(time), bpm: Int(bpm),
                               min: fields[33]?.first.map { Int($0) }, max: fields[34]?.first.map { Int($0) })
        }
    }

    /// Single-value readings (time -> value): stress 0-100 or blood oxygen in percent.
    static func readings(from payload: [UInt8], type: Int) -> [Int: Int]? {
        guard type == typeStress || type == typeOxygen,
              let records = vitalRecords(from: payload, type: type) else { return nil }
        var out: [Int: Int] = [:]
        for fields in records {
            guard let time = fields[2] ?? fields[1],
                  let value = fields[type == typeStress ? 96 : 169]?.first, value > 0, value <= 100 else { continue }
            out[healthSeconds(time)] = Int(value)
        }
        return out
    }

    static func sleepEpisodes(from payload: [UInt8]) -> [SleepEpisode]? {
        guard let records = vitalRecords(from: payload, type: typeSleep) else { return nil }
        return records.compactMap { fields in
            guard let first = fields[1], let last = fields[2] else { return nil }
            let start = healthSeconds(first), end = healthSeconds(last)
            guard end > start, end - start <= 36 * 3600 else { return nil }
            let score = fields[83]?.first.map { Int($0) }.flatMap { $0 <= 100 ? $0 : nil }
            return SleepEpisode(id: fields[117].map(hexText) ?? "\(start):\(end)", start: start, end: end, score: score)
        }
    }

    /// Sleep stages arrive as rows of exactly eight fixed-width fields, without a length prefix.
    static func sleepStages(from payload: [UInt8]) -> [SleepStage]? {
        guard payload.count >= 6, payload[0] == 0x82, payload[2] == 0xE0, Int(payload[5]) == typeSleepStage else { return nil }
        var offset = 6
        var stages: [SleepStage] = []
        for _ in 0..<10_000 {
            guard offset < payload.count else { return nil }
            let more = payload[offset]
            offset += 1
            guard more <= 1 else { return nil }
            var fields: [Int: [UInt8]] = [:]
            for _ in 0..<8 {
                guard offset < payload.count else { return nil }
                let id = Int(payload[offset])
                offset += 1
                let width: Int
                if [1, 2, 3, 5, 82, 151, 153].contains(id) { width = 4 } else if id == 85 { width = 16 } else { return nil }
                guard fields[id] == nil, offset + width <= payload.count else { return nil }
                fields[id] = Array(payload[offset..<(offset + width)])
                offset += width
            }
            guard let first = fields[1], let last = fields[2], let kind = fields[82], let owner = fields[85] else { return nil }
            let start = healthSeconds(first), end = healthSeconds(last)
            if end > start, end - start <= 36 * 3600 {
                stages.append(SleepStage(sleepID: hexText(owner), start: start, end: end, kind: Int(int32(kind, at: 0))))
            }
            if more == 0 { return stages }
        }
        return nil
    }

    static func isDataBatch(_ payload: [UInt8]) -> Bool {
        guard let head = header(payload) else { return false }
        return head.isRequest && head.id == Command.syncData.rawValue
    }

    private static func short(_ bytes: [UInt8], at offset: Int) -> Int? {
        guard offset >= 0, offset + 2 <= bytes.count else { return nil }
        return Int(bytes[offset]) | Int(bytes[offset + 1]) << 8
    }

    /// Request layout seen on firmware AZA3: A2 02 E0 <sequence> E1 <protocol version>.
    private static func gmRequest(_ payload: [UInt8]) -> (sequence: Int, version: Int)? {
        guard let head = header(payload), head.variable, payload.count >= 2 else { return nil }
        var index = 2
        var sequence: Int?
        var version: Int?
        var remaining = Int(payload[1])
        while remaining > 0, index < payload.count {
            remaining -= 1
            let id = payload[index]
            index += 1
            switch id {
            case 0xE0:
                sequence = short(payload, at: index)
                index += 2
            case 0xE1:
                version = short(payload, at: index)
                index += 2
            case 0xD0, 0xD1:
                index += 1
            case 0xD2, 0xD3:
                index += 4
            default:
                remaining = 0 // An unknown field cannot be sized safely.
            }
        }
        guard let sequence, let version else { return nil }
        return (sequence, version)
    }

    private static func capabilitySequence(_ payload: [UInt8]) -> Int? {
        guard payload.count >= 5, payload[2] == 0xE0 else { return nil }
        return short(payload, at: 3)
    }

    private static func le16(_ value: Int) -> [UInt8] {
        [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF)]
    }

    private static func le32(_ value: UInt32) -> [UInt8] {
        [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF), UInt8((value >> 16) & 0xFF), UInt8((value >> 24) & 0xFF)]
    }

    private static func text(_ id: UInt8, _ value: String) -> [UInt8] {
        let bytes = Array(value.utf8.prefix(255))
        return [id, UInt8(bytes.count)] + bytes
    }

    static func gmCapabilityResponse(sequence: Int, version: Int) -> [UInt8] {
        var out: [UInt8] = [0xE2, 0x06]
        out += [0xD0, 0x02]
        out += [0xD1, 0x00]
        out += [0xD2] + le32(hostHealthVersion)
        out += [0xD3] + le32(minimumHealthVersion)
        out += [0xE0] + le16(sequence)
        out += [0xE1] + le16(version)
        return out
    }

    static func wearableCapabilityResponse(sequence: Int) -> [UInt8] {
        let binning = #"{"pedometer":4}"#
        let protocolFeature = #"{"wearable_messaging":true,"compression":true,"wm_chunk_size":10000,"sync_duration":30,"blob_compression":true}"#
        let syncAddress = #"{"common_sync":"com.samsung.android.app.shealth.wearable.syncmanager"}"#
        let trackerFeature = #"{"pedometer_sync":{"support_wearable_all_step":true},"goal_support":{"pedometer":1,"floor":1,"water":0},"daily_activity":{"support":false},"dashboard_config_sync":{"version":1000,"is_support":true}}"#
        let config = #"{"os":"android","os_version":"16","country_iso":"","one_ui_version":-1}"#
        let wearableMessage = #"{"message_version":5.18,"message_support":true,"message_compression":true,"message_compression_format":"gzip","message_size":10000}"#
        let launchSupport = #"{"support":false,"target_list":"settings.band.manage_exercises"}"#

        var out: [UInt8] = [0xE0, 13]
        out += [0xE0] + le16(sequence)
        out += [0xA1, 0x04, 0x51]
        out += [0xA2] + le32(hostHealthVersion)
        out += text(0xC0, "com.samsung.android.app.shealth.RESPONSE_CAPABILITY")
        out += text(0xC1, "shealth")
        out += text(0xC2, "wearable")
        out += text(0xAE, binning)
        out += text(0xAF, protocolFeature)
        out += text(0xB1, syncAddress)
        out += text(0xB3, trackerFeature)
        out += text(0xAC, config)
        out += text(0xC3, wearableMessage)
        out += text(0xAD, launchSupport)
        return out
    }

    /// A request in the layout the band uses must produce exactly the expected reply.
    static let selfCheckPasses: Bool = {
        let request: [UInt8] = [0xA2, 0x02, 0xE0, 0x34, 0x12, 0xE1, 0x2D, 0x01]
        let expected: [UInt8] = [0xE2, 0x06, 0xD0, 0x02, 0xD1, 0x00,
                                 0xD2, 0x3B, 0xE7, 0x6A, 0x00, 0xD3, 0xC0, 0x29, 0x5C, 0x00,
                                 0xE0, 0x34, 0x12, 0xE1, 0x2D, 0x01]
        guard let answer = SapHealth.reply(to: request), answer == expected else { return false }
        guard SapHealth.reply(to: [0x04, 0xE0, 0x01, 0x00]) == [0x44] else { return false }
        // One step record exactly as a real band sent it: 15 steps over 10 s.
        let batch: [UInt8] = [0x82, 0x03, 0xE0, 0x3D, 0x27, 0x07, 0x00,
                              0x05, 0x44, 0xBA, 0x61, 0x45, 0x01, 0x08, 0xBA, 0x61, 0x45,
                              0x02, 0x44, 0xBA, 0x61, 0x45, 0x03, 0x80, 0x34, 0x5B, 0xFF,
                              0x10, 0x0F, 0x00, 0x00, 0x00, 0x11, 0x74, 0xDF, 0x33, 0x41,
                              0x12, 0x8E, 0xAD, 0x2C, 0x3F, 0x13, 0xF3, 0xB0, 0xFF, 0x3E,
                              0x14, 0x00, 0x00, 0x00, 0x00, 0x15, 0x0F, 0x00, 0x00, 0x00,
                              0x16, 0x10, 0x27, 0x00, 0x00, 0x17, 0x03]
        guard let records = SapHealth.stepIntervals(from: batch), records.count == 1,
              records[0].steps == 15, records[0].durationMillis == 10_000,
              records[0].start == 0x4561_BA08 + 631_152_000 else { return false }
        guard SapHealth.syncAcknowledgement(for: batch) == [0x42, 0x02, 0xE0, 0x3D, 0x27, 0x04, 0x02, 0x01, 0x01] else { return false }
        var large = LargeData()
        guard large.accept([0x3F, 0x08, 0, 0, 0, 0, 0xAA]).message == nil else { return false }
        let done = large.accept([0x3F, 0x0A, 1, 0, 0, 0, 0xBB])
        return done.message == [0xAA, 0xBB] && done.reply == [0x3E, 0x09, 2, 0, 0, 0]
    }()
}
