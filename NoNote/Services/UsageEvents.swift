import UsageKit

/// Feature events counted by UsageKit (anonymous per-day counts, see the package README).
/// Only *that* a feature was used — never anything written, the mood, the weather,
/// a sheep's name, or any other content or value.
enum DiaryUsageEvent: String, UsageEventName {
    /// A day went from empty to written — the core action.
    case entryCreated = "entry_created"
    /// A save that attached new photos.
    case photoAdded = "photo_added"
    /// A Pro user dressed a sheep.
    case costumeChanged = "costume_changed"

    // What free users want badly enough to pay for. Free users only.
    /// Tapped a costume — Pro-only, a free user can preview but not keep it.
    case lockedCostume = "locked_costume"
    /// A save earned a sheep beyond the free flock's five (shown greyed out).
    case limitHitFlock = "limit_hit_flock"
    /// The App Store purchase sheet was cancelled.
    case paywallClosed = "paywall_closed"
}

/// Where the Pro purchase sheet was opened from. Counted as `paywall_shown_<raw>`.
enum DiaryPaywallSource: String, UsagePaywallSource {
    case settings
    /// The "unlock full flock" card in the flock sheet.
    case flockCard = "flock_card"
    /// The unlock button under the costume picker.
    case wardrobe
}

/// Screens a user deliberately goes to. Counted as `screen_<raw>` per appearance, via
/// `.usageScreen(_:)` on each screen's root view. (Replaces pass-1's search_opened /
/// stats_opened / flock_opened.)
enum DiaryScreen: String, UsageScreenName {
    /// The home screen. Re-counts when the user comes back to it from a pushed screen.
    case calendar
    /// iPad keeps the editor on screen and rebuilds it per selected day, so there it
    /// counts once per day selected rather than once per navigation.
    case editor
    case search
    case stats
    case monthPicker = "month_picker"
    /// The flock sheet — where every Pro feature lives.
    case flock
    case settings
    case security
    case reminder
    case export
    case `import`
    case lockScreen = "lock_screen"
}

/// Multi-step flows. `flow_started_<raw>` minus `flow_completed_<raw>` is where users give up.
/// The purchase funnel deliberately has no pair here: `paywall_shown_<source>` →
/// `purchase_completed` / `paywall_closed` / `failed_purchase` already counts it.
enum DiaryFlow: String, UsageFlowName {
    /// Started: tapped Export with something to export. Completed: the share sheet
    /// finished with an action (saved / sent), not just produced a file.
    case export
    /// Started: picked a source (file picker opens). Completed: at least one entry imported.
    case `import`
    /// Started: switched App Lock on. Completed: the confirming Face ID / passcode passed.
    case lockSetup = "lock_setup"
}

/// Failures the user can see. Counted as `failed_<raw>`.
enum DiaryFailure: String, UsageFailureName {
    /// A month could not be loaded from iCloud (the calendar's "can't connect" alert).
    case icloudFetch = "icloud_fetch"
    /// The App Store purchase threw or came back unverified.
    case purchase
    /// Restore Purchases could not reach the App Store.
    case restore
    /// The import file could not be opened or parsed.
    case importRead = "import_read"
    /// An import finished with entries still waiting to upload to iCloud.
    case importUpload = "import_upload"
    /// Export produced no file.
    case export
    /// Face ID / passcode failed or was cancelled on the lock screen.
    case unlock
    /// Daily reminder switched on but notification permission was denied.
    case reminderPermission = "reminder_permission"
}
