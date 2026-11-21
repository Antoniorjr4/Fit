import CallKit
import Foundation

/// Watches the phone's call state. iOS tells an app that a call is ringing,
/// answered or over, but never who is calling.
final class CallMonitor: NSObject, CXCallObserverDelegate {
    enum Event { case ringing, answered, ended }

    private let observer = CXCallObserver()
    private var ringing: Set<UUID> = []
    var onEvent: ((Event) -> Void)?

    override init() {
        super.init()
        observer.setDelegate(self, queue: .main)
    }

    func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        if call.hasEnded {
            if ringing.remove(call.uuid) != nil { onEvent?(.ended) }
        } else if call.hasConnected {
            if ringing.contains(call.uuid) { onEvent?(.answered) }
        } else if !call.isOutgoing, !ringing.contains(call.uuid) {
            ringing.insert(call.uuid)
            onEvent?(.ringing)
        }
    }
}
