# Kadō — Roadmap

Plan of incremental versions. Each version must be usable end-to-end
by its author — that's the main scope definition criterion.

Estimates are for a solo workflow with Claude Code as pair programmer,
based on convergent Reddit accounts (2-4 weeks for an iOS MVP, 3
weeks for a production app by an experienced dev, etc.).

---

## Current status (2026-04-19)

- **v0.1 MVP**: shipped — all scope items and exit criteria complete.
- **v0.2 "Visible iOS-native"**: largely shipped — widgets,
  multi-habit overview, notifications, CloudKit polish, and the
  JSON half of import/export done. CSV export, generic CSV import,
  and Loop-CSV import moved into a post-v0.2 follow-up.
- **French localization** (originally scheduled for v1.0) shipped
  early in the v0.2 stream — main app + widget extension, native
  translations.
- **App Store**: first public build submitted, currently in App
  Store review. TestFlight external beta also live.
- **Next**: v0.3 (App Intents, HealthKit, Live Activities, native
  Apple Watch).

---

## v0.1 MVP — "I use Kadō every day" ✅ shipped

**Objective**: usable daily by the author, with Kadō's philosophical
DNA (habit score, offline, privacy) in place from the start.

**Estimate**: 4-6 weeks.

### Data and domain
- [x] SwiftData `Habit` model: id, name, icon, color, frequency,
      type (binary/counter/timer), createdAt, archivedAt
- [x] SwiftData `Completion` model: habit relation, date, value
      (Double), note (optional String)
- [x] `Frequency` type: `.daily`, `.daysPerWeek(Int)`,
      `.specificDays(Set<Weekday>)`, `.everyNDays(Int)`
- [x] SwiftData migrations configured from now (VersionedSchema)

### Business logic
- [x] **`HabitScoreCalculator`**: EMA-based, with exhaustive unit
      tests (see `habit-score.md`)
- [x] `StreakCalculator`: current streak + best streak, with handling
      of non-daily frequencies
- [x] `FrequencyEvaluator`: determines whether a habit is "due" on a
      given day

### Views
- [x] **Today View**: list of habits due today, tap to complete
      (immediate haptic feedback)
- [x] **Habit Detail View**: monthly calendar, streak, current habit
      score, completion history
- [x] **New/Edit Habit View**: form with icon picker, color,
      frequency
- [x] **Settings View** (minimal): about, iCloud sync on/off

### Infrastructure
- [x] CloudKit sync opt-in, via SwiftData CloudKit container
- [x] Full dark mode
- [x] Dynamic Type tested up to XXXL
- [x] EN localization — string catalog populated (FR shipped early
      in the v0.2 stream)
- [x] SwiftUI previews with realistic demo data

### Exit criteria for v0.1
- [x] Used daily by the author through v0.2 development
- [x] Habit score is calculated correctly, verified by tests
- [x] iCloud sync works between 2 devices (verified on iPhone 17 Pro
      + iPad Air M4)
- [x] No detectable memory leaks over a month of data

---

## v0.2 — Visible iOS-native ✅ shipped (CSV deferred)

**Objective**: the iOS-native surfaces users see first — widgets, an
at-a-glance overview, notifications, frictionless data portability.

**Estimate**: 2-3 weeks.

### Widgets
- [x] Small home screen widget: today's grid (5-6 habits max)
- [x] Medium home screen widget: grid + progress
- [x] Large home screen widget: weekly view
- [x] Lock screen widget (rectangular, circular, inline)
- [x] App Group configured for data sharing

### Multi-habit overview
- [x] New "Overview" tab: habits × days matrix, all habits on a shared
      day axis (Loop / Way of Life pattern)
- [x] Cells encode completion with habit-score shading, not binary
      checkmarks — keeps Kadō's score DNA visible at a glance
- [x] Horizontal scroll back through history; sticky habit-name column
- [x] Tap a cell to open the per-habit Detail for that date
- [x] Dark mode, Dynamic Type, VoiceOver labels for every cell

### Notifications
- [x] Reminders per habit, at fixed time
- [x] Recurring reminders (mon-fri, daily, etc.)
- [x] **Notification actions**: check/skip from the notification
      without opening the app
- [x] Per-habit notification settings (disable, modify)

### Import / Export
- [x] JSON export: documented, stable format (versioned schema)
- [x] Import from a Kadō JSON export (round-trip tested)
- [ ] CSV export: one file per habit, or a consolidated one —
      **deferred to a post-v0.2 follow-up**
- [ ] Generic CSV import (with column mapping) — **deferred**
- [ ] Import from Loop Habit Tracker — **deferred to v1.0** (see
      v1.0 "Final features")

### CloudKit sync polish
- [x] Live sync indicator (subscribe to
      `NSPersistentCloudKitContainer.eventChangedNotification` and
      surface "Syncing…", "Up to date", or "Error" in Settings)
- [x] Real "Sync now" affordance — replaces v0.1's cosmetic
      pull-to-refresh now that we have a real fetch hook

### Exit criteria for v0.2
- [x] Widgets work on iOS 18 and update correctly after completion
- [x] An export followed by an import restores 100% of the data
      (automated test) — JSON path covered
- [x] Notifications respect system settings (Focus, Do Not Disturb)
- [x] Overview shows ≥30 days of history for all habits legibly on
      iPhone 17 Pro and iPad Air M4

---

## v0.3 — iOS depth and Apple Watch (next)

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

**Status (2026-04-19)**: the first public build is **in App Store
review**, ahead of the nominal v0.3 gate. The scope below still
reflects the target for the 1.0 label — a few items (biometrics,
themes, Streaks import) are not in the review build and will ship
in a follow-up update before the final 1.0 marketing push.

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
- [x] App Store screenshots in 2 languages (6.7" iPhone + 13" iPad,
      EN + FR) — captured in `docs/screenshots/`

### Quality
- [ ] Unit test suite with >80% coverage on business logic
- [ ] UI tests on the 3-4 critical flows (create habit, complete, view
      detail, export)
- [ ] Manual smoke test on iPhone SE, iPhone 15, iPad, Apple Watch
- [x] Privacy Nutrition Label filled honestly (nothing collected) —
      submitted with first review build

### Monetization
- [ ] Tip Jar (consumable or non-consumable IAP) without RevenueCat
      for simplicity
- [ ] No Pro tier at launch. Wait-and-see for 3 months, decide after.

### Communication
- [x] GitHub README with screenshots, features, stack, philosophy
- [ ] Simple landing page (single HTML) on GitHub Pages
- [ ] Launch post on r/iOSProgramming, r/ClaudeAI (category "Built
      with Claude"), r/opensource, Hacker News (Show HN)
- [ ] Submission to AlternativeTo facing Streaks and Loop

### Exit criteria for v1.0
- [ ] App Store review passed (first build submitted 2026-04-19 —
      awaiting outcome)
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
- JSON export / import round-trip (v0.2) — CSV was reclassified
  as a post-v0.2 follow-up during the build
- Native watchOS app (v0.3) — the big differentiator vs Teymia and
  Loop
- FR localization at v1.0 launch (a marketing and personal
  differentiator)
