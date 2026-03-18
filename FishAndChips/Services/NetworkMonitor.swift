import Foundation
import Network
import Combine

@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    enum ConnectionType: String {
        case wifi
        case cellular
        case wiredEthernet
        case none
    }

    @Published private(set) var isOnline: Bool = true
    @Published private(set) var connectionType: ConnectionType = .wifi

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.nicolascooper.FishAndChips.network-monitor")

    var onReconnect: (() async -> Void)?

    private var wasOffline = false

    private init() {
        monitor = NWPathMonitor()
        startMonitoring()
    }

    /// For testing / dependency injection
    init(monitor: NWPathMonitor) {
        self.monitor = monitor
        startMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }

                let online = path.status == .satisfied
                let type: ConnectionType = {
                    if path.usesInterfaceType(.wifi) { return .wifi }
                    if path.usesInterfaceType(.cellular) { return .cellular }
                    if path.usesInterfaceType(.wiredEthernet) { return .wiredEthernet }
                    return .none
                }()

                let reconnected = !self.isOnline && online

                self.isOnline = online
                self.connectionType = type
                self.wasOffline = !online

                debugLog("NetworkMonitor: \(online ? "online" : "offline") via \(type.rawValue)")

                if reconnected {
                    debugLog("NetworkMonitor: reconnected — triggering sync")
                    await self.onReconnect?()
                }
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
