import SwiftUI

struct DashboardView: View {
    @ObservedObject var store: PulseDeckStore

    private let columns = [
        GridItem(.adaptive(minimum: 166), spacing: 16, alignment: .top)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                NeonGridBackground(glowIntensity: store.settings.glowIntensity)

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        heroCard

                        SectionLabel(
                            title: "Deck Highlights",
                            subtitle: "Short-form status tiles keep the demo readable before you dive into the full signal grid."
                        )

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(store.dashboardHighlights) { highlight in
                                    DashboardHighlightTile(
                                        highlight: highlight,
                                        glowIntensity: store.settings.glowIntensity
                                    )
                                }
                            }
                            .padding(.vertical, 2)
                        }

                        SectionLabel(
                            title: "Watchlist",
                            subtitle: "Active pressure points stay visible here so a demo operator can narrate what matters first."
                        )

                        watchlistCard

                        SectionLabel(
                            title: "Signal Deck",
                            subtitle: "Each card shows both capability confidence and the current feed source so live and demo behavior never blur together."
                        )

                        LazyVGrid(columns: columns, spacing: 16) {
                            batteryCard
                            thermalCard
                            fpsCard
                            networkCard
                            storageCard
                            memoryCard
                            motionCard
                            deviceCard
                        }

                        SectionLabel(
                            title: "Timeline Pulse",
                            subtitle: "Recent event previews combine framework notifications, inferred transitions, and explicit feed changes."
                        )

                        VStack(spacing: store.settings.prefersDenseTimeline ? 8 : 12) {
                            ForEach(store.timeline.prefix(store.settings.prefersDenseTimeline ? 5 : 3)) { event in
                                TimelineChip(
                                    event: event,
                                    showCapabilityBadge: store.settings.showCapabilityBadges,
                                    showSourceBadges: store.settings.showSourceBadges,
                                    dense: store.settings.prefersDenseTimeline
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PulseDeck")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(PulsePalette.textPrimary)
                        Text(store.heroStatusLine)
                            .font(PulseFonts.micro)
                            .foregroundStyle(PulsePalette.textSecondary)
                    }
                }
            }
        }
    }

    private var heroCard: some View {
        NeonCard(accent: store.mode.accentColor, glowIntensity: store.settings.glowIntensity) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("PULSEDECK")
                            .font(PulseFonts.micro)
                            .foregroundStyle(store.mode.accentColor)
                        Text("Realtime iPhone performance deck")
                            .font(PulseFonts.hero)
                            .foregroundStyle(PulsePalette.textPrimary)
                        Text("A polished demo shell for the signals iOS apps can legitimately observe, estimate, or reserve as future placeholders.")
                            .font(.subheadline)
                            .foregroundStyle(PulsePalette.textSecondary)
                    }

                    Spacer(minLength: 16)

                    VStack(alignment: .trailing, spacing: 8) {
                        ModePill(mode: store.mode)
                        if store.settings.showCapabilityBadges {
                            CapabilityPill(tier: store.mode == .live ? .hybrid : .estimated)
                        }
                        Text(store.lastUpdatedText)
                            .font(PulseFonts.micro)
                            .foregroundStyle(PulsePalette.textSecondary)
                        Text(store.uptimeText)
                            .font(.title3.monospacedDigit().weight(.semibold))
                            .foregroundStyle(PulsePalette.textPrimary)
                    }
                }

                Picker("Source", selection: Binding(get: { store.mode }, set: store.setMode)) {
                    ForEach(TelemetryMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        MetricTag(text: store.mode.bannerTitle, accent: store.mode.accentColor)
                        MetricTag(text: store.mode.subtitle, accent: PulsePalette.textSecondary)
                    }

                    Text(store.modeDisclosure)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(PulsePalette.panelHighlight.opacity(0.72))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(store.mode.accentColor.opacity(0.25), lineWidth: 0.8)
                        )
                )

                HStack(spacing: 12) {
                    heroStat(title: "Battery", value: PulseFormatters.battery(store.snapshot.battery.level))
                    heroStat(title: "Thermal", value: store.snapshot.thermal.stateDescription)
                    heroStat(title: "Path", value: store.snapshot.network.pathState.rawValue.capitalized)
                }

                SparklineView(
                    points: store.trimmedValues(from: store.fpsHistory),
                    colors: [store.mode.accentColor, PulsePalette.violet]
                )

                Text(store.throughputDisclosure)
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var watchlistCard: some View {
        NeonCard(
            accent: store.activeAlertHighlights.first?.tier.accentColor ?? PulsePalette.lime,
            glowIntensity: store.settings.glowIntensity
        ) {
            VStack(alignment: .leading, spacing: 14) {
                if store.activeAlertHighlights.isEmpty {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.title3)
                            .foregroundStyle(PulsePalette.lime)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Signals steady")
                                .font(.headline)
                                .foregroundStyle(PulsePalette.textPrimary)
                            Text("No active battery, thermal, memory, storage, render, or reachability flags are tripped on the latest sample window.")
                                .font(.subheadline)
                                .foregroundStyle(PulsePalette.textSecondary)
                        }
                    }
                } else {
                    ForEach(store.activeAlertHighlights) { alert in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: alert.symbol)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(alert.tier.accentColor)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(alert.title)
                                        .font(.headline)
                                        .foregroundStyle(PulsePalette.textPrimary)
                                    Spacer()
                                    CapabilityPill(tier: alert.tier)
                                }

                                Text(alert.value)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(alert.tier.accentColor)

                                Text(alert.detail)
                                    .font(.footnote)
                                    .foregroundStyle(PulsePalette.textSecondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func heroStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(PulseFonts.micro)
                .foregroundStyle(PulsePalette.textSecondary)
            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(PulsePalette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(PulsePalette.cyan.opacity(0.16), lineWidth: 0.8)
                )
        )
    }

    private var batteryCard: some View {
        DashboardMetricCard(
            title: "Battery",
            tier: store.snapshot.battery.tier,
            mode: store.mode,
            primaryText: PulseFormatters.battery(store.snapshot.battery.level),
            secondaryText: store.snapshot.battery.stateDescription + (store.snapshot.battery.isLowPowerModeEnabled ? " • Low Power" : ""),
            statusText: store.snapshot.battery.level == nil ? "Waiting for hardware battery" : "Direct UIDevice battery signal",
            deltaText: PulseFormatters.delta(
                current: store.batteryHistory.last?.value.map { $0 * 100 },
                previous: store.previousValue(in: store.batteryHistory).map { $0 * 100 },
                suffix: "%"
            ),
            caption: "Direct UIDevice battery state and level. Simulator often returns unavailable battery values.",
            trend: store.trimmedValues(from: store.batteryHistory),
            accent: PulsePalette.cyan,
            glowIntensity: store.settings.glowIntensity,
            showCapabilityBadge: store.settings.showCapabilityBadges,
            showSourceBadge: store.settings.showSourceBadges,
            showFootnote: store.settings.showMetricFootnotes,
            footerTags: [
                store.snapshot.battery.isLowPowerModeEnabled ? "Low Power Mode" : "Power normal",
                "Updated now",
                "UIDevice"
            ]
        )
    }

    private var thermalCard: some View {
        DashboardMetricCard(
            title: "Thermal",
            tier: store.snapshot.thermal.tier,
            mode: store.mode,
            primaryText: store.snapshot.thermal.stateDescription,
            secondaryText: store.snapshot.battery.isLowPowerModeEnabled ? "Low Power Mode enabled" : "Power mode normal",
            statusText: "Coarse thermal tier only",
            deltaText: thermalDeltaText,
            caption: "Thermal state is public through ProcessInfo. It is coarse, not a CPU or battery temperature readout.",
            trend: store.trimmedValues(from: store.thermalHistory),
            accent: PulsePalette.amber,
            glowIntensity: store.settings.glowIntensity,
            showCapabilityBadge: store.settings.showCapabilityBadges,
            showSourceBadge: store.settings.showSourceBadges,
            showFootnote: store.settings.showMetricFootnotes,
            footerTags: [
                "ProcessInfo",
                "No temperature sensor"
            ]
        )
    }

    private var fpsCard: some View {
        DashboardMetricCard(
            title: "App FPS",
            tier: store.snapshot.fps.tier,
            mode: store.mode,
            primaryText: PulseFormatters.fps(store.snapshot.fps.framesPerSecond),
            secondaryText: "DisplayLink sampled render cadence",
            statusText: store.snapshot.fps.framesPerSecond.map { $0 < 50 ? "Cadence softened" : "Cadence healthy" } ?? "Collecting cadence",
            deltaText: PulseFormatters.delta(
                current: store.fpsHistory.last?.value,
                previous: store.previousValue(in: store.fpsHistory),
                suffix: " fps"
            ),
            caption: "Estimated from the app’s own CADisplayLink, so it reflects in-app rendering only.",
            trend: store.trimmedValues(from: store.fpsHistory),
            accent: PulsePalette.lime,
            glowIntensity: store.settings.glowIntensity,
            showCapabilityBadge: store.settings.showCapabilityBadges,
            showSourceBadge: store.settings.showSourceBadges,
            showFootnote: store.settings.showMetricFootnotes,
            footerTags: [
                "App-only estimate",
                "CADisplayLink"
            ]
        )
    }

    private var networkCard: some View {
        let throughputText = store.mode == .demo
            ? PulseFormatters.throughput(store.snapshot.network.estimatedDownlinkMbps)
            : "Throughput pending"

        return DashboardMetricCard(
            title: "Network",
            tier: store.mode == .live ? .hybrid : .estimated,
            mode: store.mode,
            primaryText: store.snapshot.network.pathState.rawValue.capitalized,
            secondaryText: "\(store.snapshot.network.interfaceDescription) • \(throughputText)",
            statusText: store.mode == .live ? "Reachability real, Mbps placeholder" : "Synthetic throughput active",
            deltaText: store.mode == .demo
                ? PulseFormatters.delta(
                    current: store.snapshot.network.estimatedDownlinkMbps,
                    previous: store.previousValue(in: store.networkHistory),
                    suffix: " Mbps",
                    decimals: 1
                )
                : "Path-backed only",
            caption: "Reachability is real via `NWPathMonitor`. Mbps stays placeholder in live mode until an explicit opt-in test is implemented.",
            trend: store.trimmedValues(from: store.networkHistory),
            accent: PulsePalette.pink,
            glowIntensity: store.settings.glowIntensity,
            showCapabilityBadge: store.settings.showCapabilityBadges,
            showSourceBadge: store.settings.showSourceBadges,
            showFootnote: store.settings.showMetricFootnotes,
            footerTags: [
                store.snapshot.network.interfaceDescription,
                store.mode == .live ? "No silent speed scraping" : "Demo Mbps"
            ]
        )
    }

    private var storageCard: some View {
        DashboardMetricCard(
            title: "Storage",
            tier: store.snapshot.storage.tier,
            mode: store.mode,
            primaryText: PulseFormatters.percentage(store.snapshot.storage.usedFraction),
            secondaryText: "\(PulseFormatters.bytes(store.snapshot.storage.availableBytes)) free",
            statusText: "App-visible volume capacity",
            deltaText: PulseFormatters.delta(
                current: store.storageHistory.last?.value.map { $0 * 100 },
                previous: store.previousValue(in: store.storageHistory).map { $0 * 100 },
                suffix: "%"
            ),
            caption: "Volume capacity comes from the app-visible filesystem container and represents device storage broadly, not per-app cache accounting.",
            trend: store.trimmedValues(from: store.storageHistory),
            accent: PulsePalette.violet,
            glowIntensity: store.settings.glowIntensity,
            showCapabilityBadge: store.settings.showCapabilityBadges,
            showSourceBadge: store.settings.showSourceBadges,
            showFootnote: store.settings.showMetricFootnotes,
            footerTags: [
                PulseFormatters.bytes(store.snapshot.storage.totalBytes),
                "Filesystem APIs"
            ]
        )
    }

    private var memoryCard: some View {
        DashboardMetricCard(
            title: "Memory",
            tier: store.snapshot.memory.tier,
            mode: store.mode,
            primaryText: PulseFormatters.bytes(store.snapshot.memory.residentFootprintBytes),
            secondaryText: "\(store.snapshot.memory.warningCount) warnings • \(store.snapshot.memory.indicatorDescription)",
            statusText: "App-only footprint estimate",
            deltaText: PulseFormatters.delta(
                current: store.memoryHistory.last?.value,
                previous: store.previousValue(in: store.memoryHistory),
                suffix: " MB"
            ),
            caption: "Memory warnings are real. Resident footprint is an app-only footprint estimate, not whole-device RAM pressure.",
            trend: store.trimmedValues(from: store.memoryHistory),
            accent: PulsePalette.amber,
            glowIntensity: store.settings.glowIntensity,
            showCapabilityBadge: store.settings.showCapabilityBadges,
            showSourceBadge: store.settings.showSourceBadges,
            showFootnote: store.settings.showMetricFootnotes,
            footerTags: [
                "Warnings real",
                "Process footprint"
            ]
        )
    }

    private var motionCard: some View {
        DashboardMetricCard(
            title: "Motion",
            tier: store.snapshot.motion.tier,
            mode: store.mode,
            primaryText: store.snapshot.motion.orientationDescription,
            secondaryText: store.snapshot.motion.isTracking
                ? "Tilt \(PulseFormatters.tilt(store.snapshot.motion.tiltMagnitude))"
                : "Core Motion unavailable",
            statusText: store.snapshot.motion.isTracking ? "Orientation + tilt tracking" : "Motion unavailable",
            deltaText: PulseFormatters.delta(
                current: store.motionHistory.last?.value,
                previous: store.previousValue(in: store.motionHistory),
                suffix: " g",
                decimals: 2
            ),
            caption: "Orientation and device-motion cues are public. They say nothing about CPU or background system activity.",
            trend: store.trimmedValues(from: store.motionHistory),
            accent: PulsePalette.cyan,
            glowIntensity: store.settings.glowIntensity,
            showCapabilityBadge: store.settings.showCapabilityBadges,
            showSourceBadge: store.settings.showSourceBadges,
            showFootnote: store.settings.showMetricFootnotes,
            footerTags: [
                store.snapshot.motion.isTracking ? "Core Motion" : "Tracking off",
                store.snapshot.motion.orientationDescription
            ]
        )
    }

    private var deviceCard: some View {
        DashboardMetricCard(
            title: "Device",
            tier: store.snapshot.device.tier,
            mode: store.mode,
            primaryText: store.snapshot.device.identifier,
            secondaryText: "\(store.snapshot.device.systemVersion) • \(PulseFormatters.bytes(store.snapshot.device.physicalMemoryBytes)) RAM",
            statusText: "Static public hardware facts",
            deltaText: store.snapshot.device.isSimulator ? "Simulator context" : "Physical device",
            caption: "Hardware identifier, OS version, core count, and physical memory are public device facts, not live performance scores.",
            trend: store.trimmedValues(from: store.batteryHistory),
            accent: PulsePalette.violet,
            glowIntensity: store.settings.glowIntensity,
            showCapabilityBadge: store.settings.showCapabilityBadges,
            showSourceBadge: store.settings.showSourceBadges,
            showFootnote: store.settings.showMetricFootnotes,
            footerTags: [
                "\(store.snapshot.device.processorCount) cores",
                store.snapshot.device.model
            ]
        )
    }

    private var thermalDeltaText: String {
        let current = store.snapshot.thermal.stateDescription
        let previousValue = store.previousValue(in: store.thermalHistory)
        let currentValue = store.thermalHistory.last?.value

        if previousValue == nil || currentValue == nil {
            return "Fresh sample"
        }

        if current == "Serious" || current == "Critical" {
            return "Escalated"
        }

        return current == "Nominal" ? "Cooler" : "Stable"
    }
}
