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

    /// What to send back for a message from the band, or nil when no answer is defined here.
    /// Data batches (syncData) are deliberately left unanswered for now, so the band keeps them.
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
        default:
            return nil
        }
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
        return SapHealth.reply(to: [0x04, 0xE0, 0x01, 0x00]) == [0x44]
    }()
}
