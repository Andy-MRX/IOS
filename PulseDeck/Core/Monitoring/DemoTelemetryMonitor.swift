import Foundation

struct DemoTelemetryMonitor {
    private let sessionStart = Date()

    func snapshot(at date: Date) -> TelemetrySnapshot {
        let time = date.timeIntervalSince(sessionStart)
        let batteryLevel = clamp(0.84 - (time / 7_500) + (sin(time / 36) * 0.05), min: 0.16, max: 0.94)
        let storageUsed = clamp(0.62 + (sin(time / 58) * 0.07), min: 0.38, max: 0.86)
        let footprintMB = clamp(184 + (sin(time / 5) * 30) + (cos(time / 13) * 15), min: 128, max: 448)
        let fpsDip = max(0, sin(time / 11) * 11) + max(0, cos(time / 23) * 5)
        let fps = clamp(59 + (sin(time / 4) * 4.6) - fpsDip, min: 34, max: 61)
        let throughputPulse = max(0, sin(time / 14) * 110)
        let downlink = clamp(146 + (sin(time / 6) * 52) + (cos(time / 21) * 26) - throughputPulse, min: 8, max: 310)
        let uplink = clamp(34 + (sin(time / 9) * 13) - max(0, cos(time / 17) * 8), min: 4, max: 76)
        let tilt = abs(sin(time / 2.8)) * 0.92
        let thermalIndex = Int(((sin(time / 75) + 1) * 1.6).rounded())
        let thermalState = ["Nominal", "Fair", "Serious", "Critical"][min(max(thermalIndex, 0), 3)]
        let warningCount = Int(max(0, (sin(time / 33) + 1.1) * 0.9).rounded(.down))
        let interface = downlink < 25 ? "Cellular" : "Wi-Fi"
        let pathState: NetworkPathState = {
            if downlink < 18 {
                return .offline
            }
            if downlink < 58 {
                return .constrained
            }
            return .online
        }()

        return TelemetrySnapshot(
            timestamp: date,
            battery: BatterySnapshot(
                level: Float(batteryLevel),
                stateDescription: batteryLevel < 0.32 ? "On Battery" : "Charging",
                isLowPowerModeEnabled: batteryLevel < 0.28,
                tier: .real
            ),
            thermal: ThermalSnapshot(stateDescription: thermalState, tier: .real),
            storage: StorageSnapshot(
                totalBytes: 256 * 1_024 * 1_024 * 1_024,
                availableBytes: Int64((1 - storageUsed) * Double(256 * 1_024 * 1_024 * 1_024)),
                tier: .real
            ),
            memory: MemorySnapshot(
                residentFootprintBytes: UInt64(footprintMB * 1_024 * 1_024),
                warningCount: warningCount,
                lastWarningAt: warningCount > 0 ? date.addingTimeInterval(-44) : nil,
                indicatorDescription: warningCount > 0 ? "Demo pressure pulse detected" : "Demo session looks healthy",
                tier: .hybrid
            ),
            fps: FPSSnapshot(framesPerSecond: fps, tier: .estimated),
            network: NetworkSnapshot(
                pathState: pathState,
                interfaceDescription: interface,
                estimatedDownlinkMbps: downlink,
                estimatedUplinkMbps: uplink,
                tier: .real,
                throughputTier: .estimated
            ),
            motion: MotionSnapshot(
                orientationDescription: abs(sin(time / 18)) > 0.55 ? "Landscape Right" : "Portrait",
                tiltMagnitude: tilt,
                isTracking: true,
                tier: .real
            ),
            device: DeviceSnapshot(
                name: "Demo iPhone",
                model: "iPhone",
                identifier: "SIM-DEMO-01",
                systemVersion: "iOS demo seed",
                processorCount: 6,
                physicalMemoryBytes: 8 * 1_024 * 1_024 * 1_024,
                isSimulator: true,
                tier: .real
            )
        )
    }

    private func clamp(_ value: Double, min lowerBound: Double, max upperBound: Double) -> Double {
        Swift.max(lowerBound, Swift.min(value, upperBound))
    }
}
