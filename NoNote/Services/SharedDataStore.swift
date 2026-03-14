import Foundation
import UIKit
import WidgetKit

enum SharedDataStore {
    private static let suiteName = "group.greenCross.NoDiary"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    private static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName)
    }

    @MainActor static func update(from cloudKit: CloudKitService) {
        guard let defaults = defaults else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "M-d-yyyy"
        let todayKey = formatter.string(from: Date())

        let entry = cloudKit.diaryCache[todayKey]
        defaults.set(entry?.text ?? "", forKey: "todayDiaryText")
        defaults.set(entry?.mood ?? "", forKey: "todayMood")
        defaults.set(StatsService.currentStreak(dates: cloudKit.diaryDates), forKey: "currentStreak")
        defaults.set(entry?.photoFileURLs.count ?? 0, forKey: "todayPhotoCount")
        let flock = FlockService.computeFlockState(diaryDates: cloudKit.diaryDates, isPro: UserDefaults.standard.bool(forKey: "isPro"))
        defaults.set(flock.sheepCount, forKey: "sheepCount")
        defaults.set(flock.isAwake, forKey: "sheepAwake")
        defaults.set(UserDefaults.standard.bool(forKey: "appLockEnabled"), forKey: "appLockEnabled")
        defaults.set(Date(), forKey: "lastUpdated")

        updateWidgetThumbnail(photoURLs: entry?.photoFileURLs ?? [])

        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Getters (for widget)

    static var todayDiaryText: String {
        defaults?.string(forKey: "todayDiaryText") ?? ""
    }

    static var todayMood: String {
        defaults?.string(forKey: "todayMood") ?? ""
    }

    static var currentStreak: Int {
        defaults?.integer(forKey: "currentStreak") ?? 0
    }

    static var todayPhotoCount: Int {
        defaults?.integer(forKey: "todayPhotoCount") ?? 0
    }

    static var sheepCount: Int {
        defaults?.integer(forKey: "sheepCount") ?? 0
    }

    static var sheepAwake: Bool {
        defaults?.bool(forKey: "sheepAwake") ?? false
    }

    // MARK: - Thumbnail

    private static var thumbnailURL: URL? {
        sharedContainerURL?.appendingPathComponent("widget_thumbnail.jpg")
    }

    private static func updateWidgetThumbnail(photoURLs: [URL]) {
        guard let thumbURL = thumbnailURL else { return }
        let fm = FileManager.default

        if let firstURL = photoURLs.first,
           let image = UIImage(contentsOfFile: firstURL.path) {
            let thumbnail = createSquareThumbnail(from: image, size: 160)
            if let data = thumbnail.jpegData(compressionQuality: 0.8) {
                try? data.write(to: thumbURL)
            }
        } else {
            try? fm.removeItem(at: thumbURL)
        }
    }

    private static func createSquareThumbnail(from image: UIImage, size: CGFloat) -> UIImage {
        let targetSize = CGSize(width: size, height: size)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            let scale: CGFloat
            if image.size.width > image.size.height {
                scale = size / image.size.height
            } else {
                scale = size / image.size.width
            }
            let scaled = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let origin = CGPoint(x: (size - scaled.width) / 2, y: (size - scaled.height) / 2)
            image.draw(in: CGRect(origin: origin, size: scaled))
        }
    }
}
