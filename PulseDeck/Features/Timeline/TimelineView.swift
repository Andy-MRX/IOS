import SwiftUI

struct TimelineView: View {
    @ObservedObject var store: PulseDeckStore

    var body: some View {
        NavigationStack {
            ZStack {
                NeonGridBackground(glowIntensity: store.settings.glowIntensity)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        SectionLabel(
                            title: "Session Timeline",
                            subtitle: "A rolling event feed with explicit source labels so direct iOS notifications, inferred shifts, and demo-generated notes stay easy to separate."
                        )

                        sourceCard

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(store.timelineHighlights) { highlight in
                                    DashboardHighlightTile(
                                        highlight: highlight,
                                        glowIntensity: store.settings.glowIntensity
                                    )
                                }
                            }
                            .padding(.vertical, 2)
                        }

                        filterCard
                        legendCard

                        if store.filteredTimeline.isEmpty {
                            emptyStateCard
                        } else {
                            LazyVStack(spacing: store.settings.prefersDenseTimeline ? 8 : 12) {
                                ForEach(store.filteredTimeline) { event in
                                    TimelineChip(
                                        event: event,
                                        showCapabilityBadge: store.settings.showCapabilityBadges,
                                        showSourceBadges: store.settings.showSourceBadges,
                                        dense: store.settings.prefersDenseTimeline
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("Timeline")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(PulsePalette.textPrimary)
                }
            }
        }
    }

    private var sourceCard: some View {
        NeonCard(accent: store.mode.accentColor, glowIntensity: store.settings.glowIntensity) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Event Integrity")
                        .font(.headline)
                        .foregroundStyle(PulsePalette.textPrimary)
                    Spacer()
                    ModePill(mode: store.mode)
                }

                Text(store.mode == .live
                    ? "While live mode is armed, system notifications come from public iOS APIs and inferred entries are generated only from visible trend changes."
                    : "While demo mode is armed, timeline updates come from the seeded synthetic feed so the UI can demonstrate transitions without pretending to read hidden system diagnostics."
                )
                .font(.subheadline)
                .foregroundStyle(PulsePalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    MetricTag(text: store.lastUpdatedText, accent: PulsePalette.textSecondary)
                    MetricTag(text: "\(store.sampleCount) samples", accent: store.mode.accentColor)
                }
            }
        }
    }

    private var filterCard: some View {
        NeonCard(accent: PulsePalette.cyan, glowIntensity: store.settings.glowIntensity) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Filter")
                    .font(.headline)
                    .foregroundStyle(PulsePalette.textPrimary)

                Picker(
                    "Timeline Filter",
                    selection: Binding(
                        get: { store.settings.timelineFilter },
                        set: { newValue in
                            store.updateSettings { settings in
                                settings.timelineFilter = newValue
                            }
                        }
                    )
                ) {
                    ForEach(TimelineFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)

                Text(store.settings.timelineFilter.subtitle)
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.textSecondary)
            }
        }
    }

    private var legendCard: some View {
        NeonCard(accent: PulsePalette.violet, glowIntensity: store.settings.glowIntensity) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Legend")
                    .font(.headline)
                    .foregroundStyle(PulsePalette.textPrimary)

                ForEach(CapabilityTier.allCases) { tier in
                    HStack(alignment: .top, spacing: 12) {
                        CapabilityPill(tier: tier)
                        Text(tier.detail)
                            .font(.subheadline)
                            .foregroundStyle(PulsePalette.textSecondary)
                    }
                }

                Divider().overlay(PulsePalette.divider)

                ForEach(EventOrigin.allCases) { origin in
                    HStack(alignment: .top, spacing: 12) {
                        OriginPill(origin: origin)
                        Text(origin.detail)
                            .font(.subheadline)
                            .foregroundStyle(PulsePalette.textSecondary)
                    }
                }
            }
        }
    }

    private var emptyStateCard: some View {
        NeonCard(accent: PulsePalette.amber, glowIntensity: store.settings.glowIntensity) {
            VStack(alignment: .leading, spacing: 10) {
                Text("No events match this filter yet")
                    .font(.headline)
                    .foregroundStyle(PulsePalette.textPrimary)
                Text("Switch the filter or keep the session running. Demo mode will synthesize additional transitions if you need a more active feed during a presentation.")
                    .font(.subheadline)
                    .foregroundStyle(PulsePalette.textSecondary)
            }
        }
    }
}
