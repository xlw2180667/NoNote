import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct Provider: TimelineProvider {
    private let suiteName = "group.greenCross.NoDiary"

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    func placeholder(in context: Context) -> DiaryWidgetEntry {
        DiaryWidgetEntry(date: Date(), diaryText: "Today's diary...", mood: "🐑", streak: 3, photoCount: 0, thumbnail: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (DiaryWidgetEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DiaryWidgetEntry>) -> Void) {
        let entry = currentEntry()
        let midnight = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        )
        let timeline = Timeline(entries: [entry], policy: .after(midnight))
        completion(timeline)
    }

    private func currentEntry() -> DiaryWidgetEntry {
        DiaryWidgetEntry(
            date: Date(),
            diaryText: defaults?.string(forKey: "todayDiaryText") ?? "",
            mood: defaults?.string(forKey: "todayMood") ?? "",
            streak: defaults?.integer(forKey: "currentStreak") ?? 0,
            photoCount: defaults?.integer(forKey: "todayPhotoCount") ?? 0,
            thumbnail: loadThumbnail()
        )
    }

    private func loadThumbnail() -> UIImage? {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName) else { return nil }
        let url = container.appendingPathComponent("widget_thumbnail.jpg")
        return UIImage(contentsOfFile: url.path)
    }
}

// MARK: - Entry

struct DiaryWidgetEntry: TimelineEntry {
    let date: Date
    let diaryText: String
    let mood: String
    let streak: Int
    let photoCount: Int
    let thumbnail: UIImage?

    var hasEntry: Bool { !diaryText.isEmpty }
    var displayMood: String { mood.isEmpty ? "🐑" : mood }
    var hasPhotos: Bool { photoCount > 0 && thumbnail != nil }
}

// MARK: - Widget Views

struct NoDiaryWidgetEntryView: View {
    var entry: DiaryWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    // MARK: Small

    private var smallView: some View {
        VStack(spacing: 6) {
            if entry.hasEntry {
                HStack {
                    moodView(size: 32)
                    Spacer()
                    if entry.hasPhotos, let thumb = entry.thumbnail {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                Text(entry.diaryText)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)

                if entry.streak > 0 {
                    streakLabel
                }
            } else {
                Spacer(minLength: 0)
                Text("🐑")
                    .font(.system(size: 40))
                Text("Write today's diary")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 0)
            }
        }
        .padding(2)
    }

    // MARK: Medium

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(dateString)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                if entry.hasEntry {
                    moodView(size: 22)
                }
            }

            if entry.hasEntry {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.diaryText)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Spacer(minLength: 0)

                        HStack(spacing: 8) {
                            if entry.streak > 0 {
                                streakLabel
                            }
                            if entry.photoCount > 1 {
                                photoCountLabel
                            }
                        }
                    }

                    if entry.hasPhotos, let thumb = entry.thumbnail {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            } else {
                Spacer(minLength: 0)
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Text("🐑")
                            .font(.system(size: 32))
                        Text("Tap to write today's diary")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Spacer(minLength: 0)
            }
        }
        .padding(2)
    }

    // MARK: Shared

    @ViewBuilder
    private func moodView(size: CGFloat) -> some View {
        if SheepMood.isSheepMood(entry.mood) {
            SheepMoodIcon(mood: entry.mood, size: size)
        } else if entry.mood.isEmpty {
            Text("🐑")
                .font(.system(size: size))
        } else {
            Text(entry.mood)
                .font(.system(size: size))
        }
    }

    private var streakLabel: some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
            Text("\(entry.streak) days")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var photoCountLabel: some View {
        HStack(spacing: 3) {
            Image(systemName: "photo")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text("\(entry.photoCount)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: entry.date)
    }
}

// MARK: - Widget Configuration

struct NoDiaryWidget: Widget {
    let kind: String = "NoDiaryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            NoDiaryWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("NoDiary")
        .description("Today's diary at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    NoDiaryWidget()
} timeline: {
    DiaryWidgetEntry(date: .now, diaryText: "Had a wonderful day at the park with friends.", mood: "😊", streak: 5, photoCount: 3, thumbnail: nil)
    DiaryWidgetEntry(date: .now, diaryText: "", mood: "", streak: 0, photoCount: 0, thumbnail: nil)
}

#Preview(as: .systemMedium) {
    NoDiaryWidget()
} timeline: {
    DiaryWidgetEntry(date: .now, diaryText: "Had a wonderful day at the park with friends. The weather was perfect.", mood: "😊", streak: 5, photoCount: 3, thumbnail: nil)
    DiaryWidgetEntry(date: .now, diaryText: "", mood: "", streak: 0, photoCount: 0, thumbnail: nil)
}
