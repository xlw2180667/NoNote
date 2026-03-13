import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct Provider: TimelineProvider {
    private let suiteName = "group.greenCross.NoDiary"

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    func placeholder(in context: Context) -> DiaryWidgetEntry {
        DiaryWidgetEntry(date: Date(), diaryText: "Today's diary...", mood: "🐑", streak: 3, photoCount: 0, thumbnail: nil, sheepCount: 2, sheepAwake: true, isLocked: false)
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
        let locked = defaults?.bool(forKey: "appLockEnabled") ?? false
        return DiaryWidgetEntry(
            date: Date(),
            diaryText: defaults?.string(forKey: "todayDiaryText") ?? "",
            mood: defaults?.string(forKey: "todayMood") ?? "",
            streak: defaults?.integer(forKey: "currentStreak") ?? 0,
            photoCount: defaults?.integer(forKey: "todayPhotoCount") ?? 0,
            thumbnail: locked ? nil : loadThumbnail(),
            sheepCount: defaults?.integer(forKey: "sheepCount") ?? 0,
            sheepAwake: defaults?.bool(forKey: "sheepAwake") ?? false,
            isLocked: locked
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
    let sheepCount: Int
    let sheepAwake: Bool
    let isLocked: Bool

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
            if entry.isLocked {
                lockedSmallView
            } else if entry.hasEntry {
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

                bottomBar
            } else {
                emptySmallView
            }
        }
        .padding(2)
    }

    private var lockedSmallView: some View {
        VStack(spacing: 6) {
            HStack {
                if entry.sheepCount > 0 {
                    sheepCountBadge
                }
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if entry.sheepCount > 0 {
                SheepMoodIcon(mood: entry.sheepAwake ? "good" : "neutral", size: 40)
            } else {
                Text("🐑")
                    .font(.system(size: 40))
            }

            if entry.hasEntry {
                Text("Diary written today")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                Text("Write today's diary")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            bottomBar
        }
    }

    private var emptySmallView: some View {
        VStack(spacing: 6) {
            if entry.sheepCount > 0 {
                HStack {
                    sheepCountBadge
                    Spacer()
                }
            }
            Spacer(minLength: 0)
            SheepMoodIcon(mood: entry.sheepAwake ? "good" : "neutral", size: 40)
            Text("Write today's diary")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
            if entry.streak > 0 {
                streakLabel
            }
        }
    }

    // MARK: Medium

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(dateString)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                if entry.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else if entry.hasEntry {
                    moodView(size: 22)
                }
            }

            if entry.isLocked {
                lockedMediumContent
            } else if entry.hasEntry {
                unlockMediumContent
            } else {
                emptyMediumContent
            }
        }
        .padding(2)
    }

    private var lockedMediumContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                if entry.hasEntry {
                    Text("Diary written today")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Tap to write today's diary")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    if entry.streak > 0 { streakLabel }
                    if entry.sheepCount > 0 { sheepCountBadge }
                }
            }

            Spacer()

            SheepMoodIcon(mood: entry.sheepAwake ? "good" : "neutral", size: 48)
        }
    }

    private var unlockMediumContent: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.diaryText)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    if entry.streak > 0 { streakLabel }
                    if entry.sheepCount > 0 { sheepCountBadge }
                    if entry.photoCount > 1 { photoCountLabel }
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
    }

    private var emptyMediumContent: some View {
        VStack {
            Spacer(minLength: 0)
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    SheepMoodIcon(mood: entry.sheepAwake ? "good" : "neutral", size: 32)
                    Text("Tap to write today's diary")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            Spacer(minLength: 0)
            if entry.streak > 0 || entry.sheepCount > 0 {
                HStack(spacing: 8) {
                    Spacer()
                    if entry.streak > 0 { streakLabel }
                    if entry.sheepCount > 0 { sheepCountBadge }
                    Spacer()
                }
            }
        }
    }

    // MARK: Shared

    private var bottomBar: some View {
        HStack(spacing: 6) {
            if entry.streak > 0 { streakLabel }
            Spacer()
            if entry.sheepCount > 0 && !entry.isLocked { sheepCountBadge }
        }
    }

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

    private var sheepCountBadge: some View {
        HStack(spacing: 3) {
            Text("🐑")
                .font(.system(size: 10))
            Text("\(entry.sheepCount)")
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
    DiaryWidgetEntry(date: .now, diaryText: "Had a wonderful day at the park.", mood: "good", streak: 5, photoCount: 1, thumbnail: nil, sheepCount: 3, sheepAwake: true, isLocked: false)
    DiaryWidgetEntry(date: .now, diaryText: "Had a wonderful day at the park.", mood: "good", streak: 5, photoCount: 0, thumbnail: nil, sheepCount: 3, sheepAwake: true, isLocked: true)
    DiaryWidgetEntry(date: .now, diaryText: "", mood: "", streak: 0, photoCount: 0, thumbnail: nil, sheepCount: 2, sheepAwake: false, isLocked: false)
}

#Preview(as: .systemMedium) {
    NoDiaryWidget()
} timeline: {
    DiaryWidgetEntry(date: .now, diaryText: "Had a wonderful day at the park with friends. The weather was perfect.", mood: "good", streak: 5, photoCount: 3, thumbnail: nil, sheepCount: 3, sheepAwake: true, isLocked: false)
    DiaryWidgetEntry(date: .now, diaryText: "Had a wonderful day at the park.", mood: "good", streak: 5, photoCount: 0, thumbnail: nil, sheepCount: 3, sheepAwake: true, isLocked: true)
    DiaryWidgetEntry(date: .now, diaryText: "", mood: "", streak: 0, photoCount: 0, thumbnail: nil, sheepCount: 0, sheepAwake: false, isLocked: false)
}
