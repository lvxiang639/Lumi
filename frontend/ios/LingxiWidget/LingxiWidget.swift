import WidgetKit
import SwiftUI

// MARK: - Data Model

struct WidgetEntry: TimelineEntry {
    let date: Date
    let weather: String
    let countdown: String
}

// MARK: - Data Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), weather: "☀️ 晴 32°", countdown: "🎯 旅行: 3天")
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> WidgetEntry {
        let defaults = UserDefaults(suiteName: "group.com.lingxi.widget")
        let weather = defaults?.string(forKey: "widget_weather") ?? "🦏 灵犀"
        let countdown = defaults?.string(forKey: "widget_countdown") ?? ""
        return WidgetEntry(date: Date(), weather: weather, countdown: countdown)
    }
}

// MARK: - Widget Views

struct SmallWidgetView: View {
    let entry: WidgetEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("🦏")
                    .font(.system(size: 28))
                Spacer()
                Text("灵犀")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Text(entry.weather)
                .font(.caption)
                .lineLimit(1)
            if !entry.countdown.isEmpty {
                Text(entry.countdown)
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(12)
        .widgetBackground()
    }
}

struct MediumWidgetView: View {
    let entry: WidgetEntry
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("🦏 灵犀")
                    .font(.headline)
                Text(entry.weather)
                    .font(.subheadline)
                if !entry.countdown.isEmpty {
                    Label(entry.countdown, systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                Spacer()
                Text("刚刚更新")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack {
                Text("🦏")
                    .font(.system(size: 48))
            }
        }
        .padding(16)
        .widgetBackground()
    }
}

// MARK: - Widget Configuration

struct LingxiWidget: Widget {
    let kind = "LingxiWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            switch WidgetFamily.current {
            case .systemSmall:  SmallWidgetView(entry: entry)
            default:            MediumWidgetView(entry: entry)
            }
        }
        .configurationDisplayName("灵犀")
        .description("天气 + 倒数日，一眼看见")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Background Extension

extension View {
    func widgetBackground() -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            return containerBackground(.regularMaterial, for: .widget)
        } else {
            return background(.regularMaterial)
        }
    }
}
