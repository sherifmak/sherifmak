import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct TamagotchiTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TamagotchiEntry {
        TamagotchiEntry(date: Date(), strain: 10.0, strainLevel: .moderate, needsReauth: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (TamagotchiEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        completion(entryFromStoredState())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TamagotchiEntry>) -> Void) {
        // Read cached state first to ensure we always have something
        let cachedEntry = entryFromStoredState()

        Task {
            var entry = cachedEntry

            do {
                let strain = try await WhoopAPIClient.shared.fetchTodayStrain()
                let level = StrainLevel.from(strain: strain)
                entry = TamagotchiEntry(
                    date: Date(),
                    strain: strain,
                    strainLevel: level,
                    needsReauth: false
                )
            } catch {
                // On auth failure, flag it so the widget can show a message
                if let apiError = error as? WhoopAPIError, apiError == .notAuthenticated {
                    entry = TamagotchiEntry(
                        date: cachedEntry.date,
                        strain: cachedEntry.strain,
                        strainLevel: cachedEntry.strainLevel,
                        needsReauth: true
                    )
                }
                // For other errors, use cached data as-is
            }

            // Refresh every 15 minutes (WidgetKit budgets ~40-70 refreshes/day)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())
                ?? Date().addingTimeInterval(900)
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    private func entryFromStoredState() -> TamagotchiEntry {
        if let state = TamagotchiState.load() {
            return TamagotchiEntry(
                date: state.lastUpdated,
                strain: state.strain,
                strainLevel: state.strainLevel,
                needsReauth: state.needsReauth
            )
        }
        return TamagotchiEntry(date: Date(), strain: 0, strainLevel: .resting, needsReauth: false)
    }
}

// MARK: - Timeline Entry

struct TamagotchiEntry: TimelineEntry {
    let date: Date
    let strain: Double
    let strainLevel: StrainLevel
    let needsReauth: Bool
}

// MARK: - Small Widget View

struct TamagotchiSmallWidgetView: View {
    let entry: TamagotchiEntry

    var body: some View {
        VStack(spacing: 6) {
            if entry.needsReauth {
                reauthOverlay
            } else {
                TamagotchiCharacter(strainLevel: entry.strainLevel, strain: entry.strain)
            }
        }
        .containerBackground(for: .widget) {
            backgroundGradient
        }
    }

    private var reauthOverlay: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.title2)
                .foregroundColor(.orange)
            Text("Tap to sign in")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [backgroundColor.opacity(0.15), backgroundColor.opacity(0.05)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var backgroundColor: Color {
        switch entry.strainLevel {
        case .resting:   return .blue
        case .light:     return .green
        case .moderate:  return .yellow
        case .high:      return .orange
        case .overreach: return .red
        }
    }
}

// MARK: - Medium Widget View

struct TamagotchiMediumWidgetView: View {
    let entry: TamagotchiEntry

    var body: some View {
        HStack(spacing: 16) {
            if entry.needsReauth {
                reauthView
            } else {
                TamagotchiCharacter(strainLevel: entry.strainLevel, strain: entry.strain)
                    .scaleEffect(1.2)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Today's Strain")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    Text(String(format: "%.1f", entry.strain))
                        .font(.system(size: 32, weight: .bold, design: .rounded))

                    Text(entry.strainLevel.label)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(statusColor)

                    Text(timeAgo)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
        }
        .padding(.horizontal, 4)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [statusColor.opacity(0.12), statusColor.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var reauthView: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("Session Expired")
                    .font(.system(size: 14, weight: .semibold))
                Text("Open app to reconnect WHOOP")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    private var statusColor: Color {
        switch entry.strainLevel {
        case .resting:   return .blue
        case .light:     return .green
        case .moderate:  return .yellow
        case .high:      return .orange
        case .overreach: return .red
        }
    }

    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Updated \(formatter.localizedString(for: entry.date, relativeTo: Date()))"
    }
}

// MARK: - Widget Configuration

struct WhoopTamagotchiWidget: Widget {
    let kind = "WhoopTamagotchiWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TamagotchiTimelineProvider()) { entry in
            WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Whoop Tamagotchi")
        .description("Your Tamagotchi reacts to your WHOOP daily strain.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct WidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: TamagotchiEntry

    var body: some View {
        switch family {
        case .systemMedium:
            TamagotchiMediumWidgetView(entry: entry)
        default:
            TamagotchiSmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Bundle

@main
struct WhoopTamagotchiWidgetBundle: WidgetBundle {
    var body: some Widget {
        WhoopTamagotchiWidget()
    }
}

// MARK: - WhoopAPIError Equatable

extension WhoopAPIError: Equatable {
    static func == (lhs: WhoopAPIError, rhs: WhoopAPIError) -> Bool {
        switch (lhs, rhs) {
        case (.notAuthenticated, .notAuthenticated): return true
        case (.invalidResponse, .invalidResponse): return true
        case (.rateLimited, .rateLimited): return true
        case (.httpError(let a), .httpError(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - Preview

#Preview("Small", as: .systemSmall) {
    WhoopTamagotchiWidget()
} timeline: {
    TamagotchiEntry(date: Date(), strain: 2.0, strainLevel: .resting, needsReauth: false)
    TamagotchiEntry(date: Date(), strain: 6.5, strainLevel: .light, needsReauth: false)
    TamagotchiEntry(date: Date(), strain: 15.5, strainLevel: .high, needsReauth: false)
    TamagotchiEntry(date: Date(), strain: 0, strainLevel: .resting, needsReauth: true)
}

#Preview("Medium", as: .systemMedium) {
    WhoopTamagotchiWidget()
} timeline: {
    TamagotchiEntry(date: Date(), strain: 14.2, strainLevel: .high, needsReauth: false)
    TamagotchiEntry(date: Date(), strain: 0, strainLevel: .resting, needsReauth: true)
}
