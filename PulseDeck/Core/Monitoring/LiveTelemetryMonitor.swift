import CoreMotion
import Darwin
import Foundation
import Network
import UIKit

@MainActor
final class LiveTelemetryMonitor {
    var onEvent: ((SessionEvent) -> Void)?

    private let batteryService = BatteryService()
    private let powerService = PowerStateService()
    private let storageInspector = StorageInspector()
    private let memoryService = MemoryIndicatorService()
    private let fpsService = FPSService()
    private let networkService = NetworkService()
    private let motionService = MotionService()
    private let deviceProvider = DeviceProfileProvider()

    init() {
        let forward: (SessionEvent) -> Void = { [weak self] event in
            self?.onEvent?(event)
        }

        batteryService.onEvent = forward
        powerService.onEvent = forward
        memoryService.onEvent = forward
        networkService.onEvent = forward
        motionService.onEvent = forward
    }

    func start() {
        batteryService.start()
        powerService.start()
        memoryService.start()
        fpsService.start()
        networkService.start()
        motionService.start()
    }

    func stop() {
        batteryService.stop()
        powerService.stop()
        memoryService.stop()
        fpsService.stop()
        networkService.stop()
        motionService.stop()
    }

    func snapshot(at date: Date) -> TelemetrySnapshot {
        let thermal = powerService.thermalSnapshot()
        let lowPowerMode = powerService.isLowPowerModeEnabled

        return TelemetrySnapshot(
            timestamp: date,
            battery: batteryService.snapshot(lowPowerMode: lowPowerMode),
            thermal: thermal,
            storage: storageInspector.snapshot(),
            memory: memoryService.snapshot(thermalState: thermal.stateDescription),
            fps: fpsService.snapshot(),
            network: networkService.snapshot(),
            motion: motionService.snapshot(),
            device: deviceProvider.snapshot()
        )
    }
}

private final class BatteryService {
    var onEvent: ((SessionEvent) -> Void)?

    private var notificationTokens: [NSObjectProtocol] = []
    private var level: Float?
    private var stateDescription = "Unavailable"
    private var lastSignature: String?

    func start() {
        guard notificationTokens.isEmpty else { return }

        UIDevice.current.isBatteryMonitoringEnabled = true
        refresh(emitEvent: false)

        let center = NotificationCenter.default
        notificationTokens.append(
            center.addObserver(
                forName: UIDevice.batteryLevelDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refresh(emitEvent: true)
            }
        )
        notificationTokens.append(
            center.addObserver(
                forName: UIDevice.batteryStateDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refresh(emitEvent: true)
            }
        )
    }

    func stop() {
        notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
        notificationTokens.removeAll()
        UIDevice.current.isBatteryMonitoringEnabled = false
    }

    func snapshot(lowPowerMode: Bool) -> BatterySnapshot {
        BatterySnapshot(
            level: level,
            stateDescription: stateDescription,
            isLowPowerModeEnabled: lowPowerMode,
            tier: .real
        )
    }

    private func refresh(emitEvent: Bool) {
        let currentLevel = UIDevice.current.batteryLevel
        level = currentLevel >= 0 ? currentLevel : nil
        stateDescription = UIDevice.current.batteryState.pulseDescription

        let signature = "\(stateDescription)-\(level.map { String(format: "%.2f", $0) } ?? "nil")"
        defer { lastSignature = signature }

        guard emitEvent, lastSignature != nil, signature != lastSignature else { return }
        onEvent?(
            SessionEvent(
                timestamp: .now,
                kind: .battery,
                title: "Battery changed",
                detail: "\(PulseFormatters.battery(level)) • \(stateDescription)",
                tier: .real,
                origin: .system,
                mode: .live
            )
        )
    }
}

private final class PowerStateService {
    var onEvent: ((SessionEvent) -> Void)?

    private var notificationTokens: [NSObjectProtocol] = []
    private var thermalDescription = ProcessInfo.processInfo.thermalState.pulseDescription
    private(set) var isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
    private var lastThermalDescription: String?
    private var lastLowPowerState: Bool?

    func start() {
        guard notificationTokens.isEmpty else { return }

        refreshThermal(emitEvent: false)
        refreshLowPower(emitEvent: false)

        let center = NotificationCenter.default
        notificationTokens.append(
            center.addObserver(
                forName: ProcessInfo.thermalStateDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refreshThermal(emitEvent: true)
            }
        )
        notificationTokens.append(
            center.addObserver(
                forName: .NSProcessInfoPowerStateDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refreshLowPower(emitEvent: true)
            }
        )
    }

    func stop() {
        notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
        notificationTokens.removeAll()
    }

    func thermalSnapshot() -> ThermalSnapshot {
        ThermalSnapshot(stateDescription: thermalDescription, tier: .real)
    }

    private func refreshThermal(emitEvent: Bool) {
        thermalDescription = ProcessInfo.processInfo.thermalState.pulseDescription
        defer { lastThermalDescription = thermalDescription }

        guard emitEvent, lastThermalDescription != nil, thermalDescription != lastThermalDescription else {
            return
        }

        onEvent?(
            SessionEvent(
                timestamp: .now,
                kind: .thermal,
                title: "Thermal state updated",
                detail: thermalDescription,
                tier: .real,
                origin: .system,
                mode: .live
            )
        )
    }

    private func refreshLowPower(emitEvent: Bool) {
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        defer { lastLowPowerState = isLowPowerModeEnabled }

        guard emitEvent, let lastLowPowerState, lastLowPowerState != isLowPowerModeEnabled else {
            return
        }

        onEvent?(
            SessionEvent(
                timestamp: .now,
                kind: .battery,
                title: "Low Power Mode",
                detail: isLowPowerModeEnabled ? "Enabled" : "Disabled",
                tier: .real,
                origin: .system,
                mode: .live
            )
        )
    }
}

private struct StorageInspector {
    func snapshot() -> StorageSnapshot {
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())

        do {
            let values = try homeURL.resourceValues(forKeys: [
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeTotalCapacityKey
            ])

            let total = values.volumeTotalCapacity.flatMap { Int64($0) }
            let available = values.volumeAvailableCapacityForImportantUsage.flatMap { Int64($0) }

            return StorageSnapshot(
                totalBytes: total,
                availableBytes: available,
                tier: .real
            )
        } catch {
            return StorageSnapshot(totalBytes: nil, availableBytes: nil, tier: .real)
        }
    }
}

private final class MemoryIndicatorService {
    var onEvent: ((SessionEvent) -> Void)?

    private var notificationTokens: [NSObjectProtocol] = []
    private(set) var warningCount = 0
    private(set) var lastWarningAt: Date?

    func start() {
        guard notificationTokens.isEmpty else { return }

        notificationTokens.append(
            NotificationCenter.default.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                self.warningCount += 1
                self.lastWarningAt = .now
                self.onEvent?(
                    SessionEvent(
                        timestamp: .now,
                        kind: .memory,
                        title: "Memory warning",
                        detail: "iOS asked the app to shed memory aggressively.",
                        tier: .real,
                        origin: .system,
                        mode: .live
                    )
                )
            }
        )
    }

    func stop() {
        notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
        notificationTokens.removeAll()
    }

    func snapshot(thermalState: String) -> MemorySnapshot {
        let warningText: String
        if let lastWarningAt {
            let seconds = Date().timeIntervalSince(lastWarningAt)
            if seconds < 90 {
                warningText = "Recent warning \(Int(seconds))s ago • thermal \(thermalState.lowercased())"
            } else {
                warningText = "Recovered • \(warningCount) warnings this session"
            }
        } else {
            warningText = "No memory warnings this session"
        }

        return MemorySnapshot(
            residentFootprintBytes: residentFootprint(),
            warningCount: warningCount,
            lastWarningAt: lastWarningAt,
            indicatorDescription: warningText,
            tier: .hybrid
        )
    }

    private func residentFootprint() -> UInt64? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)

        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), reboundPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else { return nil }
        return info.phys_footprint
    }
}

private final class FPSService {
    private let proxy = DisplayLinkProxy()
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameCount = 0
    private var framesPerSecond: Double?

    init() {
        proxy.owner = self
    }

    func start() {
        guard displayLink == nil else { return }

        let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.step(_:)))
        if #available(iOS 15.0, *) {
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 20, maximum: 120, preferred: 60)
        }
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        lastTimestamp = 0
        frameCount = 0
    }

    func snapshot() -> FPSSnapshot {
        FPSSnapshot(framesPerSecond: framesPerSecond, tier: .estimated)
    }

    fileprivate func handleFrame(_ link: CADisplayLink) {
        if lastTimestamp == 0 {
            lastTimestamp = link.timestamp
            return
        }

        frameCount += 1
        let elapsed = link.timestamp - lastTimestamp

        guard elapsed >= 0.5 else { return }

        framesPerSecond = Double(frameCount) / elapsed
        frameCount = 0
        lastTimestamp = link.timestamp
    }
}

private final class DisplayLinkProxy: NSObject {
    weak var owner: FPSService?

    @objc func step(_ link: CADisplayLink) {
        owner?.handleFrame(link)
    }
}

private final class NetworkService {
    var onEvent: ((SessionEvent) -> Void)?

    private let queue = DispatchQueue(label: "PulseDeck.NetworkMonitor")
    private var monitor: NWPathMonitor?
    private var isRunning = false
    private var pathState: NetworkPathState = .offline
    private var interfaceDescription = "Unknown"
    private var lastSignature: String?

    func start() {
        guard !isRunning else { return }
        isRunning = true
        let monitor = NWPathMonitor()
        self.monitor = monitor

        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }

            let nextState: NetworkPathState
            if path.status != .satisfied {
                nextState = .offline
            } else if path.isConstrained || path.isExpensive {
                nextState = .constrained
            } else {
                nextState = .online
            }

            let interface: String
            if path.usesInterfaceType(.wifi) {
                interface = "Wi-Fi"
            } else if path.usesInterfaceType(.cellular) {
                interface = "Cellular"
            } else if path.usesInterfaceType(.wiredEthernet) {
                interface = "Ethernet"
            } else if path.usesInterfaceType(.loopback) {
                interface = "Loopback"
            } else {
                interface = "Other"
            }

            let signature = "\(nextState.rawValue)-\(interface)"

            DispatchQueue.main.async {
                self.pathState = nextState
                self.interfaceDescription = interface
                defer { self.lastSignature = signature }

                guard self.lastSignature != nil, self.lastSignature != signature else { return }
                self.onEvent?(
                    SessionEvent(
                        timestamp: .now,
                        kind: .network,
                        title: "Path changed",
                        detail: "\(nextState.rawValue.capitalized) via \(interface)",
                        tier: .real,
                        origin: .system,
                        mode: .live
                    )
                )
            }
        }

        monitor.start(queue: queue)
    }

    func stop() {
        guard isRunning else { return }
        monitor?.cancel()
        monitor = nil
        isRunning = false
    }

    func snapshot() -> NetworkSnapshot {
        NetworkSnapshot(
            pathState: pathState,
            interfaceDescription: interfaceDescription,
            estimatedDownlinkMbps: nil,
            estimatedUplinkMbps: nil,
            tier: .real,
            throughputTier: .placeholder
        )
    }
}

private final class MotionService {
    var onEvent: ((SessionEvent) -> Void)?

    private let motionManager = CMMotionManager()
    private var notificationTokens: [NSObjectProtocol] = []
    private var orientationDescription = UIDevice.current.orientation.pulseDescription
    private var tiltMagnitude: Double?
    private var isTracking = false
    private var lastOrientation: String?

    func start() {
        guard notificationTokens.isEmpty else { return }

        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        refreshOrientation(emitEvent: false)

        notificationTokens.append(
            NotificationCenter.default.addObserver(
                forName: UIDevice.orientationDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refreshOrientation(emitEvent: true)
            }
        )

        guard motionManager.isDeviceMotionAvailable else {
            isTracking = false
            tiltMagnitude = nil
            return
        }

        isTracking = true
        motionManager.deviceMotionUpdateInterval = 0.35
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let gravity = motion?.gravity else { return }
            self.tiltMagnitude = sqrt((gravity.x * gravity.x) + (gravity.y * gravity.y))
        }
    }

    func stop() {
        notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
        notificationTokens.removeAll()
        motionManager.stopDeviceMotionUpdates()
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }

    func snapshot() -> MotionSnapshot {
        MotionSnapshot(
            orientationDescription: orientationDescription,
            tiltMagnitude: tiltMagnitude,
            isTracking: isTracking,
            tier: .real
        )
    }

    private func refreshOrientation(emitEvent: Bool) {
        orientationDescription = UIDevice.current.orientation.pulseDescription
        defer { lastOrientation = orientationDescription }

        guard emitEvent, lastOrientation != nil, lastOrientation != orientationDescription else { return }
        onEvent?(
            SessionEvent(
                timestamp: .now,
                kind: .motion,
                title: "Orientation changed",
                detail: orientationDescription,
                tier: .real,
                origin: .system,
                mode: .live
            )
        )
    }
}

private struct DeviceProfileProvider {
    func snapshot() -> DeviceSnapshot {
        let device = UIDevice.current

        return DeviceSnapshot(
            name: device.name,
            model: device.model,
            identifier: machineIdentifier(),
            systemVersion: "\(device.systemName) \(device.systemVersion)",
            processorCount: ProcessInfo.processInfo.processorCount,
            physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory,
            isSimulator: isSimulator,
            tier: .real
        )
    }

    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    private func machineIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)

        return withUnsafePointer(to: &systemInfo.machine) { machinePtr in
            machinePtr.withMemoryRebound(to: CChar.self, capacity: 1) { cStringPtr in
                String(cString: cStringPtr)
            }
        }
    }
}

private extension UIDevice.BatteryState {
    var pulseDescription: String {
        switch self {
        case .charging:
            return "Charging"
        case .full:
            return "Full"
        case .unplugged:
            return "On Battery"
        case .unknown:
            return "Unavailable"
        @unknown default:
            return "Unavailable"
        }
    }
}

private extension ProcessInfo.ThermalState {
    var pulseDescription: String {
        switch self {
        case .nominal:
            return "Nominal"
        case .fair:
            return "Fair"
        case .serious:
            return "Serious"
        case .critical:
            return "Critical"
        @unknown default:
            return "Unknown"
        }
    }
}

private extension UIDeviceOrientation {
    var pulseDescription: String {
        switch self {
        case .portrait:
            return "Portrait"
        case .portraitUpsideDown:
            return "Upside Down"
        case .landscapeLeft:
            return "Landscape Left"
        case .landscapeRight:
            return "Landscape Right"
        case .faceUp:
            return "Face Up"
        case .faceDown:
            return "Face Down"
        case .unknown:
            return "Unknown"
        @unknown default:
            return "Unknown"
        }
    }
}
