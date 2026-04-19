# Kadō — Roadmap

Plan of incremental versions. Each version must be usable end-to-end
by its author — that's the main scope definition criterion.

Estimates are for a solo workflow with Claude Code as pair programmer,
based on convergent Reddit accounts (2-4 weeks for an iOS MVP, 3
weeks for a production app by an experienced dev, etc.).

---

## v0.1 MVP — "I use Kadō every day"

**Objective**: usable daily by the author, with Kadō's philosophical
DNA (habit score, offline, privacy) in place from the start.

**Estimate**: 4-6 weeks.

### Data and domain
- [ ] SwiftData `Habit` model: id, name, icon, color, frequency,
      type (binary/counter/timer), createdAt, archivedAt
- [ ] SwiftData `Completion` model: habit relation, date, value
      (Double), note (optional String)
- [ ] `Frequency` type: `.daily`, `.daysPerWeek(Int)`,
      `.specificDays(Set<Weekday>)`, `.everyNDays(Int)`
- [ ] SwiftData migrations configured from now (VersionedSchema)

### Business logic
- [ ] **`HabitScoreCalculator`**: EMA-based, with exhaustive unit
      tests (see `habit-score.md`)
- [ ] `StreakCalculator`: current streak + best streak, with handling
      of non-daily frequencies
- [ ] `FrequencyEvaluator`: determines whether a habit is "due" on a
      given day

### Views
- [ ] **Today View**: list of habits due today, tap to complete
      (immediate haptic feedback)
- [ ] **Habit Detail View**: monthly calendar, streak, current habit
      score, completion history
- [ ] **New/Edit Habit View**: form with icon picker, color,
      frequency
- [ ] **Settings View** (minimal): about, iCloud sync on/off

### Infrastructure
- [ ] CloudKit sync opt-in, via SwiftData CloudKit container
- [ ] Full dark mode
- [ ] Dynamic Type tested up to XXXL
- [ ] EN localization (FR arrives in v1.0, strings prepared now via
      String Catalog)
- [ ] SwiftUI previews with realistic demo data

### Exit criteria for v0.1
- [ ] I've used it daily for 2 weeks with no blocking bugs
- [ ] Habit score is calculated correctly, verified by tests
- [ ] iCloud sync works between 2 devices
- [ ] No detectable memory leaks over a month of data

---

## v0.2 — Visible iOS-native

**Objective**: the iOS-native surfaces users see first — widgets, an
at-a-glance overview, notifications, frictionless data portability.

**Estimate**: 2-3 weeks.

### Widgets
- [ ] Small home screen widget: today's grid (5-6 habits max)
- [ ] Medium home screen widget: grid + progress
- [ ] Large home screen widget: weekly view
- [ ] Lock screen widget (rectangular, circular, inline)
- [ ] App Group configured for data sharing

### Multi-habit overview
- [ ] New "Overview" tab: habits × days matrix, all habits on a shared
      day axis (Loop / Way of Life pattern)
- [ ] Cells encode completion with habit-score shading, not binary
      checkmarks — keeps Kadō's score DNA visible at a glance
- [ ] Horizontal scroll back through history; sticky habit-name column
- [ ] Tap a cell to open the per-habit Detail for that date
- [ ] Dark mode, Dynamic Type, VoiceOver labels for every cell

### Notifications
- [ ] Reminders per habit, at fixed time
- [ ] Recurring reminders (mon-fri, daily, etc.)
- [ ] **Notification actions**: check/skip from the notification
      without opening the app
- [ ] Per-habit notification settings (disable, modify)

### Import / Export
- [ ] CSV export: one file per habit, or a consolidated one
- [ ] JSON export: documented, stable format (versioned schema)
- [ ] Generic CSV import (with column mapping)
- [ ] Import from a Kadō JSON export (round-trip tested)
- [ ] Import from Loop Habit Tracker (CSV format documented on Loop's
      side)

### CloudKit sync polish
- [ ] Live sync indicator (subscribe to
      `NSPersistentCloudKitContainer.eventChangedNotification` and
      surface "Syncing…", "Up to date", or "Error" in Settings)
- [ ] Real "Sync now" affordance — replaces v0.1's cosmetic
      pull-to-refresh once we have a real fetch hook

### Exit criteria for v0.2
- [ ] Widgets work on iOS 18 and update correctly after completion
- [ ] An export followed by an import restores 100% of the data
      (automated test)
- [ ] Notifications respect system settings (Focus, Do Not Disturb)
- [ ] Overview shows ≥30 days of history for all habits legibly on
      iPhone 16 Pro and iPad Air

---

## v0.3 — iOS depth and Apple Watch

**Objective**: deep Apple ecosystem integration, with the Apple Watch
app becoming a reason to install Kadō on its own.

**Estimate**: 3-4 weeks.

### App Intents and Siri
- [ ] `CompleteHabitIntent`: "Hey Siri, mark [habit] as done"
- [ ] `LogHabitValueIntent`: for counters/timers ("I drank 2 glasses
      of water")
- [ ] `GetHabitStatsIntent`: "What's my meditation streak?"
- [ ] Contextual Shortcuts suggestions (morning, evening)

### HealthKit
- [ ] Read-only HealthKit permission, granular
- [ ] Auto-completion based on Apple Health types: steps, exercise
      minutes, mindfulness, sleep, workouts
- [ ] Configurable mapping: a "Meditate 10 min" habit can be linked to
      mindfulMinutes with a threshold
- [ ] Clear UI to indicate a habit is auto-completed vs manual
- [ ] Score continues to work with auto-completion without distortion

### Live Activities
- [ ] Live Activity for habits with a running timer
- [ ] Dynamic Island compact + expanded
- [ ] Timer background persistence (respecting iOS limitations)

### Apple Watch
- [ ] Native watchOS app (SwiftUI + WatchKit)
- [ ] Today view: tappable list of due habits
- [ ] Circular complication (longest current streak)
- [ ] Rectangular complication (number of completed / total habits)
- [ ] Sync with iPhone via SwiftData + CloudKit (no custom
      WatchConnectivity unless needed)
- [ ] Haptic feedback on completion

### Exit criteria for v0.3
- [ ] I can complete a habit without taking my iPhone out of my pocket
- [ ] A morning run auto-logs via HealthKit before I open the app
- [ ] The watchOS complication is useful on the wrist, not just a
      gimmick

---

## v1.0 — Public launch

**Objective**: first-impression quality. App Store, polished GitHub
README, landing page, first wave of downloads.

**Estimate**: 2-3 weeks after v0.3.

### Final features
- [ ] Import from Streaks (format to reverse-engineer or document if
      no official export)
- [ ] Core themes: light, dark, sepia, high contrast
- [ ] Optional biometrics (Face ID / Touch ID) to open the app
- [ ] Habit archive with history preservation
- [ ] Categories/tags for organization
- [ ] Manual backup as `.kado` file (zipped JSON)
- [ ] Restore from a backup

### Localization
- [x] Complete native FR (not machine-translated) — **shipped in
      v0.2 stream**, see `docs/plans/2026-04/french-translations/`.
      Covers main app + widget extension (dual-catalog setup).
- [ ] Pseudo-locale IDE smoke test pass before App Store submission
- [ ] Accessibility: VoiceOver verified on every view, clear labels in
      EN and FR
- [ ] App Store screenshots in 2 languages

### Quality
- [ ] Unit test suite with >80% coverage on business logic
- [ ] UI tests on the 3-4 critical flows (create habit, complete, view
      detail, export)
- [ ] Manual smoke test on iPhone SE, iPhone 15, iPad, Apple Watch
- [ ] Privacy Nutrition Label filled honestly (nothing collected)

### Monetization
- [ ] Tip Jar (consumable or non-consumable IAP) without RevenueCat
      for simplicity
- [ ] No Pro tier at launch. Wait-and-see for 3 months, decide after.

### Communication
- [ ] GitHub README with screenshots, features, stack, philosophy
- [ ] Simple landing page (single HTML) on GitHub Pages
- [ ] Launch post on r/iOSProgramming, r/ClaudeAI (category "Built
      with Claude"), r/opensource, Hacker News (Show HN)
- [ ] Submission to AlternativeTo facing Streaks and Loop

### Exit criteria for v1.0
- [ ] App Store review passed first try (otherwise quick iteration)
- [ ] 100+ downloads in the first week
- [ ] Consistent user feedback on the habit score's value

---

## Post-v1.0 — to be decided after user listening

**To consider based on feedback**:
- Sharing a habit with a partner (via CloudKit shared database)
- Enriched completion notes (photos, mood)
- Advanced analyses: correlations between habits, seasonal trends
- Export to Obsidian (structured markdown format)
- URL schemes for third-party automation
- macOS app (Mac Catalyst or native SwiftUI)

**Do not do without proof of real need**:
- Multi-profiles on the same device
- Real-time collaboration between unrelated users
- Bidirectional calendar integration
- AI-assisted habit suggestions (contrary to privacy-first ethics)

---

## Prioritization under time constraints

If time runs short, here is the order of sacrifice (most to least
sacrificable):

1. ~~Import from Streaks (v1.0)~~ — sacrificable
2. ~~Advanced themes (v1.0)~~ — sacrificable
3. ~~Categories/tags (v1.0)~~ — can wait for post-launch
4. ~~Biometrics (v1.0)~~ — nice-to-have, not blocking

On the other hand, **non-sacrificable** at these stages:
- Habit score correctly implemented and tested (v0.1)
- CSV + JSON export working (v0.2)
- Native watchOS app (v0.3) — the big differentiator vs Teymia and
  Loop
- FR localization at v1.0 launch (a marketing and personal
  differentiator)
