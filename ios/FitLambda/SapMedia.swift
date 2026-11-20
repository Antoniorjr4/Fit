import Foundation
import MediaPlayer
import AVFoundation

/// Music screen of the band (SAP service 9).
/// Message ids and parameters ported from Fit3MediaCodec.kt in yuriyurin/Fit3-App (GPL-3.0).
enum SapMedia {
    static let service: UInt8 = 9
    static let appID = "com.apple.Music"
    static let maxVolume = 15

    enum Remote: Int { case stop = 1, playPause, previous, next }

    struct State: Equatable {
        var playback = 1          // 1 stopped, 2 paused, 3 playing
        var positionMillis: UInt64 = 0
        var durationMillis: UInt64 = 0
        var title = ""
        var artist = ""
        var identity: String { "\(title)|\(artist)|\(durationMillis)" }
    }

    /// Id of a request coming from the band, or nil for anything else.
    static func requestID(_ message: [UInt8]) -> Int? {
        guard let first = message.first, first & 0x40 == 0 else { return nil }
        return Int(first & 0x3F)
    }

    /// The band sends one packet when a button goes down and one when it is released.
    static func remote(_ message: [UInt8]) -> (action: Remote, pressed: Bool)? {
        guard requestID(message) == 4 else { return nil }
        var action: Remote?
        var key = 2
        var index = 1
        while index + 1 < message.count {
            if message[index] == 1 { action = Remote(rawValue: Int(message[index + 1])) }
            if message[index] == 2 { key = Int(message[index + 1]) }
            index += 2
        }
        return action.map { ($0, key == 2) }
    }

    /// The screen state the band reports (0 closed, 1 visible, 2 always-on); echoed back.
    static func screenState(_ message: [UInt8]) -> UInt8 {
        (message.count >= 3 && message[1] == 1 && message[2] <= 2) ? message[2] : 1
    }

    private static func little(_ value: UInt64, bytes: Int) -> [UInt8] {
        (0..<bytes).map { UInt8((value >> (8 * UInt64($0))) & 0xFF) }
    }
    private static func text(_ id: UInt8, _ value: String, limit: Int = 100) -> [UInt8] {
        let bytes = SapNotify.utf8Prefix(value, limit: limit)
        return [id, UInt8(bytes.count)] + bytes
    }
    private static func fixed(_ id: UInt8, _ parameters: [[UInt8]]) -> [UInt8] {
        [0x40 | id, UInt8(parameters.count)] + parameters.flatMap { $0 }
    }
    private static func variable(_ id: UInt8, _ parameters: [[UInt8]]) -> [UInt8] {
        [0xC0 | id, UInt8(parameters.count)] + parameters.flatMap { $0 }
    }

    static func screenAnswer(_ state: UInt8) -> [UInt8] { fixed(23, [[1, state]]) }
    static func capability() -> [UInt8] {
        fixed(20, [[1] + little(UInt64(maxVolume), bytes: 4), [2] + little(UInt64(maxVolume), bytes: 4)])
    }
    static func volume(_ level: Int) -> [UInt8] {
        fixed(21, [[1] + little(UInt64(max(0, min(maxVolume, level))), bytes: 4), [2, 2]])
    }
    static func playerAvailable(_ available: Bool) -> [UInt8] {
        variable(24, [[1, available ? 1 : 0], text(2, available ? appID : "")])
    }
    static func playback(_ state: State) -> [UInt8] {
        variable(18, [[1, UInt8(max(1, min(3, state.playback)))], [2] + little(state.positionMillis, bytes: 8),
                      [4] + little(UInt64.max, bytes: 8), text(3, appID)])
    }
    static func metadata(_ state: State) -> [UInt8] {
        variable(17, [[1] + little(state.durationMillis, bytes: 8), text(2, state.title), text(3, state.artist),
                      text(4, ""), text(5, appID)])
    }
    static func appInfo() -> [UInt8] { variable(22, [text(1, appID), text(2, "Apple Music"), text(3, "")]) }
    static func emptyQueue() -> [UInt8] {
        variable(25, [text(1, appID), text(2, ""), [3] + little(0, bytes: 4), text(4, "")])
    }
}

/// The Apple Music player of this iPhone. iOS gives apps no control over other apps' playback
/// (Spotify, YouTube and so on), and no way to change the system volume.
final class MusicBridge {
    private let player = MPMusicPlayerController.systemMusicPlayer
    private var observers: [NSObjectProtocol] = []
    var onChange: (() -> Void)?

    init() {
        player.beginGeneratingPlaybackNotifications()
        for name in [Notification.Name.MPMusicPlayerControllerNowPlayingItemDidChange,
                     Notification.Name.MPMusicPlayerControllerPlaybackStateDidChange] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: player, queue: .main) { [weak self] _ in
                self?.onChange?()
            })
        }
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        player.endGeneratingPlaybackNotifications()
    }

    var state: SapMedia.State {
        var state = SapMedia.State()
        switch player.playbackState {
        case .playing, .seekingForward, .seekingBackward: state.playback = 3
        case .paused, .interrupted: state.playback = 2
        default: state.playback = 1
        }
        if let item = player.nowPlayingItem {
            state.title = item.title ?? ""
            state.artist = item.artist ?? ""
            state.durationMillis = UInt64(max(0, item.playbackDuration) * 1000)
            let position = player.currentPlaybackTime
            state.positionMillis = position.isFinite ? UInt64(max(0, position) * 1000) : 0
        }
        return state
    }

    var volume: Int { Int((AVAudioSession.sharedInstance().outputVolume * Float(SapMedia.maxVolume)).rounded()) }

    func perform(_ action: SapMedia.Remote) {
        switch action {
        case .stop: player.pause()
        case .playPause: player.playbackState == .playing ? player.pause() : player.play()
        case .previous: player.skipToPreviousItem()
        case .next: player.skipToNextItem()
        }
    }
}
