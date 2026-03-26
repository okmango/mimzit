import Network
import Foundation

/// Thread-safe network connectivity monitor using NWPathMonitor.
///
/// Used by TranscriptionService to guard against calling the Whisper API
/// when there is no network connection, providing a better UX than a
/// URLSession timeout error.
///
/// ## Usage
/// ```swift
/// let monitor = NetworkMonitor()
/// if monitor.isConnected {
///     // proceed with API call
/// }
/// ```
///
/// Adapted from carufus_whozit/Whozit/Services/TranscriptionService.swift (NetworkMonitor class).
/// Updated queue label to com.okmango.mimzit.network.
final class NetworkMonitor: @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.okmango.mimzit.network")
    private let lock = NSLock()
    private var _isConnected: Bool = true

    /// Whether the device currently has a usable network path.
    var isConnected: Bool { lock.withLock { _isConnected } }

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            self.lock.withLock { self._isConnected = path.status == .satisfied }
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }
}
