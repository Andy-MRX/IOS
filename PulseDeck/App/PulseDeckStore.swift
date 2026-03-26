import Foundation
import SwiftUI

@MainActor
final class PulseDeckStore: ObservableObject {
    @Published private(set) var snapshot = TelemetrySnapshot.empty
    @Published private(set) var batteryHistory: [MetricPoint] = []
    @Published private(set) var thermalHistory: [MetricPoint] = []
    @Published private(set) var fpsHistory: [MetricPoint] = []
    @Published private(set) var networkHistory: [MetricPoint] = []
    @Published private(set) var storageHistory: [MetricPoint] = []
    @Published private(set) var memoryHistory: [MetricPoint] = []
    @Published private(set) var motionHistory: [MetricPoint] = []
    @Published private(set) var timeline: [SessionEvent] = []
    @Published private(set) var sampleCount = 0
    @Published var mode: TelemetryMode
    @Published var settings: SettingsState

    let sessionStartedAt = Date()

    private let liveMonitor = LiveTelemetryMonitor()
    private let demoMonitor = DemoTelemetryMonitor()
    private var refreshTimer: Timer?
    private var didStart = false
    private var previousSnapshot: TelemetrySnapshot?

    init() {
        mode = Self.loadMode()
        settings = Self.loadSettings()

        liveMonitor.onEvent = { [weak self] event in
            Task { @MainActor [weak self] in
                guard let self, self.mode == .live else { return }
                self.record(event)
            }
        }
    }

    func start() {
        guard !didStart else { return }
        didStart = true

        syncMonitorStateForCurrentMode()
        record(
            makeEvent(
                kind: .lifecycle,
                title: "Session armed",
                detail: mode == .live
                    ? "Live sampling is active. Throughput remains clearly labeled as a placeholder until an explicit benchmark is added."
                    : "Demo feed is active. Values are synthetic and labeled accordingly so the deck stays visually rich without pretending to be live.",
                tier: mode == .live ? .hybrid : .estimated
            )
        )

        refreshSnapshot()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshSnapshot()
            }
        }
    }

    func setMode(_ newMode: TelemetryMode) {
        guard mode != newMode else { return }
        mode = newMode
        persistMode()

        previousSnapshot = nil
        resetHistories()
        syncMonitorStateForCurrentMode()

        record(
            makeEvent(
                kind: .mode,
                title: "Data source switched",
                detail: newMode == .live
                    ? "Live feed re-armed. Only public on-device APIs are sampled; throughput stays placeholder until a consented test path exists."
                    : "Demo feed armed. Charts now use seeded values so dashboards and alerts remain active during demos and simulator sessions.",
                tier: newMode == .live ? .hybrid : .estimated
            )
        )

        refreshSnapshot()
    }

    func updateSettings(_ mutate: (inout SettingsState) -> Void) {
        mutate(&settings)
        persistSettings()
        trimAllHistories()
        trimTimelineIfNeeded()
    }

    func handleScenePhase(_ phase: ScenePhase) {
        let detail: String
        switch phase {
        case .active:
            syncMonitorStateForCurrentMode()
            detail = "Foreground sampling active"
            refreshSnapshot()
        case .inactive:
            detail = "Interface inactive"
        case .background:
            liveMonitor.stop()
            detail = "App moved to background"
        @unknown default:
            detail = "Scene moved to an unknown phase"
        }

        record(
            makeEvent(
                kind: .lifecycle,
                title: "Scene phase",
                detail: detail,
                tier: .real
            )
        )
    }

    func trimmedValues(from history: [MetricPoint]) -> [Double] {
        Array(history.suffix(settings.historyWindow)).numericValues
    }

    func previousValue(in history: [MetricPoint]) -> Double? {
        guard history.count >= 2 else { return nil }
        return history[history.count - 2].value
    }

    var uptimeText: String {
        PulseFormatters.duration.string(from: Date().timeIntervalSince(sessionStartedAt)) ?? "00:00:00"
    }

    var heroStatusLine: String {
        "\(mode.bannerTitle) • \(snapshot.network.pathState.rawValue.capitalized) • \(sampleCount) samples"
    }

    var lastUpdatedText: String {
        "Updated \(PulseFormatters.relativeTime(since: snapshot.timestamp))"
    }

    var modeDisclosure: String {
        mode.detail
    }

    var throughputDisclosure: String {
        mode == .live
            ? "Live reachability is real. Mbps stays labeled placeholder until you add an explicit opt-in throughput test."
            : "Demo Mbps values are synthetic on purpose so demos can show richer motion without claiming hidden iOS access."
    }

    var filteredTimeline: [SessionEvent] {
        Array(
            timeline
                .filter { settings.timelineFilter.matches($0) }
                .prefix(settings.timelineLimit)
        )
    }

    var dashboardHighlights: [DashboardHighlight] {
        let alerts = activeAlertHighlights

        return [
            DashboardHighlight(
                symbol: mode.iconName,
                title: "Feed",
                value: mode.shortLabel,
                detail: mode == .live ? "Public APIs only" : "Synthetic seed active",
                tier: mode == .live ? .real : .estimated
            ),
            DashboardHighlight(
                symbol: "timer",
                title: "Session",
                value: uptimeText,
                detail: "\(sampleCount) samples • \(lastUpdatedText)",
                tier: .real
            ),
            DashboardHighlight(
                symbol: "antenna.radiowaves.left.and.right",
                title: "Reach",
                value: snapshot.network.pathState.rawValue.capitalized,
                detail: mode == .live
                    ? "Path via \(snapshot.network.interfaceDescription) • throughput placeholder"
                    : "Demo \(PulseFormatters.throughput(snapshot.network.estimatedDownlinkMbps)) downlink",
                tier: mode == .live ? .hybrid : .estimated
            ),
            DashboardHighlight(
                symbol: alerts.isEmpty ? "checkmark.shield" : "exclamationmark.triangle.fill",
                title: "Watchlist",
                value: alerts.isEmpty ? "Stable" : "\(alerts.count) active",
                detail: alerts.first?.detail ?? "No pressure spikes or disconnects right now",
                tier: alerts.first?.tier ?? .real
            )
        ]
    }

    var timelineHighlights: [DashboardHighlight] {
        let alertCount = timeline.filter(\.isAlert).count

        return [
            DashboardHighlight(
                symbol: "line.3.horizontal.decrease.circle",
                title: "Filter",
                value: settings.timelineFilter.rawValue,
                detail: settings.timelineFilter.subtitle,
                tier: .hybrid
            ),
            DashboardHighlight(
                symbol: "clock.arrow.circlepath",
                title: "Events",
                value: "\(timeline.count)",
                detail: "\(filteredTimeline.count) visible • \(settings.timelineLimit) cap",
                tier: .real
            ),
            DashboardHighlight(
                symbol: alertCount == 0 ? "checkmark.circle" : "bell.badge",
                title: "Alerts",
                value: "\(alertCount)",
                detail: alertCount == 0 ? "No alert-class events yet" : "Battery, thermal, memory, or network transitions captured",
                tier: alertCount == 0 ? .real : .hybrid
            ),
            DashboardHighlight(
                symbol: mode.iconName,
                title: "Source",
                value: mode.shortLabel,
                detail: mode == .live ? "System notifications while live is armed" : "Synthetic timeline notes drive the demo feed",
                tier: mode == .live ? .real : .estimated
            )
        ]
    }

    var activeAlertHighlights: [DashboardHighlight] {
        var alerts: [DashboardHighlight] = []

        if let level = snapshot.battery.level {
            if level < 0.20 {
                alerts.append(
                    DashboardHighlight(
                        symbol: "battery.25",
                        title: "Battery",
                        value: PulseFormatters.battery(level),
                        detail: "Reserve is critical\(snapshot.battery.isLowPowerModeEnabled ? " • Low Power Mode is on" : "")",
                        tier: .real
                    )
                )
            } else if level < 0.35 || snapshot.battery.isLowPowerModeEnabled {
                alerts.append(
                    DashboardHighlight(
                        symbol: "battery.50",
                        title: "Battery",
                        value: PulseFormatters.battery(level),
                        detail: snapshot.battery.isLowPowerModeEnabled ? "Low Power Mode engaged" : "Battery buffer is trending low",
                        tier: .real
                    )
                )
            }
        }

        if ["Serious", "Critical"].contains(snapshot.thermal.stateDescription) {
            alerts.append(
                DashboardHighlight(
                    symbol: "thermometer.medium",
                    title: "Thermal",
                    value: snapshot.thermal.stateDescription,
                    detail: "Thermal state escalated beyond nominal",
                    tier: .real
                )
            )
        }

        if snapshot.network.pathState != .online {
            alerts.append(
                DashboardHighlight(
                    symbol: "wifi.exclamationmark",
                    title: "Network",
                    value: snapshot.network.pathState.rawValue.capitalized,
                    detail: "Reachability is \(snapshot.network.interfaceDescription.lowercased())-backed right now",
                    tier: mode == .live ? .hybrid : .estimated
                )
            )
        }

        if snapshot.memory.warningCount > 0 {
            alerts.append(
                DashboardHighlight(
                    symbol: "memorychip",
                    title: "Memory",
                    value: "\(snapshot.memory.warningCount) warnings",
                    detail: snapshot.memory.indicatorDescription,
                    tier: .hybrid
                )
            )
        }

        if let fps = snapshot.fps.framesPerSecond, fps < 50 {
            alerts.append(
                DashboardHighlight(
                    symbol: "gauge.with.dots.needle.33percent",
                    title: "Render",
                    value: PulseFormatters.fps(fps),
                    detail: "Frame pacing dipped below the smooth-range target",
                    tier: .estimated
                )
            )
        }

        if let used = snapshot.storage.usedFraction, used > 0.82 {
            alerts.append(
                DashboardHighlight(
                    symbol: "externaldrive.badge.exclamationmark",
                    title: "Storage",
                    value: PulseFormatters.percentage(used),
                    detail: "Available storage is getting tight",
                    tier: .real
                )
            )
        }

        return Array(alerts.prefix(3))
    }

    private func refreshSnapshot() {
        let date = Date()
        let nextSnapshot = mode == .live ? liveMonitor.snapshot(at: date) : demoMonitor.snapshot(at: date)
        let previous = previousSnapshot

        snapshot = nextSnapshot
        sampleCount += 1
        appendHistory(using: nextSnapshot)

        if settings.highlightStatusChanges {
            recordDerivedEvents(current: nextSnapshot, previous: previous)
        }

        previousSnapshot = nextSnapshot
    }

    private func appendHistory(using snapshot: TelemetrySnapshot) {
        append(point: snapshot.battery.level.map(Double.init) ?? batteryHistory.last?.value ?? 0, to: &batteryHistory, at: snapshot.timestamp)
        append(point: thermalChartValue(from: snapshot), to: &thermalHistory, at: snapshot.timestamp)
        append(point: snapshot.fps.framesPerSecond ?? fpsHistory.last?.value ?? 0, to: &fpsHistory, at: snapshot.timestamp)
        append(point: networkChartValue(from: snapshot), to: &networkHistory, at: snapshot.timestamp)
        append(point: snapshot.storage.usedFraction ?? storageHistory.last?.value ?? 0, to: &storageHistory, at: snapshot.timestamp)
        append(point: memoryChartValue(from: snapshot), to: &memoryHistory, at: snapshot.timestamp)
        append(point: snapshot.motion.tiltMagnitude ?? motionHistory.last?.value ?? 0, to: &motionHistory, at: snapshot.timestamp)
    }

    private func append(point: Double, to history: inout [MetricPoint], at timestamp: Date) {
        history.append(MetricPoint(timestamp: timestamp, value: point))
        trim(&history)
    }

    private func recordDerivedEvents(current: TelemetrySnapshot, previous: TelemetrySnapshot?) {
        guard let previous else { return }

        recordBatteryTransition(current: current, previous: previous)
        recordStorageTransition(current: current, previous: previous)
        recordFPSTransition(current: current, previous: previous)

        if mode == .demo {
            recordDemoTransitions(current: current, previous: previous)
        }
    }

    private func recordBatteryTransition(current: TelemetrySnapshot, previous: TelemetrySnapshot) {
        let currentBand = batteryBand(for: current.battery.level)
        let previousBand = batteryBand(for: previous.battery.level)

        guard currentBand != previousBand else { return }

        switch currentBand {
        case .critical:
            record(
                makeSnapshotEvent(
                    kind: .battery,
                    title: "Battery reserve critical",
                    detail: "\(PulseFormatters.battery(current.battery.level)) remaining\(current.battery.isLowPowerModeEnabled ? " • Low Power Mode on" : "")",
                    tier: current.battery.tier
                )
            )
        case .reserve:
            record(
                makeSnapshotEvent(
                    kind: .battery,
                    title: "Battery reserve thinning",
                    detail: "\(PulseFormatters.battery(current.battery.level)) remaining on the current sample path",
                    tier: current.battery.tier
                )
            )
        case .healthy where previousBand == .reserve || previousBand == .critical:
            record(
                makeSnapshotEvent(
                    kind: .battery,
                    title: "Battery buffer recovered",
                    detail: "\(PulseFormatters.battery(current.battery.level)) available again",
                    tier: current.battery.tier
                )
            )
        case .unavailable, .healthy:
            break
        }
    }

    private func recordStorageTransition(current: TelemetrySnapshot, previous: TelemetrySnapshot) {
        let currentBand = storageBand(for: current.storage.usedFraction)
        let previousBand = storageBand(for: previous.storage.usedFraction)

        guard currentBand != previousBand else { return }

        switch currentBand {
        case .tight:
            record(
                makeSnapshotEvent(
                    kind: .info,
                    title: "Storage headroom tight",
                    detail: "\(PulseFormatters.percentage(current.storage.usedFraction)) used • \(PulseFormatters.bytes(current.storage.availableBytes)) free",
                    tier: current.storage.tier
                )
            )
        case .elevated where previousBand == .comfortable:
            record(
                makeSnapshotEvent(
                    kind: .info,
                    title: "Storage usage elevated",
                    detail: "\(PulseFormatters.percentage(current.storage.usedFraction)) of visible capacity is in use",
                    tier: current.storage.tier
                )
            )
        case .comfortable where previousBand != .comfortable:
            record(
                makeSnapshotEvent(
                    kind: .info,
                    title: "Storage headroom recovered",
                    detail: "\(PulseFormatters.bytes(current.storage.availableBytes)) free",
                    tier: current.storage.tier
                )
            )
        case .comfortable, .elevated:
            break
        }
    }

    private func recordFPSTransition(current: TelemetrySnapshot, previous: TelemetrySnapshot) {
        let currentBand = fpsBand(for: current.fps.framesPerSecond)
        let previousBand = fpsBand(for: previous.fps.framesPerSecond)

        guard currentBand != previousBand else { return }

        switch currentBand {
        case .strained:
            record(
                makeSnapshotEvent(
                    kind: .info,
                    title: "Frame pacing softened",
                    detail: "\(PulseFormatters.fps(current.fps.framesPerSecond)) on the latest cadence window",
                    tier: current.fps.tier
                )
            )
        case .steady where previousBand == .strained:
            record(
                makeSnapshotEvent(
                    kind: .info,
                    title: "Frame pacing recovered",
                    detail: "Render cadence returned to \(PulseFormatters.fps(current.fps.framesPerSecond))",
                    tier: current.fps.tier
                )
            )
        case .unknown, .steady:
            break
        }
    }

    private func recordDemoTransitions(current: TelemetrySnapshot, previous: TelemetrySnapshot) {
        if current.thermal.stateDescription != previous.thermal.stateDescription {
            record(
                makeSnapshotEvent(
                    kind: .thermal,
                    title: "Demo thermal shift",
                    detail: current.thermal.stateDescription,
                    tier: current.thermal.tier
                )
            )
        }

        if current.network.pathState != previous.network.pathState {
            record(
                makeSnapshotEvent(
                    kind: .network,
                    title: "Demo path changed",
                    detail: "\(current.network.pathState.rawValue.capitalized) via \(current.network.interfaceDescription)",
                    tier: .estimated
                )
            )
        }

        if current.motion.orientationDescription != previous.motion.orientationDescription {
            record(
                makeSnapshotEvent(
                    kind: .motion,
                    title: "Demo orientation changed",
                    detail: current.motion.orientationDescription,
                    tier: current.motion.tier
                )
            )
        }

        if current.memory.warningCount > previous.memory.warningCount {
            record(
                makeSnapshotEvent(
                    kind: .memory,
                    title: "Demo memory pulse",
                    detail: current.memory.indicatorDescription,
                    tier: current.memory.tier
                )
            )
        }
    }

    private func record(_ event: SessionEvent) {
        timeline.insert(event, at: 0)
        trimTimelineIfNeeded()
    }

    private func syncMonitorStateForCurrentMode() {
        if mode == .live {
            liveMonitor.start()
        } else {
            liveMonitor.stop()
        }
    }

    private func trimTimelineIfNeeded() {
        let cap = max(settings.timelineLimit * 4, 120)
        if timeline.count > cap {
            timeline.removeLast(timeline.count - cap)
        }
    }

    private func trimAllHistories() {
        trim(&batteryHistory)
        trim(&thermalHistory)
        trim(&fpsHistory)
        trim(&networkHistory)
        trim(&storageHistory)
        trim(&memoryHistory)
        trim(&motionHistory)
    }

    private func resetHistories() {
        batteryHistory.removeAll()
        thermalHistory.removeAll()
        fpsHistory.removeAll()
        networkHistory.removeAll()
        storageHistory.removeAll()
        memoryHistory.removeAll()
        motionHistory.removeAll()
    }

    private func trim(_ history: inout [MetricPoint]) {
        let cap = max(settings.historyWindow * 3, 72)
        if history.count > cap {
            history.removeFirst(history.count - cap)
        }
    }

    private func makeEvent(
        kind: SessionEventKind,
        title: String,
        detail: String,
        tier: CapabilityTier,
        origin: EventOrigin = .app,
        mode overrideMode: TelemetryMode? = nil
    ) -> SessionEvent {
        SessionEvent(
            timestamp: .now,
            kind: kind,
            title: title,
            detail: detail,
            tier: tier,
            origin: origin,
            mode: overrideMode ?? mode
        )
    }

    private func makeSnapshotEvent(
        kind: SessionEventKind,
        title: String,
        detail: String,
        tier: CapabilityTier
    ) -> SessionEvent {
        makeEvent(
            kind: kind,
            title: title,
            detail: detail,
            tier: tier,
            origin: mode == .live ? .inferred : .demo
        )
    }

    private func networkChartValue(from snapshot: TelemetrySnapshot) -> Double {
        if let downlink = snapshot.network.estimatedDownlinkMbps {
            return downlink
        }

        switch snapshot.network.pathState {
        case .online:
            return 1
        case .constrained:
            return 0.45
        case .offline:
            return 0
        }
    }

    private func thermalChartValue(from snapshot: TelemetrySnapshot) -> Double {
        switch snapshot.thermal.stateDescription {
        case "Nominal":
            return 0.2
        case "Fair":
            return 0.45
        case "Serious":
            return 0.72
        case "Critical":
            return 1.0
        default:
            return thermalHistory.last?.value ?? 0
        }
    }

    private func memoryChartValue(from snapshot: TelemetrySnapshot) -> Double {
        if let footprint = snapshot.memory.residentFootprintBytes {
            return Double(footprint) / 1_048_576
        }
        return memoryHistory.last?.value ?? 0
    }

    private func batteryBand(for level: Float?) -> BatteryBand {
        guard let level else { return .unavailable }
        if level < 0.20 {
            return .critical
        }
        if level < 0.35 {
            return .reserve
        }
        return .healthy
    }

    private func fpsBand(for fps: Double?) -> FPSBand {
        guard let fps else { return .unknown }
        return fps < 50 ? .strained : .steady
    }

    private func storageBand(for usedFraction: Double?) -> StorageBand {
        guard let usedFraction else { return .comfortable }
        if usedFraction > 0.82 {
            return .tight
        }
        if usedFraction > 0.68 {
            return .elevated
        }
        return .comfortable
    }

    private func persistMode() {
        UserDefaults.standard.set(mode.rawValue, forKey: DefaultsKeys.mode)
    }

    private func persistSettings() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: DefaultsKeys.settings)
    }

    private static func loadMode() -> TelemetryMode {
        guard
            let rawValue = UserDefaults.standard.string(forKey: DefaultsKeys.mode),
            let mode = TelemetryMode(rawValue: rawValue)
        else {
            return .live
        }

        return mode
    }

    private static func loadSettings() -> SettingsState {
        guard
            let data = UserDefaults.standard.data(forKey: DefaultsKeys.settings),
            let settings = try? JSONDecoder().decode(SettingsState.self, from: data)
        else {
            return SettingsState()
        }

        return settings
    }
}

private extension PulseDeckStore {
    enum DefaultsKeys {
        static let mode = "PulseDeck.mode"
        static let settings = "PulseDeck.settings"
    }

    enum BatteryBand {
        case unavailable
        case healthy
        case reserve
        case critical
    }

    enum FPSBand {
        case unknown
        case steady
        case strained
    }

    enum StorageBand {
        case comfortable
        case elevated
        case tight
    }
}
