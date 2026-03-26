import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: PulseDeckStore

    var body: some View {
        NavigationStack {
            ZStack {
                NeonGridBackground(glowIntensity: store.settings.glowIntensity)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        SectionLabel(
                            title: "Data Source",
                            subtitle: "Pick the feed, keep the labeling honest, and preserve the difference between public live signals and synthetic demo motion."
                        )

                        dataSourceCard

                        SectionLabel(
                            title: "Presentation",
                            subtitle: "Tune how much detail the dashboard shows during a demo without changing what the telemetry layer claims."
                        )

                        presentationCard

                        SectionLabel(
                            title: "Timeline",
                            subtitle: "Control density, filtering, and how much event metadata stays visible when you are narrating a session."
                        )

                        timelineCard

                        SectionLabel(
                            title: "Project Prep",
                            subtitle: "These reminders keep the Linux scaffold realistic and make the eventual macOS/Xcode handoff smoother."
                        )

                        projectPrepCard

                        SectionLabel(
                            title: "Scope Limits",
                            subtitle: "These are deliberate product guardrails so the concept stays App Store-safe."
                        )

                        scopeCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("Settings")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(PulsePalette.textPrimary)
                }
            }
        }
    }

    private var dataSourceCard: some View {
        NeonCard(accent: store.mode.accentColor, glowIntensity: store.settings.glowIntensity) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Current Feed")
                        .font(.headline)
                        .foregroundStyle(PulsePalette.textPrimary)
                    Spacer()
                    ModePill(mode: store.mode)
                }

                Picker("Mode", selection: Binding(get: { store.mode }, set: store.setMode)) {
                    ForEach(TelemetryMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(store.mode.detail)
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider().overlay(PulsePalette.divider)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Throughput disclosure")
                        .font(PulseFonts.micro)
                        .foregroundStyle(PulsePalette.textSecondary)
                    Text(store.throughputDisclosure)
                        .font(.subheadline)
                        .foregroundStyle(PulsePalette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var presentationCard: some View {
        NeonCard(accent: PulsePalette.cyan, glowIntensity: store.settings.glowIntensity) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Glow Intensity")
                            .foregroundStyle(PulsePalette.textPrimary)
                        Spacer()
                        Text("\(Int((store.settings.glowIntensity * 100).rounded()))%")
                            .font(PulseFonts.micro)
                            .foregroundStyle(PulsePalette.textSecondary)
                    }
                    Slider(value: glowBinding, in: 0.3...1.2)
                        .tint(PulsePalette.cyan)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Chart Window")
                            .foregroundStyle(PulsePalette.textPrimary)
                        Spacer()
                        Text("\(store.settings.historyWindow) samples")
                            .font(PulseFonts.micro)
                            .foregroundStyle(PulsePalette.textSecondary)
                    }

                    Stepper(value: historyBinding, in: 12...60, step: 6) {
                        Text("Adjust sparkline history")
                            .foregroundStyle(PulsePalette.textSecondary)
                    }
                }

                Toggle("Show capability badges", isOn: capabilityBadgeBinding)
                    .tint(PulsePalette.lime)

                Toggle("Show live/demo source badges", isOn: sourceBadgeBinding)
                    .tint(PulsePalette.cyan)

                Toggle("Show metric footnotes", isOn: footnoteBinding)
                    .tint(PulsePalette.amber)

                Toggle("Generate highlight/status events", isOn: highlightEventsBinding)
                    .tint(PulsePalette.violet)
            }
        }
    }

    private var timelineCard: some View {
        NeonCard(accent: PulsePalette.violet, glowIntensity: store.settings.glowIntensity) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Visible Event Limit")
                            .foregroundStyle(PulsePalette.textPrimary)
                        Spacer()
                        Text("\(store.settings.timelineLimit)")
                            .font(PulseFonts.micro)
                            .foregroundStyle(PulsePalette.textSecondary)
                    }

                    Stepper(value: timelineLimitBinding, in: 12...60, step: 6) {
                        Text("Cap timeline items shown in the app")
                            .foregroundStyle(PulsePalette.textSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Default Filter")
                        .foregroundStyle(PulsePalette.textPrimary)

                    Picker("Filter", selection: timelineFilterBinding) {
                        ForEach(TimelineFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(store.settings.timelineFilter.subtitle)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.textSecondary)
                }

                Toggle("Use dense timeline cards", isOn: denseTimelineBinding)
                    .tint(PulsePalette.violet)
            }
        }
    }

    private var projectPrepCard: some View {
        NeonCard(accent: PulsePalette.pink, glowIntensity: store.settings.glowIntensity) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Image(systemName: "macbook.and.iphone")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(PulsePalette.pink)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("macOS required for archive and IPA export")
                            .font(.headline)
                            .foregroundStyle(PulsePalette.textPrimary)
                        Text("This Linux workspace can shape the project, but it cannot produce a signed iOS archive or IPA. Use Xcode on macOS for signing, archiving, and export.")
                            .font(.subheadline)
                            .foregroundStyle(PulsePalette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Divider().overlay(PulsePalette.divider)

                Text("Helpful files")
                    .font(PulseFonts.micro)
                    .foregroundStyle(PulsePalette.textSecondary)

                VStack(alignment: .leading, spacing: 6) {
                    infoRow("README", "Project overview, limitations, and Xcode opening notes")
                    infoRow("docs/ipa-export-macos.md", "Step-by-step archive/export checklist for macOS")
                    infoRow("scripts/regenerate_xcode_project.sh", "Regenerate the Xcode project with XcodeGen on macOS")
                    infoRow("scripts/archive_ipa.sh", "Example archive/export wrapper for signed builds on macOS")
                }
            }
        }
    }

    private var scopeCard: some View {
        NeonCard(accent: PulsePalette.amber, glowIntensity: store.settings.glowIntensity) {
            VStack(alignment: .leading, spacing: 12) {
                limitRow("Allowed", "Battery level/state, thermal state, low power mode, orientation, motion, app FPS, storage capacity, and network path reachability.")
                limitRow("Estimated", "App resident footprint, pressure hints inferred from warnings, and demo-only throughput curves.")
                limitRow("Not Claimed", "CPU temperature, battery temperature, background app memory, total system CPU load, other apps’ FPS, or private diagnostics.")
            }
        }
    }

    private var glowBinding: Binding<Double> {
        Binding(
            get: { store.settings.glowIntensity },
            set: { newValue in
                store.updateSettings { settings in
                    settings.glowIntensity = newValue
                }
            }
        )
    }

    private var historyBinding: Binding<Int> {
        Binding(
            get: { store.settings.historyWindow },
            set: { newValue in
                store.updateSettings { settings in
                    settings.historyWindow = newValue
                }
            }
        )
    }

    private var capabilityBadgeBinding: Binding<Bool> {
        Binding(
            get: { store.settings.showCapabilityBadges },
            set: { newValue in
                store.updateSettings { settings in
                    settings.showCapabilityBadges = newValue
                }
            }
        )
    }

    private var sourceBadgeBinding: Binding<Bool> {
        Binding(
            get: { store.settings.showSourceBadges },
            set: { newValue in
                store.updateSettings { settings in
                    settings.showSourceBadges = newValue
                }
            }
        )
    }

    private var footnoteBinding: Binding<Bool> {
        Binding(
            get: { store.settings.showMetricFootnotes },
            set: { newValue in
                store.updateSettings { settings in
                    settings.showMetricFootnotes = newValue
                }
            }
        )
    }

    private var highlightEventsBinding: Binding<Bool> {
        Binding(
            get: { store.settings.highlightStatusChanges },
            set: { newValue in
                store.updateSettings { settings in
                    settings.highlightStatusChanges = newValue
                }
            }
        )
    }

    private var timelineLimitBinding: Binding<Int> {
        Binding(
            get: { store.settings.timelineLimit },
            set: { newValue in
                store.updateSettings { settings in
                    settings.timelineLimit = newValue
                }
            }
        )
    }

    private var timelineFilterBinding: Binding<TimelineFilter> {
        Binding(
            get: { store.settings.timelineFilter },
            set: { newValue in
                store.updateSettings { settings in
                    settings.timelineFilter = newValue
                }
            }
        )
    }

    private var denseTimelineBinding: Binding<Bool> {
        Binding(
            get: { store.settings.prefersDenseTimeline },
            set: { newValue in
                store.updateSettings { settings in
                    settings.prefersDenseTimeline = newValue
                }
            }
        )
    }

    private func limitRow(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(PulseFonts.micro)
                .foregroundStyle(PulsePalette.textSecondary)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(PulsePalette.textPrimary)
        }
    }

    private func infoRow(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PulsePalette.textPrimary)
            Text(body)
                .font(.footnote)
                .foregroundStyle(PulsePalette.textSecondary)
        }
    }
}
