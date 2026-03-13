import SwiftUI

enum SheepAccessory: String {
    case none, star, crown, wings
}

enum SheepTrack {
    case regular, special
}

struct SheepDefinition: Identifiable {
    let id: String
    let nameKey: String
    let woolColor: Color
    let accessory: SheepAccessory
    let track: SheepTrack
    let threshold: Int
}

struct FlockState {
    let unlockedRegular: [SheepDefinition]
    let unlockedSpecial: [SheepDefinition]
    let isAwake: Bool
    let totalEntries: Int
    let bestStreak: Int
    let currentStreak: Int
    let nextRegularMilestone: SheepDefinition?
    let nextSpecialMilestone: SheepDefinition?
    let progressToNextRegular: Double
    let progressToNextSpecial: Double

    var allUnlocked: [SheepDefinition] {
        unlockedRegular + unlockedSpecial
    }
}

enum FlockService {
    static let regularSheep: [SheepDefinition] = [
        SheepDefinition(id: "white", nameKey: "#sheepWhite", woolColor: Color(red: 0.96, green: 0.94, blue: 0.90), accessory: .none, track: .regular, threshold: 7),
        SheepDefinition(id: "cream", nameKey: "#sheepCream", woolColor: Color(red: 0.98, green: 0.95, blue: 0.82), accessory: .none, track: .regular, threshold: 14),
        SheepDefinition(id: "pink", nameKey: "#sheepPink", woolColor: Color(red: 0.98, green: 0.80, blue: 0.82), accessory: .none, track: .regular, threshold: 28),
        SheepDefinition(id: "lightBlue", nameKey: "#sheepLightBlue", woolColor: Color(red: 0.78, green: 0.88, blue: 0.98), accessory: .none, track: .regular, threshold: 50),
        SheepDefinition(id: "lavender", nameKey: "#sheepLavender", woolColor: Color(red: 0.85, green: 0.78, blue: 0.95), accessory: .none, track: .regular, threshold: 80),
        SheepDefinition(id: "mint", nameKey: "#sheepMint", woolColor: Color(red: 0.75, green: 0.95, blue: 0.85), accessory: .none, track: .regular, threshold: 120),
        SheepDefinition(id: "peach", nameKey: "#sheepPeach", woolColor: Color(red: 0.98, green: 0.85, blue: 0.75), accessory: .none, track: .regular, threshold: 200),
    ]

    static let specialSheep: [SheepDefinition] = [
        SheepDefinition(id: "star", nameKey: "#sheepStar", woolColor: Color(red: 0.98, green: 0.92, blue: 0.55), accessory: .star, track: .special, threshold: 7),
        SheepDefinition(id: "golden", nameKey: "#sheepGolden", woolColor: Color(red: 0.95, green: 0.82, blue: 0.35), accessory: .none, track: .special, threshold: 30),
        SheepDefinition(id: "crown", nameKey: "#sheepCrown", woolColor: Color(red: 0.95, green: 0.82, blue: 0.35), accessory: .crown, track: .special, threshold: 100),
        SheepDefinition(id: "angel", nameKey: "#sheepAngel", woolColor: Color(red: 0.98, green: 0.98, blue: 1.00), accessory: .wings, track: .special, threshold: 365),
    ]

    static func computeFlockState(diaryDates: Set<String>) -> FlockState {
        let totalEntries = diaryDates.count
        let currentStreak = StatsService.currentStreak(dates: diaryDates)
        let bestStreak = StatsService.longestStreak(dates: diaryDates)

        let unlockedRegular = regularSheep.filter { $0.threshold <= totalEntries }
        let unlockedSpecial = specialSheep.filter { $0.threshold <= bestStreak }

        let nextRegular = regularSheep.first { $0.threshold > totalEntries }
        let nextSpecial = specialSheep.first { $0.threshold > bestStreak }

        let progressRegular: Double
        if let next = nextRegular {
            let prev = unlockedRegular.last?.threshold ?? 0
            let range = next.threshold - prev
            let current = totalEntries - prev
            progressRegular = range > 0 ? min(Double(current) / Double(range), 1.0) : 0
        } else {
            progressRegular = 1.0
        }

        let progressSpecial: Double
        if let next = nextSpecial {
            let prev = unlockedSpecial.last?.threshold ?? 0
            let range = next.threshold - prev
            let current = bestStreak - prev
            progressSpecial = range > 0 ? min(Double(current) / Double(range), 1.0) : 0
        } else {
            progressSpecial = 1.0
        }

        return FlockState(
            unlockedRegular: unlockedRegular,
            unlockedSpecial: unlockedSpecial,
            isAwake: currentStreak > 0,
            totalEntries: totalEntries,
            bestStreak: bestStreak,
            currentStreak: currentStreak,
            nextRegularMilestone: nextRegular,
            nextSpecialMilestone: nextSpecial,
            progressToNextRegular: progressRegular,
            progressToNextSpecial: progressSpecial
        )
    }
}
