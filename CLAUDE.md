# NoDiary

Minimalist diary app with iCloud sync. Write one diary entry per day, tracked on a calendar with sheep icons.

## Tech Stack

- **Language**: Swift 5, SwiftUI
- **Target**: iOS 16+, iPhone & iPad
- **Backend**: CloudKit (private database)
- **Package Manager**: Swift Package Manager
- **Dependencies**: [SheepCalendar](https://github.com/xlw2180667/SheepCalendar) (local package at `../SheepCalendar`)

## Project Structure

```
NoNote/
├── App/            NoDiaryApp.swift, Info.plist
├── Models/         DiaryEntry.swift (CKRecord wrapper), DiaryCacheEntry.swift
├── Services/       CloudKitService.swift, StatsService.swift, NotificationService.swift,
│                   ExportService.swift, PhotoCacheService.swift, SharedDataStore.swift,
│                   FlockService.swift
├── Views/          CalendarView, DiaryEditorView, DiaryPreviewCard,
│                   EmptyStateView, StreakBadgeView, LoadingOverlay,
│                   SettingsView, SearchView, MoodPickerRow,
│                   MonthlyStatsView, ReminderSettingsView, ExportView,
│                   FlockBannerView, FlockDetailView, FlockSheepView
├── Theme/          AppColors.swift (adaptive light/dark), AppFonts.swift (Roboto)
├── Localization/   Localizable.xcstrings (en + zh-Hans)
└── Resource/       Roboto-Bold/Medium/Regular.ttf
```

## Key Patterns

- **Colors**: Use semantic colors from `AppColors.swift` (`Color.accent`, `.surface`, `.surfaceCard`, `.textPrimary`, `.textSecondary`, `.warmAccent`, `.danger`). Never hardcode `.white` or `.black`.
- **Fonts**: Always use `AppFonts.bold/medium/regular` with `.custom()`. Roboto font family throughout.
- **Localization**: All user-facing strings via `String(localized: "#keyName")`. Keys prefixed with `#`. Both English and Simplified Chinese.
- **Date formats**: `"M-d-yyyy"` for diary date keys, `"M-yyyy"` for month queries, `"EEEE, MMMM d"` for display.
- **CloudKit**: `CloudKitService` is `@MainActor` with `@Published` properties (`diaryDates`, `diaryCache`). `diaryCache` maps `[String: DiaryCacheEntry]` (text + mood + photoFileURL). Local cache is updated before CloudKit calls so data persists even when iCloud is unavailable.
- **Navigation**: `RootView` owns `@StateObject CloudKitService` and checks `horizontalSizeClass`. iPhone (`.compact`): single `NavigationStack` with `CalendarView` → `DiaryEditorView` via `.navigationDestination`. iPad (`.regular`): `CalendarView` renders an `HStack` split layout — left pane (calendar + preview, max 420pt) and right pane (always-visible `DiaryEditorView` keyed by `.id(dateKey)` for auto-save on date switch). iPad editor has a manual Save button in toolbar.
- **Mood**: Emoji-based mood picker in editor. Mood stored as optional String in CloudKit "Diary" record (`mood` field).
- **Photos**: CKAsset-based photo attachments. Photos compressed to JPEG 0.7 + max 1920px. Cached locally via `PhotoCacheService`.
- **Widget**: SharedDataStore writes to App Groups (`group.greenCross.NoDiary`) for widget data sharing. Widget target must be created via Xcode GUI.

## Build & Run

```bash
xcodebuild -project NoNote.xcodeproj -scheme NoDiary \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## Xcode Project File

New `.swift` files use IDs in the `A1000000000000000000000X` / `B1000000000000000000000X` pattern in `project.pbxproj`. Next available: `A10000000000000000000029` / `B10000000000000000000029`. Group IDs: Models `C10000000000000000000002`, Services `C10000000000000000000003`, Views `C10000000000000000000004`.

## Future Features (Prioritized)

### High Priority
1. **"On This Day" Memories** — Show diary from same date in previous years on app open

### Lower Priority
2. **Yearly Wrapped** — Year-end summary card: entry count, longest streak, mood chart, top keywords. Shareable.

## Notes

- Old Mac app (AppKit, `~/Documents/work/private/NoDiary`) is deprecated — iOS version runs on Mac via iPad layout
- CloudKit production schema: `mood` (String) and `photos` (Asset List) fields were manually added and deployed
- Privacy policy: https://smartkiitos.com/nodairy/privacy/
