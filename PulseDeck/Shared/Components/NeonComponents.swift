import SwiftUI

struct NeonGridBackground: View {
    let glowIntensity: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                PulsePalette.backgroundGradient
                    .ignoresSafeArea()

                PulsePalette.heroGradient
                    .blur(radius: 120)
                    .scaleEffect(1.35)
                    .opacity(0.55 * glowIntensity)

                Circle()
                    .fill(PulsePalette.cyan.opacity(0.12 * glowIntensity))
                    .frame(width: geometry.size.width * 0.7)
                    .blur(radius: 90)
                    .offset(x: geometry.size.width * 0.22, y: -geometry.size.height * 0.28)

                Circle()
                    .fill(PulsePalette.pink.opacity(0.12 * glowIntensity))
                    .frame(width: geometry.size.width * 0.6)
                    .blur(radius: 110)
                    .offset(x: -geometry.size.width * 0.24, y: geometry.size.height * 0.32)

                Canvas { context, size in
                    let spacing: CGFloat = 26
                    var path = Path()

                    stride(from: 0, through: size.width, by: spacing).forEach { x in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    }

                    stride(from: 0, through: size.height, by: spacing).forEach { y in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }

                    context.stroke(
                        path,
                        with: .color(PulsePalette.cyan.opacity(0.08 * glowIntensity)),
                        lineWidth: 0.8
                    )
                }
                .blendMode(.screen)
            }
        }
    }
}

struct NeonCard<Content: View>: View {
    let accent: Color
    let glowIntensity: Double
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [PulsePalette.panel.opacity(0.94), PulsePalette.panelSecondary.opacity(0.90)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.18), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .mask(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                        )
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(accent.opacity(0.35), lineWidth: 1.0)
                )
                .shadow(color: accent.opacity(0.24 * glowIntensity), radius: 26, x: 0, y: 12)
                .shadow(color: Color.black.opacity(0.22), radius: 20, x: 0, y: 16)

            content
                .padding(20)
        }
    }
}

struct CapabilityPill: View {
    let tier: CapabilityTier

    var body: some View {
        Text(tier.rawValue.uppercased())
            .font(PulseFonts.micro)
            .foregroundStyle(tier.accentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(tier.accentColor.opacity(0.12))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(tier.accentColor.opacity(0.35), lineWidth: 0.8)
            )
    }
}

struct ModePill: View {
    let mode: TelemetryMode

    var body: some View {
        Label(mode.shortLabel, systemImage: mode.iconName)
            .font(PulseFonts.micro)
            .foregroundStyle(mode.accentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(mode.accentColor.opacity(0.12))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(mode.accentColor.opacity(0.35), lineWidth: 0.8)
            )
    }
}

struct OriginPill: View {
    let origin: EventOrigin

    var body: some View {
        Text(origin.rawValue.uppercased())
            .font(PulseFonts.micro)
            .foregroundStyle(origin.accentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(origin.accentColor.opacity(0.12))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(origin.accentColor.opacity(0.35), lineWidth: 0.8)
            )
    }
}

struct MetricTag: View {
    let text: String
    let accent: Color

    var body: some View {
        Text(text)
            .font(PulseFonts.micro)
            .foregroundStyle(accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(accent.opacity(0.10))
            )
    }
}

struct SectionLabel: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(PulseFonts.section)
                .foregroundStyle(PulsePalette.textPrimary)
            Text(subtitle)
                .font(.footnote.weight(.medium))
                .foregroundStyle(PulsePalette.textSecondary)
        }
    }
}

struct SparklineView: View {
    let points: [Double]
    let colors: [Color]

    var body: some View {
        GeometryReader { geometry in
            let normalized = normalizedPoints(in: geometry.size)

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.03))

                if normalized.count > 1 {
                    Path { path in
                        path.move(to: normalized[0])
                        normalized.dropFirst().forEach { path.addLine(to: $0) }
                    }
                    .stroke(
                        LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )

                    Path { path in
                        path.move(to: CGPoint(x: normalized[0].x, y: geometry.size.height))
                        normalized.forEach { path.addLine(to: $0) }
                        path.addLine(to: CGPoint(x: normalized.last?.x ?? 0, y: geometry.size.height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [colors.first?.opacity(0.26) ?? .clear, .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    if let last = normalized.last {
                        Circle()
                            .fill(colors.first ?? PulsePalette.cyan)
                            .frame(width: 9, height: 9)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.6), lineWidth: 1)
                            )
                            .position(last)
                            .shadow(color: (colors.first ?? PulsePalette.cyan).opacity(0.55), radius: 10)
                    }
                }
            }
        }
        .frame(height: 72)
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard points.count > 1 else { return [] }
        let minValue = points.min() ?? 0
        let maxValue = points.max() ?? 1
        let span = max(maxValue - minValue, 0.0001)

        return points.enumerated().map { index, value in
            let x = size.width * CGFloat(Double(index) / Double(points.count - 1))
            let normalizedY = (value - minValue) / span
            let y = size.height - (CGFloat(normalizedY) * size.height)
            return CGPoint(x: x, y: y)
        }
    }
}

struct DashboardHighlightTile: View {
    let highlight: DashboardHighlight
    let glowIntensity: Double

    var body: some View {
        NeonCard(accent: highlight.tier.accentColor, glowIntensity: glowIntensity) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: highlight.symbol)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(highlight.tier.accentColor)
                    Spacer()
                    CapabilityPill(tier: highlight.tier)
                }

                Text(highlight.title.uppercased())
                    .font(PulseFonts.micro)
                    .foregroundStyle(PulsePalette.textSecondary)

                Text(highlight.value)
                    .font(.title3.monospacedDigit().weight(.bold))
                    .foregroundStyle(PulsePalette.textPrimary)
                    .contentTransition(.numericText())

                Text(highlight.detail)
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 210)
    }
}

struct DashboardMetricCard: View {
    let title: String
    let tier: CapabilityTier
    let mode: TelemetryMode
    let primaryText: String
    let secondaryText: String
    let statusText: String
    let deltaText: String
    let caption: String
    let trend: [Double]
    let accent: Color
    let glowIntensity: Double
    let showCapabilityBadge: Bool
    let showSourceBadge: Bool
    let showFootnote: Bool
    let footerTags: [String]

    var body: some View {
        NeonCard(accent: accent, glowIntensity: glowIntensity) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title.uppercased())
                            .font(PulseFonts.micro)
                            .foregroundStyle(PulsePalette.textSecondary)

                        Text(primaryText)
                            .font(PulseFonts.cardValue)
                            .foregroundStyle(PulsePalette.textPrimary)
                            .contentTransition(.numericText())
                            .animation(.snappy(duration: 0.35), value: primaryText)

                        Text(secondaryText)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(accent)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 8) {
                        if showSourceBadge {
                            ModePill(mode: mode)
                        }
                        if showCapabilityBadge {
                            CapabilityPill(tier: tier)
                        }
                    }
                }

                HStack(spacing: 8) {
                    MetricTag(text: statusText, accent: accent)
                    MetricTag(text: deltaText, accent: PulsePalette.textSecondary)
                }

                SparklineView(points: trend, colors: [accent.opacity(0.9), PulsePalette.pink.opacity(0.8)])

                if !footerTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(footerTags, id: \.self) { tag in
                                MetricTag(text: tag, accent: PulsePalette.textSecondary)
                            }
                        }
                    }
                }

                if showFootnote {
                    Text(caption)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

struct TimelineChip: View {
    let event: SessionEvent
    let showCapabilityBadge: Bool
    let showSourceBadges: Bool
    let dense: Bool

    var body: some View {
        HStack(alignment: .top, spacing: dense ? 10 : 14) {
            ZStack {
                Circle()
                    .fill(event.tier.accentColor.opacity(0.18))
                    .frame(width: dense ? 34 : 40, height: dense ? 34 : 40)

                Image(systemName: event.kind.iconName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(event.tier.accentColor)
            }

            VStack(alignment: .leading, spacing: dense ? 8 : 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(event.title)
                            .font(dense ? .subheadline.weight(.semibold) : .headline)
                            .foregroundStyle(PulsePalette.textPrimary)

                        if showSourceBadges || showCapabilityBadge {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    if showSourceBadges {
                                        ModePill(mode: event.mode)
                                        OriginPill(origin: event.origin)
                                    }
                                    if showCapabilityBadge {
                                        CapabilityPill(tier: event.tier)
                                    }
                                }
                            }
                        }
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(PulseFormatters.timelineClock.string(from: event.timestamp))
                            .font(PulseFonts.micro)
                            .foregroundStyle(PulsePalette.textSecondary)
                        Text(PulseFormatters.relativeTime(since: event.timestamp))
                            .font(PulseFonts.micro)
                            .foregroundStyle(PulsePalette.textSecondary.opacity(0.85))
                    }
                }

                Text(event.detail)
                    .font(dense ? .footnote : .subheadline)
                    .foregroundStyle(PulsePalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(dense ? 14 : 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(event.tier.accentColor.opacity(0.2), lineWidth: 0.8)
                )
        )
    }
}
