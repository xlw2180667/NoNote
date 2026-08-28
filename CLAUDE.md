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
│                   FlockService.swift, AppLanguage.swift, DiaryImportService.swift
├── Views/          CalendarView, DiaryEditorView, DiaryPreviewCard, ImportView,
│                   CostumeGalleryView (DEBUG QA),
│                   EmptyStateView, StreakBadgeView, LoadingOverlay,
│                   SettingsView, SearchView, MoodPickerRow,
│                   MonthlyStatsView, ReminderSettingsView, ExportView,
│                   FlockBannerView, FlockDetailView, FlockSheepView
├── Theme/          AppColors.swift (adaptive light/dark), AppFonts.swift (Roboto)
├── Localization/   Localizable.xcstrings (en, zh-Hans, zh-Hant, ja, ko, es)
└── Resource/       Roboto-Bold/Medium/Regular.ttf

tools/
├── artgen/         generate.py, artgen.json  (FLUX.1-schnell, Apache-2.0 — 背景插画)
├── asc/            asc_upload.py, app_metadata.json, README.md, requirements.txt
└── screenshots/    capture_raw.sh, make_captioned.py
```

## Key Patterns

- **Colors**: Use semantic colors from `AppColors.swift` (`Color.accent`, `.surface`, `.surfaceCard`, `.textPrimary`, `.textSecondary`, `.warmAccent`, `.danger`). Never hardcode `.white` or `.black`.
- **Fonts**: Always use `AppFonts.bold/medium/regular` with `.custom()`. Roboto font family throughout.
- **Localization**: All user-facing strings via `String(localized: "#keyName")`. Keys prefixed with `#`. Six languages: `en`, `zh-Hans`, `zh-Hant`, `ja`, `ko`, `es`. Copy that lives in Swift rather than the catalog — the 30 writing prompts, the DEBUG demo diary text — is keyed by `AppLanguage` (`Services/AppLanguage.swift`), which resolves the bundle's chosen localization and distinguishes Hans from Hant. Add a language: `knownRegions` in `project.pbxproj`, a locale in `Localizable.xcstrings`, plus a row in each `AppLanguage`-keyed table.
- **Date formats**: `"M-d-yyyy"` for diary date keys, `"M-yyyy"` for month queries, `"EEEE, MMMM d"` for display.
- **CloudKit**: `CloudKitService` is `@MainActor` with `@Published` properties (`diaryDates`, `diaryCache`). `diaryCache` maps `[String: DiaryCacheEntry]` (text + mood + photoFileURL). Local cache is updated before CloudKit calls so data persists even when iCloud is unavailable.
- **Navigation**: `RootView` owns `@StateObject CloudKitService` and checks `horizontalSizeClass`. iPhone (`.compact`): single `NavigationStack` with `CalendarView` → `DiaryEditorView` via `.navigationDestination`. iPad (`.regular`): `CalendarView` renders an `HStack` split layout — left pane (calendar + preview, max 420pt) and right pane (always-visible `DiaryEditorView` keyed by `.id(dateKey)` for auto-save on date switch). iPad editor has a manual Save button in toolbar.
- **Mood**: Emoji-based mood picker in editor. Mood stored as optional String in CloudKit "Diary" record (`mood` field).
- **Photos**: CKAsset-based photo attachments. Photos compressed to JPEG 0.7 + max 1920px. Cached locally via `PhotoCacheService`.
- **Widget**: SharedDataStore writes to App Groups (`group.greenCross.NoDiary`) for widget data sharing. Widget target must be created via Xcode GUI.

- **Import** (2.3): `DiaryImportService` parses Day One `Journal.json`, a folder of date-named
  `.txt`/`.md`, CSV, or the app's own `.txt` export into `[ImportedEntry]`. Parsing is pure — no
  CloudKit, no cache — so `ImportView` can show a preview and let the user back out. Day One
  stamps UTC plus a separate `timeZone`; the day is read in *that* zone then rebuilt in the
  device's, because the `M-d-yyyy` key is device-local (a trip entry files under the wrong day
  otherwise). `CloudKitService.importEntries` writes locally first, then uploads 4 at a time;
  days that already hold text are skipped, never overwritten. Note the flock is sized from
  `bestStreak / 7`, so importing years of history really does grow it.

## Pro 卖什么(2.3)

免费:写作 / iCloud 同步 / 照片 / 搜索 / 统计 / 导出 / 导入 / 面容 ID 锁 —— 工具性和隐私性的功能
永远不收费,这是和商店文案一致的承诺。Pro($2.99 买断)只卖装饰:

- **完整羊群** —— `freeLimit = 5`,羊数 = `bestStreak/7 + bestStreak/30`,所以第一只灰羊出现在
  **35 天连续记录**。这就是转化几乎为零的结构性原因:从零写的用户五周内感受不到 Pro 存在。
  导入功能把这一步压缩到了装完当天(导入几年历史 → bestStreak 上百 → 立刻看到大片灰羊)。
- **12 件换装** —— 全部是 SVG(每件约 1.2KB,共 48K)。`SheepCostume.placement` 是数据表,
  加一件就是加一个 case + 一个 imageset,不动视图。
- **季节牧场 + 夜晚牧场** —— `PastureSeason`,`FlockBannerView` 在 Pro 时用整幅插画平移
  (保留原来的 0.3 视差),免费版继续用代码画的天空+草坡。
  **不做纯自动按月切换**:南半球会完全反过来,所以做成可手选,`.auto` 只是默认。
- **给小羊起名字** —— `sheepName_<id>` 存 UserDefaults,和 `sheepCostume_<id>` 同一套。

## 美术管线(tools/artgen)

只用来做**背景/氛围插画**。小羊本体是 SwiftUI `Canvas` 矢量、配饰是 SVG —— 不要让扩散模型碰:
它做不到同一角色换 11 种颜色的一致性,而且日历格子里 20px 的光栅会糊。

- 环境:共享 venv `~/.venvs/artgen`,FLUX.1-schnell 权重在 `~/.cache/huggingface`(31G,已下过)。
- 牧场图必须**中间调**:白雪地 + 奶白色小羊 = 主体消失(第一版 winter 就是这么废掉的)。
  改成霜打的枯草地才解决。判断标准只有一个 —— **把小羊贴上去在真实横幅里截图看**。
- 否定词压不住物件固有联想:`no fences` 挡不住 "meadow" 带出来的栅栏,得换主体措辞。
- 产物存 PNG 会很大(5 张 3.0MB)。无 alpha 的背景一律转 JPEG q88 → 368KB,肉眼无差。

## App Store Connect & screenshots

`tools/asc/README.md` has the full flow. Short version — six ASC locales
(`en-US`, `zh-Hans`, `zh-Hant`, `ja`, `ko`, `es-ES`), metadata single-sourced from
`tools/asc/app_metadata.json`:

```bash
./tools/screenshots/capture_raw.sh ja            # simulator → AppStoreScreenshots/ja/
python3 tools/screenshots/make_captioned.py ja   # + caption → ja-captioned/ (1284×2778)
python3 tools/asc/asc_upload.py --dump           # read-only: what's live now
python3 tools/asc/asc_upload.py --locales ja --dry-run --screenshots
python3 tools/asc/asc_upload.py --locales ja --screenshots
python3 tools/asc/asc_upload.py --locales ja --iap          # 内购显示名/描述
```

Always pass `--locales` — without it the script rewrites all six, including the live en-US/zh-Hans.
Version-level fields (description, keywords, screenshots) need an editable ASC version, so bump
`MARKETING_VERSION` past the released 2.2 before pushing them.

## Build & Run

```bash
xcodebuild -project NoNote.xcodeproj -scheme NoDiary \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## Xcode Project File

New `.swift` files use IDs in the `A1000000000000000000000X` / `B1000000000000000000000X` pattern in `project.pbxproj`. Next available: `A1000000000000000000002E` / `B1000000000000000000002E`. Group IDs: Models `C10000000000000000000002`, Services `C10000000000000000000003`, Views `C10000000000000000000004`.

## Future Features (Prioritized)

### High Priority
1. **"On This Day" Memories** — Show diary from same date in previous years on app open

### Lower Priority
2. **Yearly Wrapped** — Year-end summary card: entry count, longest streak, mood chart, top keywords. Shareable.

## Notes

- Old Mac app (AppKit, `~/Documents/work/private/NoDiary`) is deprecated — iOS version runs on Mac via iPad layout
- CloudKit production schema: `mood` (String) and `photos` (Asset List) fields were manually added and deployed
- Privacy policy: https://smartkiitos.com/nodairy/privacy/
