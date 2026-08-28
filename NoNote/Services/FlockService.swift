import SwiftUI

enum SheepAccessory: String {
    case none, star, crown, wings
}

enum SheepCostume: String, CaseIterable {
    case none
    case scarf, bandana, bowtie                    // neck
    case sunglasses, headphones, earmuffs          // face / ears
    case flowerCrown, ribbon, strawHat, beret, beanie, santaHat   // head

    /// Asset name, and where the art sits on the sheep as a fraction of its size.
    /// Kept as data rather than a switch in the view — twelve cases of near-identical
    /// `Image().resizable().frame().offset()` is a table, not control flow.
    struct Placement {
        let asset: String
        let widthFactor: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    var placement: Placement? {
        switch self {
        case .none:        return nil
        case .scarf:       return .init(asset: "costume_scarf",       widthFactor: 0.50, x: 0,     y: 0.38)
        case .bandana:     return .init(asset: "costume_bandana",     widthFactor: 0.48, x: 0,     y: 0.36)
        case .bowtie:      return .init(asset: "costume_bowtie",      widthFactor: 0.35, x: 0,     y: 0.30)
        case .sunglasses:  return .init(asset: "costume_sunglasses",  widthFactor: 0.48, x: 0,     y: 0.01)
        case .headphones:  return .init(asset: "costume_headphones",  widthFactor: 0.66, x: 0,     y: -0.10)
        case .earmuffs:    return .init(asset: "costume_earmuffs",    widthFactor: 0.68, x: 0,     y: -0.14)
        case .flowerCrown: return .init(asset: "costume_flowercrown", widthFactor: 0.68, x: 0,     y: -0.19)
        case .ribbon:      return .init(asset: "costume_ribbon",      widthFactor: 0.40, x: 0.18,  y: -0.26)
        case .strawHat:    return .init(asset: "costume_strawhat",    widthFactor: 0.64, x: 0,     y: -0.26)
        case .beret:       return .init(asset: "costume_beret",       widthFactor: 0.52, x: 0.04,  y: -0.28)
        case .beanie:      return .init(asset: "costume_beanie",      widthFactor: 0.54, x: 0,     y: -0.32)
        case .santaHat:    return .init(asset: "costume_santahat",    widthFactor: 0.42, x: 0.02,  y: -0.30)
        }
    }

    var localizedNameKey: String {
        switch self {
        case .none:        return "#costumeNone"
        case .scarf:       return "#costumeScarf"
        case .bandana:     return "#costumeBandana"
        case .bowtie:      return "#costumeBowtie"
        case .sunglasses:  return "#costumeSunglasses"
        case .headphones:  return "#costumeHeadphones"
        case .earmuffs:    return "#costumeEarmuffs"
        case .flowerCrown: return "#costumeFlowerCrown"
        case .ribbon:      return "#costumeRibbon"
        case .strawHat:    return "#costumeStrawHat"
        case .beret:       return "#costumeBeret"
        case .beanie:      return "#costumeBeanie"
        case .santaHat:    return "#costumeSantaHat"
        }
    }
}

/// The painted pasture behind the flock. A Pro cosmetic — free users keep the
/// procedural sky-and-hills background drawn in `FlockBannerView`.
///
/// Deliberately user-selectable rather than purely automatic: deriving the season from the
/// month alone is wrong for half the planet, and "pick the one you like" is a nicer feature
/// than a hemisphere guess. `.auto` follows the northern calendar and swaps to night after dark.
enum PastureSeason: String, CaseIterable, Identifiable {
    case auto, spring, summer, autumn, winter, night

    var id: String { rawValue }

    var localizedNameKey: String {
        switch self {
        case .auto:   return "#pastureAuto"
        case .spring: return "#pastureSpring"
        case .summer: return "#pastureSummer"
        case .autumn: return "#pastureAutumn"
        case .winter: return "#pastureWinter"
        case .night:  return "#pastureNight"
        }
    }

    /// Asset for this season; `.auto` resolves against the clock first.
    var assetName: String? {
        switch self {
        case .auto:   return PastureSeason.resolvedAuto().assetName
        case .spring: return "pasture_spring"
        case .summer: return "pasture_summer"
        case .autumn: return "pasture_autumn"
        case .winter: return "pasture_winter"
        case .night:  return "pasture_night"
        }
    }

    static func resolvedAuto(date: Date = Date(), calendar: Calendar = .current) -> PastureSeason {
        let hour = calendar.component(.hour, from: date)
        if hour >= 20 || hour < 5 { return .night }
        switch calendar.component(.month, from: date) {
        case 3...5:   return .spring
        case 6...8:   return .summer
        case 9...11:  return .autumn
        default:      return .winter
        }
    }

    /// What the banner should draw right now: nil means the free procedural pasture.
    static func current(isPro: Bool) -> PastureSeason? {
        guard isPro else { return nil }
        let raw = UserDefaults.standard.string(forKey: "pastureSeason") ?? PastureSeason.auto.rawValue
        return PastureSeason(rawValue: raw) ?? .auto
    }
}

struct SheepDefinition: Identifiable {
    let id: String
    let woolColor: Color
    let accessory: SheepAccessory
    let isSpecial: Bool
    var costume: SheepCostume = .none
    var name: String = ""
}

struct FlockState {
    let sheep: [SheepDefinition]
    let activeSheep: [SheepDefinition]
    let ghostSheep: [SheepDefinition]
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

    static func loadCostume(for sheepId: String) -> SheepCostume {
        let raw = SyncedSettings.shared.string(forKey: "sheepCostume_\(sheepId)") ?? ""
        return SheepCostume(rawValue: raw) ?? .none
    }

    static func saveCostume(_ costume: SheepCostume, for sheepId: String) {
        SyncedSettings.shared.set(costume.rawValue, forKey: "sheepCostume_\(sheepId)")
    }

    /// Sheep names live next to costumes: same per-sheep UserDefaults pattern, same Pro gate.
    /// Trimmed and length-capped on the way in so a stray paste can't blow up the layout.
    static let maxSheepNameLength = 12

    static func loadName(for sheepId: String) -> String {
        SyncedSettings.shared.string(forKey: "sheepName_\(sheepId)") ?? ""
    }

    static func saveName(_ name: String, for sheepId: String) {
        let cleaned = String(name.trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(maxSheepNameLength))
        // set(nil:) removes in both stores, so an emptied name clears everywhere
        SyncedSettings.shared.set(cleaned.isEmpty ? nil : cleaned, forKey: "sheepName_\(sheepId)")
    }

    static func computeFlockState(diaryDates: Set<String>, isPro: Bool = false) -> FlockState {
        let currentStreak = StatsService.currentStreak(dates: diaryDates)
        let bestStreak = StatsService.longestStreak(dates: diaryDates)
        let totalEntries = diaryDates.count

        let isAwake = currentStreak > 0

        let regularCount = bestStreak / 7
        let specialCount = bestStreak / 30

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
        var sheep = merged.map { $0.def }

        // Load persisted costumes for each sheep
        for i in sheep.indices {
            sheep[i].costume = loadCostume(for: sheep[i].id)
            sheep[i].name = loadName(for: sheep[i].id)
        }

        // Two-track progress
        let daysInRegularCycle = isAwake ? currentStreak % 7 : 0
        let progressToNextRegular = Double(daysInRegularCycle) / 7.0
        let daysToNextRegular = 7 - daysInRegularCycle

        let daysInSpecialCycle = isAwake ? currentStreak % 30 : 0
        let progressToNextSpecial = Double(daysInSpecialCycle) / 30.0
        let daysToNextSpecial = 30 - daysInSpecialCycle

        let freeLimit = 5
        let activeSheep = isPro ? sheep : Array(sheep.prefix(freeLimit))
        let ghostSheep = isPro ? [] : Array(sheep.dropFirst(freeLimit))

        return FlockState(
            sheep: sheep,
            activeSheep: activeSheep,
            ghostSheep: ghostSheep,
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
