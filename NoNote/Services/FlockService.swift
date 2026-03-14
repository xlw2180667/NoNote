import SwiftUI

enum SheepAccessory: String {
    case none, star, crown, wings
}

struct SheepDefinition: Identifiable {
    let id: String
    let woolColor: Color
    let accessory: SheepAccessory
    let isSpecial: Bool
}

struct FlockState {
    let sheep: [SheepDefinition]
    let isAwake: Bool
    let totalEntries: Int
    let bestStreak: Int
    let currentStreak: Int
    let regularCount: Int
    let specialCount: Int
    let progressToNextRegular: Double
    let daysToNextRegular: Int
    let progressToNextSpecial: Double
    let daysToNextSpecial: Int

    var sheepCount: Int { sheep.count }
}

enum FlockService {
    static let woolColors: [Color] = [
        Color(red: 0.96, green: 0.94, blue: 0.90), // white
        Color(red: 0.98, green: 0.95, blue: 0.82), // cream
        Color(red: 0.98, green: 0.80, blue: 0.82), // pink
        Color(red: 0.78, green: 0.88, blue: 0.98), // light blue
        Color(red: 0.85, green: 0.78, blue: 0.95), // lavender
        Color(red: 0.75, green: 0.95, blue: 0.85), // mint
        Color(red: 0.98, green: 0.85, blue: 0.75), // peach
    ]

    static func regularSheepDefinition(at index: Int) -> SheepDefinition {
        SheepDefinition(
            id: "regular_\(index)",
            woolColor: woolColors[index % woolColors.count],
            accessory: .none,
            isSpecial: false
        )
    }

    static func specialSheepDefinition(at index: Int) -> SheepDefinition {
        let accessories: [SheepAccessory] = [.star, .crown, .wings]
        return SheepDefinition(
            id: "special_\(index)",
            woolColor: woolColors[index % woolColors.count],
            accessory: accessories[index % accessories.count],
            isSpecial: true
        )
    }

    static func computeFlockState(diaryDates: Set<String>) -> FlockState {
        let currentStreak = StatsService.currentStreak(dates: diaryDates)
        let bestStreak = StatsService.longestStreak(dates: diaryDates)
        let totalEntries = diaryDates.count

        let isAwake = currentStreak > 0
        let streak = isAwake ? currentStreak : bestStreak

        let regularCount = streak / 7
        let specialCount = streak / 30

        // Build regular sheep with unlock days
        let regularSheep: [(day: Int, def: SheepDefinition)] = (0..<regularCount).map { i in
            (day: (i + 1) * 7, def: regularSheepDefinition(at: i))
        }

        // Build special sheep with unlock days
        let specialSheep: [(day: Int, def: SheepDefinition)] = (0..<specialCount).map { i in
            (day: (i + 1) * 30, def: specialSheepDefinition(at: i))
        }

        // Merge and sort by unlock day
        let merged = (regularSheep + specialSheep).sorted { $0.day < $1.day }
        let sheep = merged.map { $0.def }

        // Two-track progress
        let daysInRegularCycle = isAwake ? currentStreak % 7 : 0
        let progressToNextRegular = Double(daysInRegularCycle) / 7.0
        let daysToNextRegular = 7 - daysInRegularCycle

        let daysInSpecialCycle = isAwake ? currentStreak % 30 : 0
        let progressToNextSpecial = Double(daysInSpecialCycle) / 30.0
        let daysToNextSpecial = 30 - daysInSpecialCycle

        return FlockState(
            sheep: sheep,
            isAwake: isAwake,
            totalEntries: totalEntries,
            bestStreak: bestStreak,
            currentStreak: currentStreak,
            regularCount: regularCount,
            specialCount: specialCount,
            progressToNextRegular: progressToNextRegular,
            daysToNextRegular: daysToNextRegular,
            progressToNextSpecial: progressToNextSpecial,
            daysToNextSpecial: daysToNextSpecial
        )
    }
}
