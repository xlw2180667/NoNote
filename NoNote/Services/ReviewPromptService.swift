import Foundation

/// Decides when to ask for an App Store rating. The moment a diary save
/// completes a 7-day streak cycle — a new sheep joins the flock — is the
/// happiest point in the app, so we ask right then. Each streak milestone
/// is only used once, with a 60-day cooldown between prompts.
enum ReviewPromptService {
    private static let lastMilestoneKey = "reviewPromptLastMilestone"
    private static let lastRequestDateKey = "reviewPromptLastRequestDate"
    private static let cooldown: TimeInterval = 60 * 60 * 24 * 60

    /// Call right after a diary save. Returns true when a review prompt
    /// should be shown now, and marks the milestone as used.
    static func shouldRequestReview(diaryDates: Set<String>) -> Bool {
        let streak = StatsService.currentStreak(dates: diaryDates)
        guard streak >= 7, streak % 7 == 0 else { return false }

        let defaults = UserDefaults.standard
        guard streak > defaults.integer(forKey: lastMilestoneKey) else { return false }
        if let lastRequest = defaults.object(forKey: lastRequestDateKey) as? Date,
           Date().timeIntervalSince(lastRequest) < cooldown {
            return false
        }

        defaults.set(streak, forKey: lastMilestoneKey)
        defaults.set(Date(), forKey: lastRequestDateKey)
        return true
    }
}
