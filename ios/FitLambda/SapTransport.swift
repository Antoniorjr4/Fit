import Foundation

// Frame layout, fragmentation and setup messages follow Fit3SapCodec.kt and Fit3OobeCodec.kt
// in yuriyurin/Fit3-App and docs/PROTOCOL.md in GokulArumugam/Fit3Bridge (GPL-3.0). See NOTICE.md.

/// Samsung accessory transport framing used by the Galaxy Fit3 over BLE GATT (service 1A1A).
/// Written from the public protocol description of the frame layout; pure data
/// transformations with no Bluetooth access, so every byte sent to a band can be checked first.
enum SapTransport {
    struct Fragment {
        /// 0 single, 1 first, 2 continue, 3 last.
        let kind: Int
        let service: UInt8?
        let payload: [UInt8]
    }

    static let helloLength = 105
    static let settingsService: UInt8 = 11
    static let setupService: UInt8 = 1
    static let batteryRequest: [UInt8] = [0x02]
    static let callService: UInt8 = 3
    static let faceService: UInt8 = 6
    /// Read-only watch face questions: catalogue summary, installed list, current face.
    static let faceAllInfoRequest: [UInt8] = [0x00]
    static let faceInstalledRequest: [UInt8] = [0x01]
    static let faceCurrentRequest: [UInt8] = [0x02]
    static let callEnable: [UInt8] = [0x08, 0x01]
    static let callRinging: [UInt8] = [0x03, 0x01]
    static let callAnswered: [UInt8] = [0x03, 0x02]
    static let callIdle: [UInt8] = [0x03, 0x00]
    private static let callAgent = "com.samsung.android.providers.sacall.SACallHandlerService"

    /// Caller card shown by the band before it starts ringing (call message 2, seven parameters).
    static func callContact(name: String, number: String, at date: Date) -> [UInt8] {
        let agent = Array(callAgent.utf8)
        let nameBytes = clipped(name, to: 127)
        let numberBytes = clipped(number, to: 127)
        var millis = UInt64(max(0, date.timeIntervalSince1970 * 1000))
        var time: [UInt8] = []
        for _ in 0..<8 {
            time.append(UInt8(millis & 0xFF))
            millis >>= 8
        }
        var out: [UInt8] = [0x82, 0x07, 0x00, 0x01, 0x07, 0x01, 0x00, 0x00, 0x00]
        out += [0x05, UInt8(agent.count)] + agent
        out += [0x06] + time
        out += [0x04, UInt8(nameBytes.count)] + nameBytes
        out += [0x03, UInt8(numberBytes.count)] + numberBytes
        out += [0x09, 0x00]
        return out
    }

    /// UTF-8 bytes of a text cut at a character boundary so they fit a one-byte length.
    private static func clipped(_ text: String, to limit: Int) -> [UInt8] {
        var result: [UInt8] = []
        for character in text {
            let bytes = Array(String(character).utf8)
            if result.count + bytes.count > limit { break }
            result += bytes
        }
        return result
    }
    static let watchInfoRequest: [UInt8] = [0x01, 0x04, 0x02, 0x00, 0x00, 0x00, 0x05, 0x00, 0x0E]

    /// CRC-16/ARC: reflected polynomial 0xA001, initial value 0.
    static func crc16(_ bytes: [UInt8]) -> UInt16 {
        var crc: UInt16 = 0
        for byte in bytes {
            crc ^= UInt16(byte)
            for _ in 0..<8 {
                crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xA001 : crc >> 1
            }
        }
        return crc
    }

    /// The band opens a session with a 105-byte capability message: length 104, type 0x14.
    static func isHello(_ data: [UInt8]) -> Bool {
        data.count == helloLength && data[0] == 104 && data[1] == 0x14
    }

    /// The answer is the same message with the type changed to 0x15.
    static func helloReply(_ data: [UInt8]) -> [UInt8] {
        var reply = data
        reply[1] = 0x15
        return reply
    }

    static func helloMTU(_ data: [UInt8]) -> Int {
        Int(data[0x2C]) << 8 | Int(data[0x2D])
    }

    private static func envelope(_ body: [UInt8], mtu: Int) -> [UInt8] {
        var out: [UInt8]
        if mtu < 256 {
            out = [UInt8(body.count & 0xFF), UInt8(body.count & 0xFF)]
        } else {
            let length: [UInt8] = [UInt8((body.count >> 8) & 0xFF), UInt8(body.count & 0xFF)]
            let lengthCRC = crc16(length)
            out = length + [UInt8(lengthCRC >> 8), UInt8(lengthCRC & 0xFF)]
        }
        let bodyCRC = crc16(body)
        out += body
        out += [UInt8(bodyCRC >> 8), UInt8(bodyCRC & 0xFF)]
        return out
    }

    /// One unfragmented message for a service.
    static func frame(service: UInt8, payload: [UInt8], mtu: Int) -> [UInt8] {
        envelope([0x00, 0x40, service, service] + payload, mtu: mtu)
    }

    /// A message as one frame, or as first/continue/last fragments when it does not fit the
    /// transport size. Returns an empty list when it would need more than sixteen fragments.
    static func frames(service: UInt8, payload: [UInt8], mtu: Int) -> [[UInt8]] {
        let single = frame(service: service, payload: payload, mtu: mtu)
        if single.count <= mtu { return [single] }
        let overhead = (mtu < 256 ? 2 : 4) + 2
        let firstCapacity = mtu - overhead - 4
        let nextCapacity = mtu - overhead - 2
        guard firstCapacity > 0, nextCapacity > 0 else { return [] }
        var out: [[UInt8]] = []
        var offset = min(firstCapacity, payload.count)
        out.append(envelope([0x02, 0x00, service, service] + Array(payload[0..<offset]), mtu: mtu))
        var number = 1
        while offset < payload.count {
            guard number <= 15 else { return [] }
            let take = min(nextCapacity, payload.count - offset)
            let isLast = offset + take >= payload.count
            let body: [UInt8] = [isLast ? 0x06 : 0x04, UInt8(number)] + Array(payload[offset..<(offset + take)])
            out.append(envelope(body, mtu: mtu))
            offset += take
            number += 1
        }
        return out
    }

    // MARK: Setup service (first-run configuration, time and language)

    static let deviceStatusRequest: [UInt8] = [0x02, 0x01, 0x00]
    static let userAgreementRequest: [UInt8] = [0x84, 0x01, 0x01]

    /// Language ids the band firmware understands, keyed by the app's language codes.
    static let localeIDs: [String: Int] = ["pt-BR": 82, "en": 13, "es": 14, "fr": 20, "de": 11, "it": 30]

    /// Sets language, clock, time zone and 12/24-hour display in one message.
    static func initSettings(localeID: Int, at date: Date, offsetSeconds: Int, hour24: Bool) -> [UInt8] {
        let epoch = Array(String(Int(date.timeIntervalSince1970)).utf8)
        let magnitude = abs(offsetSeconds)
        var out: [UInt8] = [0x83]
        out += [0x01, UInt8(localeID & 0xFF), UInt8((localeID >> 8) & 0xFF)]
        out += [0x02, 0x00]
        out += [0x03, UInt8(epoch.count)] + epoch
        out += [0x04, offsetSeconds < 0 ? 1 : 0, UInt8(magnitude & 0xFF), UInt8((magnitude >> 8) & 0xFF)]
        out += [0x05, hour24 ? 1 : 0]
        return out
    }

    /// Watch info reply: parameter 4 says whether the band has been through first-run setup.
    /// Layout observed on firmware AZA3: 41, 01 <len> firmware, 02 <len> name, 03 <7 bytes> model, 04 <flag>.
    static func isInitialized(watchInfo message: [UInt8]) -> Bool? {
        guard message.count >= 3, message[0] == 0x41, message[1] == 1 else { return nil }
        var offset = 3 + Int(message[2])
        guard offset + 2 <= message.count, message[offset] == 2 else { return nil }
        offset += 2 + Int(message[offset + 1])
        guard offset + 8 <= message.count, message[offset] == 3 else { return nil }
        offset += 8
        guard offset + 2 <= message.count, message[offset] == 4 else { return nil }
        switch message[offset + 1] {
        case 0: return false
        case 1: return true
        default: return nil
        }
    }

    /// Returns nil when the length or either checksum does not match.
    static func parse(_ data: [UInt8], mtu: Int) -> Fragment? {
        let start: Int
        let length: Int
        if mtu < 256 {
            guard data.count >= 4, data[0] == data[1] else { return nil }
            length = Int(data[0])
            start = 2
        } else {
            guard data.count >= 6 else { return nil }
            length = Int(data[0]) << 8 | Int(data[1])
            let expected = UInt16(data[2]) << 8 | UInt16(data[3])
            guard crc16([data[0], data[1]]) == expected else { return nil }
            start = 4
        }
        guard length >= 2, data.count == start + length + 2 else { return nil }
        let body = Array(data[start..<(start + length)])
        let bodyCRC = UInt16(data[start + length]) << 8 | UInt16(data[start + length + 1])
        guard crc16(body) == bodyCRC else { return nil }
        let kind = Int(body[0] >> 1) & 0x03
        if kind == 0 || kind == 1 {
            guard body.count >= 4 else { return nil }
            return Fragment(kind: kind, service: body[2], payload: Array(body[4...]))
        }
        return Fragment(kind: kind, service: nil, payload: Array(body[2...]))
    }

    /// Settings reply 0x42 carries one-byte parameters; parameter 5 is the battery level, 0 to 100.
    static func batteryLevel(fromSettingsReply payload: [UInt8]) -> Int? {
        guard let first = payload.first, first == 0x42 else { return nil }
        var index = 1
        while index + 1 < payload.count {
            if payload[index] == 5 {
                let level = Int(payload[index + 1])
                return level <= 100 ? level : nil
            }
            index += 2
        }
        return nil
    }

    /// Guards every write: the encoder must reproduce a published live frame, and the
    /// decoder must read it back, before anything is sent to a band.
    static let selfCheckPasses: Bool = {
        let known: [UInt8] = [0x00, 0x0D, 0xC5, 0xC1, 0x00, 0x40, 0x01, 0x01, 0x01, 0x04, 0x02,
                              0x00, 0x00, 0x00, 0x05, 0x00, 0x0E, 0x60, 0xEA]
        let encoded = SapTransport.frame(service: SapTransport.setupService,
                                         payload: SapTransport.watchInfoRequest, mtu: 500)
        guard encoded == known else { return false }
        guard let back = SapTransport.parse(known, mtu: 500), back.kind == 0,
              back.service == SapTransport.setupService,
              back.payload == SapTransport.watchInfoRequest else { return false }
        guard SapTransport.batteryLevel(fromSettingsReply: [0x42, 0x05, 0x3A, 0x06, 0x00]) == 58 else { return false }
        // Published vector: 2023-11-14 22:13:20 UTC, UTC+3, language 57, 24-hour clock.
        let settings: [UInt8] = [0x83, 0x01, 0x39, 0x00, 0x02, 0x00, 0x03, 0x0A,
                                 0x31, 0x37, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30,
                                 0x04, 0x00, 0x30, 0x2A, 0x05, 0x01]
        let built = SapTransport.initSettings(localeID: 57, at: Date(timeIntervalSince1970: 1_700_000_000),
                                              offsetSeconds: 10_800, hour24: true)
        guard built == settings else { return false }
        // A long message must split into frames that fit and reassemble to the same bytes.
        let long = [UInt8](repeating: 0xA5, count: 1_200)
        let pieces = SapTransport.frames(service: 10, payload: long, mtu: 500)
        guard pieces.count == 3, pieces.allSatisfy({ $0.count <= 500 }) else { return false }
        var joined: [UInt8] = []
        for piece in pieces {
            guard let part = SapTransport.parse(piece, mtu: 500) else { return false }
            joined += part.payload
        }
        return joined == long
    }()
}
