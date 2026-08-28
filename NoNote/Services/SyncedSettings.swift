import Foundation

/// The handful of small per-user settings that should follow the user between devices —
/// sheep names, sheep costumes, the chosen pasture.
///
/// Diary content goes through CloudKit. These are a dozen short strings, far too small to
/// deserve a record type, so they ride `NSUbiquitousKeyValueStore`: no schema, no container
/// deploy, and a 1 MB budget that is enormous next to what we put in it. The
/// `ubiquity-kvstore-identifier` entitlement was already in place.
///
/// **Reads come from `UserDefaults`, never from the cloud store directly.** UserDefaults is
/// kept as a always-current local mirror, which buys three things: reads are synchronous,
/// everything still works signed out of iCloud, and the `-pastureSeason` launch argument used
/// by the screenshot pipeline keeps working (launch arguments land in `NSArgumentDomain`,
/// which the cloud store knows nothing about).
///
/// Conflicts are last-writer-wins. For "which hat is my sheep wearing" that is the right
/// amount of machinery.
final class SyncedSettings: ObservableObject {
    static let shared = SyncedSettings()

    /// Keys we own. Anything with one of these prefixes participates in sync.
    private static let ownedPrefixes = ["sheepCostume_", "sheepName_"]
    private static let ownedKeys = ["pastureSeason"]

    private let cloud = NSUbiquitousKeyValueStore.default
    private let local = UserDefaults.standard

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cloudChangedExternally(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud)
        adoptCloudValues()
        pushUnsyncedLocalValues()
        cloud.synchronize()
    }

    // MARK: - Read / write

    func string(forKey key: String) -> String? {
        local.string(forKey: key)
    }

    func set(_ value: String?, forKey key: String) {
        if let value, !value.isEmpty {
            local.set(value, forKey: key)
            cloud.set(value, forKey: key)
        } else {
            local.removeObject(forKey: key)
            cloud.removeObject(forKey: key)
        }
    }

    /// The pasture the user picked. Falls back to `.auto`.
    var pastureSeason: String {
        get { string(forKey: "pastureSeason") ?? PastureSeason.auto.rawValue }
        set {
            set(newValue, forKey: "pastureSeason")
            objectWillChange.send()
        }
    }

    // MARK: - Reconciling the two stores

    private func isOwned(_ key: String) -> Bool {
        Self.ownedKeys.contains(key) || Self.ownedPrefixes.contains { key.hasPrefix($0) }
    }

    /// Mirror everything iCloud has down into UserDefaults.
    private func adoptCloudValues() {
        for (key, value) in cloud.dictionaryRepresentation where isOwned(key) {
            if let string = value as? String {
                local.set(string, forKey: key)
            }
        }
    }

    /// Carry values written before this build (costumes were UserDefaults-only) up to iCloud,
    /// but never overwrite something the cloud already has — that would let a stale device
    /// clobber a newer choice made elsewhere.
    private func pushUnsyncedLocalValues() {
        let existing = Set(cloud.dictionaryRepresentation.keys)
        for (key, value) in local.dictionaryRepresentation() where isOwned(key) {
            guard !existing.contains(key), let string = value as? String, !string.isEmpty else { continue }
            cloud.set(string, forKey: key)
        }
    }

    @objc private func cloudChangedExternally(_ note: Notification) {
        // Only keys the change actually touched, so a big dictionary does not cause churn.
        let changed = (note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]) ?? []
        var touchedOurs = false
        for key in changed where isOwned(key) {
            touchedOurs = true
            if let string = cloud.string(forKey: key) {
                local.set(string, forKey: key)
            } else {
                local.removeObject(forKey: key)
            }
        }
        guard touchedOurs else { return }
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }
}
