import Foundation
import SwiftUI

enum PulsePalette {
    static let backgroundTop = Color(red: 0.03, green: 0.06, blue: 0.13)
    static let backgroundBottom = Color(red: 0.01, green: 0.01, blue: 0.05)
    static let panel = Color(red: 0.07, green: 0.10, blue: 0.19)
    static let panelSecondary = Color(red: 0.05, green: 0.08, blue: 0.16)
    static let panelHighlight = Color(red: 0.11, green: 0.15, blue: 0.27)
    static let cyan = Color(red: 0.27, green: 0.96, blue: 0.97)
    static let pink = Color(red: 1.00, green: 0.26, blue: 0.72)
    static let lime = Color(red: 0.63, green: 1.00, blue: 0.56)
    static let amber = Color(red: 1.00, green: 0.74, blue: 0.30)
    static let violet = Color(red: 0.56, green: 0.48, blue: 1.00)
    static let coral = Color(red: 1.00, green: 0.46, blue: 0.48)
    static let textPrimary = Color(red: 0.94, green: 0.97, blue: 1.00)
    static let textSecondary = Color(red: 0.58, green: 0.69, blue: 0.88)
    static let divider = Color.white.opacity(0.08)

    static let backgroundGradient = LinearGradient(
        colors: [backgroundTop, backgroundBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let heroGradient = LinearGradient(
        colors: [cyan.opacity(0.45), pink.opacity(0.36), violet.opacity(0.32)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

enum PulseFonts {
    static let hero = Font.system(size: 34, weight: .black, design: .rounded)
    static let cardValue = Font.system(size: 28, weight: .bold, design: .rounded)
    static let section = Font.system(size: 18, weight: .semibold, design: .rounded)
    static let micro = Font.system(size: 12, weight: .medium, design: .monospaced)
}

extension CapabilityTier {
    var accentColor: Color {
        switch self {
        case .real:
            return PulsePalette.cyan
        case .estimated:
            return PulsePalette.amber
        case .placeholder:
            return PulsePalette.pink
        case .hybrid:
            return PulsePalette.violet
        }
    }
}

extension TelemetryMode {
    var accentColor: Color {
        switch self {
        case .live:
            return PulsePalette.cyan
        case .demo:
            return PulsePalette.pink
        }
    }
}

extension EventOrigin {
    var accentColor: Color {
        switch self {
        case .system:
            return PulsePalette.cyan
        case .inferred:
            return PulsePalette.amber
        case .demo:
            return PulsePalette.pink
        case .app:
            return PulsePalette.violet
        }
    }
}

enum PulseFormatters {
    static let byteCount: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.includesUnit = true
        formatter.allowedUnits = [.useGB, .useMB]
        return formatter
    }()

    static let duration: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()

    static let timelineClock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    static let timelineDayClock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d • HH:mm"
        return formatter
    }()

    static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    static func battery(_ level: Float?) -> String {
        guard let level else { return "N/A" }
        return "\(Int((level * 100).rounded()))%"
    }

    static func percentage(_ value: Double?) -> String {
        guard let value else { return "N/A" }
        return "\(Int((value * 100).rounded()))%"
    }

    static func bytes(_ value: UInt64?) -> String {
        guard let value else { return "N/A" }
        return byteCount.string(fromByteCount: Int64(value))
    }

    static func bytes(_ value: Int64?) -> String {
        guard let value else { return "N/A" }
        return byteCount.string(fromByteCount: value)
    }

    static func fps(_ value: Double?) -> String {
        guard let value else { return "N/A" }
        return "\(Int(value.rounded())) fps"
    }

    static func throughput(_ value: Double?) -> String {
        guard let value else { return "Pending" }
        return String(format: "%.1f Mbps", value)
    }

    static func tilt(_ value: Double?) -> String {
        guard let value else { return "Idle" }
        return String(format: "%.2f g", value)
    }

    static func delta(current: Double?, previous: Double?, suffix: String = "", decimals: Int = 0) -> String {
        guard let current, let previous else { return "Fresh sample" }
        let difference = current - previous
        guard abs(difference) > 0.0001 else { return "Stable" }

        let sign = difference >= 0 ? "+" : "-"
        let magnitude = abs(difference)

        if decimals > 0 {
            return String(format: "%@%.\(decimals)f%@", sign, magnitude, suffix)
        }

        return "\(sign)\(Int(magnitude.rounded()))\(suffix)"
    }

    static func relativeTime(since date: Date) -> String {
        relative.localizedString(for: date, relativeTo: Date())
    }
}
