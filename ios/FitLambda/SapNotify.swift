import Foundation

/// Notifications shown on the band (SAP service 7).
/// Packet layout ported from Fit3NotificationCodec.kt in yuriyurin/Fit3-App (GPL-3.0),
/// by way of NotificationCodec.swift in gokularumugam/fit3bridge.
enum SapNotify {
    static let service: UInt8 = 7
    /// Asks the band which icon format it accepts; the stock app always sends this first.
    static let capabilityRequest: [UInt8] = [0x0D]

    enum Kind: String {
        case message, mail, other

        var appID: Int { self == .message ? 22 : (self == .mail ? 23 : 24) }
        var appName: String { self == .message ? "Messages" : (self == .mail ? "Mail" : "FitLambda") }
        /// Package names the band firmware may already know an icon for.
        var packageName: String {
            self == .message ? "com.samsung.android.messaging" : (self == .mail ? "com.google.android.gm" : "com.annalabs.fitlambda")
        }
        var category: String? { self == .message ? "msg" : (self == .mail ? "email" : nil) }
    }

    /// At most `limit` bytes of UTF-8, never cutting a character in half.
    static func utf8Prefix(_ value: String, limit: Int) -> [UInt8] {
        var out: [UInt8] = []
        for scalar in value.unicodeScalars {
            let encoded = Array(String(scalar).utf8)
            if out.count + encoded.count > limit { break }
            out += encoded
        }
        return out
    }

    private static func shortText(_ id: UInt8, _ value: String) -> [UInt8] {
        let bytes = utf8Prefix(value, limit: 60)
        return [id, UInt8(bytes.count)] + bytes
    }

    private static func little(_ value: UInt64, bytes: Int) -> [UInt8] {
        (0..<bytes).map { UInt8((value >> (8 * UInt64($0))) & 0xFF) }
    }

    /// Android package names of common apps, so the band can label the notification by app.
    private static let knownPackages: [String: String] = [
        "whatsapp": "com.whatsapp", "telegram": "org.telegram.messenger", "gmail": "com.google.android.gm",
        "instagram": "com.instagram.android", "messenger": "com.facebook.orca", "signal": "org.thoughtcrime.securesms",
    ]

    static func notification(sequence: Int32, title: String, text: String, kind: Kind, app: String = "", at date: Date) -> [UInt8] {
        let custom = app.trimmingCharacters(in: .whitespaces)
        let appName = custom.isEmpty ? kind.appName : custom
        let packageName = custom.isEmpty ? kind.packageName : (knownPackages[custom.lowercased()] ?? kind.packageName)
        // Each forwarded app gets its own stable id so the band groups its notifications apart.
        let appID = custom.isEmpty ? kind.appID : 30 + Int(custom.lowercased().unicodeScalars.reduce(UInt32(5381)) { ($0 &* 33) &+ $1.value } % 60)
        let millis = UInt64(max(0, (date.timeIntervalSince1970 * 1000).rounded()))
        let body = utf8Prefix(text, limit: 100)
        var out: [UInt8] = [0x80, UInt8(10 + (kind.category == nil ? 0 : 1))]
        out += [0, 1]
        out += [1] + little(UInt64(UInt32(bitPattern: sequence)), bytes: 4)
        out += shortText(6, String(appID))
        out += [2] + little(millis, bytes: 8)
        out += shortText(3, title)
        out += [4, UInt8(body.count & 0xFF), UInt8(body.count >> 8)] + body
        out += shortText(14, appName)
        out += [15, 1]
        out += [16, 0]
        if let category = kind.category { out += shortText(12, category) }
        out += shortText(18, packageName)
        return out
    }

    /// The band's answer to a new notification: its sequence and whether it was accepted.
    static func acknowledgement(_ message: [UInt8]) -> (sequence: Int32, accepted: Bool)? {
        // A real Fit3 answers with the short form 44 01 <sequence>; the long form carries an explicit result.
        let short = message.count == 6 && message[0] == 0x44 && message[1] == 1
        let long = message.count == 8 && message[0] == 0x40 && message[1] == 1 && message[6] == 11
        guard short || long else { return nil }
        let raw = UInt32(message[2]) | UInt32(message[3]) << 8 | UInt32(message[4]) << 16 | UInt32(message[5]) << 24
        return (Int32(bitPattern: raw), short || message[7] == 1)
    }
}
