import Foundation
import SwiftUI

enum CapabilityTier: String, CaseIterable, Codable, Identifiable {
    case real = "Real"
    case estimated = "Estimated"
    case placeholder = "Placeholder"
    case hybrid = "Mixed"

    var id: String { rawValue }

    var detail: String {
        switch self {
        case .real:
            return "Directly observable with public iOS APIs."
        case .estimated:
            return "Derived from app-visible signals or approximated from safe APIs."
        case .placeholder:
            return "UI and architecture ready, but no live signal is collected yet."
        case .hybrid:
            return "Combines direct signals with estimated or placeholder context."
        }
    }
}

enum TelemetryMode: String, CaseIterable, Identifiable, Codable {
    case live = "Live"
    case demo = "Demo"

    var id: String { rawValue }

    var shortLabel: String {
        rawValue.uppercased()
    }

    var bannerTitle: String {
        switch self {
        case .live:
            return "Live device feed"
        case .demo:
            return "Demo simulation feed"
        }
    }

    var subtitle: String {
        switch self {
        case .live:
            return "Public iOS signals only"
        case .demo:
            return "Seeded motion and throughput visuals"
        }
    }

    var detail: String {
        switch self {
        case .live:
            return "PulseDeck reads only the signals an App Store-safe iOS app can actually observe on-device."
        case .demo:
            return "Charts, alerts, and throughput swings are synthetic so the demo remains visually rich without overclaiming live access."
        }
    }

    var iconName: String {
        switch self {
        case .live:
            return "dot.radiowaves.left.and.right"
        case .demo:
            return "sparkles.rectangle.stack"
        }
    }
}

enum EventOrigin: String, CaseIterable, Codable, Identifiable {
    case system = "System"
    case inferred = "Inferred"
    case demo = "Demo"
    case app = "App"

    var id: String { rawValue }

    var detail: String {
        switch self {
        case .system:
            return "Direct notification or runtime status emitted by iOS frameworks."
        case .inferred:
            return "Derived from trend thresholds inside the app."
        case .demo:
            return "Generated from the synthetic demo feed."
        case .app:
            return "PulseDeck UI or session lifecycle event."
        }
    }
}

enum TimelineFilter: String, CaseIterable, Identifiable, Codable {
    case all = "All"
    case alerts = "Alerts"
    case system = "System"
    case source = "Source"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .all:
            return "Every captured event"
        case .alerts:
            return "Battery, thermal, memory, and network shifts"
        case .system:
            return "Device and framework notifications"
        case .source:
            return "Feed switches and PulseDeck-generated notes"
        }
    }

    func matches(_ event: SessionEvent) -> Bool {
        switch self {
        case .all:
            return true
        case .alerts:
            return event.isAlert
        case .system:
            return event.origin == .system
        case .source:
            return event.origin == .app || event.origin == .demo || event.origin == .inferred || event.kind == .mode || event.kind == .info
        }
    }
}

struct SettingsState: Equatable, Codable {
    var glowIntensity = 0.92
    var historyWindow = 24
    var showCapabilityBadges = true
    var showSourceBadges = true
    var showMetricFootnotes = true
    var highlightStatusChanges = true
    var prefersDenseTimeline = false
    var timelineFilter: TimelineFilter = .all
    var timelineLimit = 30
}

struct MetricPoint: Identifiable, Hashable {
    let id = UUID()
    let timestamp: Date
    let value: Double
}

enum SessionEventKind: String, Codable {
    case lifecycle
    case battery
    case thermal
    case network
    case memory
    case motion
    case mode
    case info

    var iconName: String {
        switch self {
        case .lifecycle:
            return "app.badge"
        case .battery:
            return "battery.75"
        case .thermal:
            return "thermometer.medium"
        case .network:
            return "antenna.radiowaves.left.and.right"
        case .memory:
            return "memorychip"
        case .motion:
            return "gyroscope"
        case .mode:
            return "switch.2"
        case .info:
            return "waveform.path.ecg"
        }
    }
}

struct SessionEvent: Identifiable, Hashable {
    let id = UUID()
    let timestamp: Date
    let kind: SessionEventKind
    let title: String
    let detail: String
    let tier: CapabilityTier
    let origin: EventOrigin
    let mode: TelemetryMode

    var isAlert: Bool {
        switch kind {
        case .battery, .thermal, .network, .memory:
            return true
        case .lifecycle, .motion, .mode, .info:
            return false
        }
    }
}

struct DashboardHighlight: Identifiable, Hashable {
    let id = UUID()
    let symbol: String
    let title: String
    let value: String
    let detail: String
    let tier: CapabilityTier
}

struct BatterySnapshot: Hashable {
    var level: Float?
    var stateDescription: String
    var isLowPowerModeEnabled: Bool
    var tier: CapabilityTier
}

struct ThermalSnapshot: Hashable {
    var stateDescription: String
    var tier: CapabilityTier
}

struct StorageSnapshot: Hashable {
    var totalBytes: Int64?
    var availableBytes: Int64?
    var tier: CapabilityTier

    var usedFraction: Double? {
        guard let totalBytes, let availableBytes, totalBytes > 0 else {
            return nil
        }
        return Double(totalBytes - availableBytes) / Double(totalBytes)
    }
}

struct MemorySnapshot: Hashable {
    var residentFootprintBytes: UInt64?
    var warningCount: Int
    var lastWarningAt: Date?
    var indicatorDescription: String
    var tier: CapabilityTier
}

struct FPSSnapshot: Hashable {
    var framesPerSecond: Double?
    var tier: CapabilityTier
}

enum NetworkPathState: String, Hashable {
    case online
    case constrained
    case offline
}

struct NetworkSnapshot: Hashable {
    var pathState: NetworkPathState
    var interfaceDescription: String
    var estimatedDownlinkMbps: Double?
    var estimatedUplinkMbps: Double?
    var tier: CapabilityTier
    var throughputTier: CapabilityTier
}

struct MotionSnapshot: Hashable {
    var orientationDescription: String
    var tiltMagnitude: Double?
    var isTracking: Bool
    var tier: CapabilityTier
}

struct DeviceSnapshot: Hashable {
    var name: String
    var model: String
    var identifier: String
    var systemVersion: String
    var processorCount: Int
    var physicalMemoryBytes: UInt64
    var isSimulator: Bool
    var tier: CapabilityTier
}

struct TelemetrySnapshot: Hashable {
    var timestamp: Date
    var battery: BatterySnapshot
    var thermal: ThermalSnapshot
    var storage: StorageSnapshot
    var memory: MemorySnapshot
    var fps: FPSSnapshot
    var network: NetworkSnapshot
    var motion: MotionSnapshot
    var device: DeviceSnapshot

    static let empty = TelemetrySnapshot(
        timestamp: .now,
        battery: BatterySnapshot(
            level: nil,
            stateDescription: "Unavailable",
            isLowPowerModeEnabled: false,
            tier: .real
        ),
        thermal: ThermalSnapshot(stateDescription: "Unavailable", tier: .real),
        storage: StorageSnapshot(totalBytes: nil, availableBytes: nil, tier: .real),
        memory: MemorySnapshot(
            residentFootprintBytes: nil,
            warningCount: 0,
            lastWarningAt: nil,
            indicatorDescription: "No warnings yet",
            tier: .hybrid
        ),
        fps: FPSSnapshot(framesPerSecond: nil, tier: .estimated),
        network: NetworkSnapshot(
            pathState: .offline,
            interfaceDescription: "Unknown",
            estimatedDownlinkMbps: nil,
            estimatedUplinkMbps: nil,
            tier: .real,
            throughputTier: .placeholder
        ),
        motion: MotionSnapshot(
            orientationDescription: "Unknown",
            tiltMagnitude: nil,
            isTracking: false,
            tier: .real
        ),
        device: DeviceSnapshot(
            name: "iPhone",
            model: "Unknown",
            identifier: "Unknown",
            systemVersion: "iOS",
            processorCount: 0,
            physicalMemoryBytes: 0,
            isSimulator: false,
            tier: .real
        )
    )
}

extension Array where Element == MetricPoint {
    var numericValues: [Double] {
        map(\.value)
    }
}
