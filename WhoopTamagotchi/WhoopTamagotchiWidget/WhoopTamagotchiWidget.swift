import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct TamagotchiTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TamagotchiEntry {
        TamagotchiEntry(date: Date(), strain: 10.0, strainLevel: .moderate, isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (TamagotchiEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        let entry = entryFromStoredState()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TamagotchiEntry>) -> Void) {
        Task {
            var strain: Double = 0.0

            // Try fetching fresh data from WHOOP
            do {
                strain = try await WhoopAPIClient.shared.fetchTodayStrain()
            } catch {
                // Fall back to stored state
                if let state = TamagotchiState.load() {
                    strain = state.strain
                }
            }

            let level = StrainLevel.from(strain: strain)
            let entry = TamagotchiEntry(
                date: Date(),
                strain: strain,
                strainLevel: level,
                isPlaceholder: false
            )

            // Refresh every 15 minutes
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    private func entryFromStoredState() -> TamagotchiEntry {
        if let state = TamagotchiState.load() {
            let level = StrainLevel.from(strain: state.strain)
            return TamagotchiEntry(date: state.lastUpdated, strain: state.strain, strainLevel: level, isPlaceholder: false)
        }
        return TamagotchiEntry(date: Date(), strain: 0, strainLevel: .resting, isPlaceholder: false)
    }
}

// MARK: - Timeline Entry

struct TamagotchiEntry: TimelineEntry {
    let date: Date
    let strain: Double
    let strainLevel: StrainLevel
    let isPlaceholder: Bool
}

// MARK: - Small Widget View

struct TamagotchiSmallWidgetView: View {
    let entry: TamagotchiEntry

    var body: some View {
        VStack(spacing: 6) {
            TamagotchiCharacter(strainLevel: entry.strainLevel, strain: entry.strain)
        }
        .containerBackground(for: .widget) {
            backgroundGradient
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
        .padding(.horizontal, 4)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [statusColor.opacity(0.12), statusColor.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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
            if #available(iOS 17.0, *) {
                WidgetEntryView(entry: entry)
            } else {
                WidgetEntryView(entry: entry)
                    .padding()
            }
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

// MARK: - Preview

#Preview("Small", as: .systemSmall) {
    WhoopTamagotchiWidget()
} timeline: {
    TamagotchiEntry(date: Date(), strain: 2.0, strainLevel: .resting, isPlaceholder: false)
    TamagotchiEntry(date: Date(), strain: 6.5, strainLevel: .light, isPlaceholder: false)
    TamagotchiEntry(date: Date(), strain: 11.0, strainLevel: .moderate, isPlaceholder: false)
    TamagotchiEntry(date: Date(), strain: 15.5, strainLevel: .high, isPlaceholder: false)
    TamagotchiEntry(date: Date(), strain: 19.0, strainLevel: .overreach, isPlaceholder: false)
}

#Preview("Medium", as: .systemMedium) {
    WhoopTamagotchiWidget()
} timeline: {
    TamagotchiEntry(date: Date(), strain: 14.2, strainLevel: .high, isPlaceholder: false)
}
