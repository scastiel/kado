# Kadō — Roadmap

Plan of incremental versions. Each version must be usable end-to-end
by its author — that's the main scope definition criterion.

The pre-launch sections (v0.1 → v1.0) are kept as a record of what was
scoped and what actually shipped. Everything after v1.0 is tracked as
the App Store release it went out in.

---

## Current status (2026-09-05)

- **Shipping on the App Store: version 1.7** (build 14). Seven
  updates since the public launch, all free, no subscription.
- **v0.1 MVP**, **v0.2 "Visible iOS-native"**, and **v1.0 public
  launch**: shipped.
- **v0.3 "iOS depth"**: partially shipped, partially descoped. App
  Intents / Siri shipped in 1.1. Live Activities remain planned.
  **Apple Watch and HealthKit are descoped** — see
  [Descoped](#descoped) below.
- **French localization** (originally v1.0) shipped early, in the
  v0.2 stream.
- **Next**: Live Activities + Dynamic Island for timer habits, then
  the remaining v1.x polish items (themes, biometrics, categories,
  backup files).

---

## Post-launch releases (shipped)

| Version | Theme | Shipped |
|---|---|---|
| **1.0** | First public release | Score, Today / Overview / Detail, widgets, iCloud sync, reminders, JSON export, EN + FR |
| **1.1** | Siri and editable history | Siri + Shortcuts (3 intents); edit past days from the detail calendar; Today refreshes correctly after midnight |
| **1.2** | Notes, backdate, navigation | Per-day completion notes; completions before a habit's creation date; month navigation in the calendar |
| **1.3** | Order and asking nicely | Drag-to-reorder habits on Today (order syncs via iCloud); a one-time, dismissable review prompt |
| **1.4** | Sync reliability | Fixed an iPad crash shortly after enabling iCloud sync; Settings now reports sync failures honestly instead of always "active" |
| **1.5** | Support Kadō | Tip Jar (StoreKit 2, no third-party SDK). Optional, unlocks nothing |
| **1.6** | Late nights and fairer scores | "Day starts at" rollover hour (up to 6 AM); days-per-week scoring fix; off-schedule completions now visible in Overview |
| **1.7** | Portable backups | CSV export and import with a lossless round-trip; "every N days" re-anchors on each completion instead of a fixed grid |

Per-release copy (EN + FR) lives in `docs/app-store-connect.md`; the
copy that actually ships is in `docs/app-store/metadata/`.

---

## Descoped

Scope that was planned and has been **removed** from the roadmap. Not
"later" — removed, and would only come back on evidence of real
demand.

### Native Apple Watch app — descoped 2026-09-05

Originally the headline of v0.3 and listed as non-sacrificable (the
"big differentiator vs Teymia and Loop"). **No user has asked for it
since launch.** It was a competitive-analysis assumption, not a
demand signal, and it carries a large ongoing cost: a second target,
a second UI to keep localized and accessible, complications, and a
sync story to debug on a device that is awkward to debug on.

Was scoped as: watchOS app, Today list, circular + rectangular
complications, CloudKit sync, haptics.

### HealthKit auto-completion — descoped 2026-09-05

Same reasoning, plus a philosophical one: auto-completion sits
uneasily with a tracker whose whole premise is that *you* decide what
counts. It also adds a permission prompt, a privacy surface to
explain, and a class of "why did my score change on its own?"
support questions — for a feature nobody has requested.

Was scoped as: read-only granular permission, auto-completion from
steps / exercise minutes / mindfulness / sleep / workouts,
configurable thresholds, a manual-vs-auto indicator, and score
neutrality under auto-completion.

Reconsider either if: users file issues asking for it, reviews
mention its absence, or a concrete workflow appears that the manual
flow genuinely can't serve.

---

## Next

### Live Activities (planned)
- [ ] Live Activity for habits with a running timer
- [ ] Dynamic Island compact + expanded
- [ ] Timer background persistence (respecting iOS limitations)

### Remaining v1.x polish
- [ ] Core themes: light, dark, sepia, high contrast
- [ ] Optional biometrics (Face ID / Touch ID) to open the app
- [ ] Categories / tags for organization
- [ ] Manual backup as `.kado` file (zipped JSON), and restore
- [ ] Import from Loop Habit Tracker (CSV) — the generic CSV import
      shipped in 1.7 is most of the machinery
- [ ] Import from Streaks (format to reverse-engineer, or document if
      there is no official export)

### Quality
- [ ] Unit test suite with >80% coverage on business logic
- [x] UI tests on the critical flows — `KadoUITests` target added,
      `make e2e` runs it
- [ ] Pseudo-locale IDE smoke test pass
- [ ] Manual smoke test on iPhone SE, iPhone 15, iPad

---

## v0.1 MVP — "I use Kadō every day" ✅ shipped

**Objective**: usable daily by the author, with Kadō's philosophical
DNA (habit score, offline, privacy) in place from the start.

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

## v0.2 — Visible iOS-native ✅ shipped

**Objective**: the iOS-native surfaces users see first — widgets, an
at-a-glance overview, notifications, frictionless data portability.

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
- [x] Off-schedule completions rendered instead of hidden as rest
      days — shipped in 1.6

### Notifications
- [x] Reminders per habit, at fixed time
- [x] Recurring reminders (mon-fri, daily, etc.)
- [x] **Notification actions**: check/skip from the notification
      without opening the app
- [x] Per-habit notification settings (disable, modify)

### Import / Export
- [x] JSON export: documented, stable format (versioned schema)
- [x] Import from a Kadō JSON export (round-trip tested)
- [x] CSV export — shipped in 1.7
- [x] CSV import, round-trip tested against the export — shipped in
      1.7
- [ ] Import from Loop Habit Tracker — still open, see
      [Next](#next)

### CloudKit sync polish
- [x] Live sync indicator (subscribe to
      `NSPersistentCloudKitContainer.eventChangedNotification` and
      surface "Syncing…", "Up to date", or "Error" in Settings)
- [x] Real "Sync now" affordance — replaces v0.1's cosmetic
      pull-to-refresh now that we have a real fetch hook
- [x] Surface sync *failures* rather than always reporting active —
      shipped in 1.4

### Exit criteria for v0.2
- [x] Widgets work on iOS 18 and update correctly after completion
- [x] An export followed by an import restores 100% of the data
      (automated test) — JSON and CSV paths both covered
- [x] Notifications respect system settings (Focus, Do Not Disturb)
- [x] Overview shows ≥30 days of history for all habits legibly on
      iPhone 17 Pro and iPad Air M4

---

## v0.3 — iOS depth ✅ partially shipped, partially descoped

**Objective, as written**: deep Apple ecosystem integration, with the
Apple Watch app becoming a reason to install Kadō on its own.

**Outcome**: the App Intents track shipped in 1.1 and is used. The
Apple Watch and HealthKit tracks were [descoped](#descoped) in
September 2026 for lack of demand. Live Activities is the only part
still planned.

### App Intents and Siri ✅ shipped in 1.1
- [x] `CompleteHabitIntent`: "Hey Siri, mark [habit] as done"
- [x] `LogHabitValueIntent`: for counters/timers ("I drank 2 glasses
      of water")
- [x] `GetHabitStatsIntent`: "What's my meditation streak?"
- [x] Contextual Shortcuts suggestions (`suggestedInvocationPhrase`
      via `AppShortcutsProvider`; morning/evening predicates via
      `ShortcutTile` deferred)

### HealthKit ❌ descoped
See [Descoped](#descoped).

### Live Activities — planned
See [Next](#next).

### Apple Watch ❌ descoped
See [Descoped](#descoped).

---

## v1.0 — Public launch ✅ shipped

**Objective**: first-impression quality. App Store, polished GitHub
README, landing page, first wave of downloads.

The first public build was submitted 2026-04-19 and approved. The
items below that were not in the launch build shipped across 1.1–1.7,
noted inline.

### Final features
- [x] **"Day starts at" setting** — a configurable day-rollover hour
      (midnight…6 AM, default midnight) so late-night logging keeps
      the one-tap Today flow. One injected `DayBoundary` resolves the
      logical day for every surface; completions are normalised on
      write, so changing the setting never re-buckets history.
      Shipped in 1.6, see `docs/plans/2026-08/day-start-hour/`.
- [x] Habit archive with history preservation
- [ ] Import from Streaks — still open
- [ ] Core themes: light, dark, sepia, high contrast — still open
- [ ] Optional biometrics (Face ID / Touch ID) — still open
- [ ] Categories/tags for organization — still open
- [ ] Manual backup as `.kado` file, and restore — still open

### Localization
- [x] Complete native FR (not machine-translated) — **shipped in
      v0.2 stream**, see `docs/plans/2026-04/french-translations/`.
      Covers main app + widget extension (dual-catalog setup).
- [ ] Accessibility: VoiceOver verified end-to-end on every view, in
      EN and FR (labels are in place throughout; the systematic pass
      is still open)
- [x] App Store screenshots in 2 languages (6.7" iPhone + 13" iPad,
      EN + FR) — regenerated by `make screenshots`, captures in
      `docs/app-store/screenshots/` and the framed images to upload in
      `docs/app-store/marketing/`. See `docs/app-store/README.md`.
- [x] Listing copy and screenshots pushed from the command line —
      `make listing`, no retyping into App Store Connect
- [ ] Pseudo-locale IDE smoke test pass

### Quality
- [x] UI tests on the critical flows — `KadoUITests`, `make e2e`
- [x] Privacy Nutrition Label filled honestly (nothing collected)
- [ ] Unit test suite with >80% coverage on business logic
- [ ] Manual smoke test on iPhone SE, iPhone 15, iPad

### Monetization
- [x] Tip Jar (StoreKit 2 IAP, no RevenueCat) — shipped in 1.5, with
      an earned-it nudge at the bottom of Today
- [x] No Pro tier at launch — still the position

### Communication
- [x] GitHub README with screenshots, features, stack, philosophy
- [x] Landing page on GitHub Pages — `site/`, live at getkado.app,
      EN + FR, screenshots regenerated from the same captures as the
      listing
- [ ] Launch post on r/iOSProgramming, r/ClaudeAI (category "Built
      with Claude"), r/opensource, Hacker News (Show HN)
- [ ] Submission to AlternativeTo facing Streaks and Loop

### Exit criteria for v1.0
- [x] App Store review passed
- [ ] 100+ downloads in the first week
- [ ] Consistent user feedback on the habit score's value

---

## Later — to be decided after user listening

**To consider based on feedback**:
- **Rollover-aware widget refresh** — `SnapshotTimelineProvider` asks
  for a reload every hour and the snapshot is only rebuilt on app
  mutation, so a widget can show a stale "today" across a day
  boundary. Pre-existing (true at midnight today), surfaced while
  building the day-start hour. See
  `docs/plans/2026-08/day-start-hour/compound.md`.
- **iCloud-sync the "Day starts at" hour** via
  `NSUbiquitousKeyValueStore` so iPhone and iPad don't each need it
  set. Device-local today; disagreement causes no corruption, since a
  completion's day is fixed by whichever device wrote it.
- Sharing a habit with a partner (via CloudKit shared database)
- Enriched completion notes (photos, mood)
- Advanced analyses: correlations between habits, seasonal trends
- Export to Obsidian (structured markdown format)
- URL schemes for third-party automation
- macOS app (Mac Catalyst or native SwiftUI)

**Do not do without proof of real need**:
- Native Apple Watch app and HealthKit auto-completion (see
  [Descoped](#descoped))
- Multi-profiles on the same device
- Real-time collaboration between unrelated users
- Bidirectional calendar integration
- AI-assisted habit suggestions (contrary to privacy-first ethics)

---

## Prioritization under time constraints

Order of sacrifice for what remains (most to least sacrificable):

1. Import from Streaks — sacrificable
2. Advanced themes — sacrificable
3. Categories/tags — can wait
4. Biometrics — nice-to-have, not blocking
5. Live Activities — worth doing, but only timer habits benefit

**Non-sacrificable**, at any stage:
- The habit score, correctly implemented and tested
- Lossless export / import round-trips (JSON and CSV)
- FR parity with EN on every user-facing string
- The privacy position: no telemetry, no third-party SDK, no account

The one entry that used to sit in this list — "native watchOS app,
the big differentiator" — is the cautionary tale. It was
non-sacrificable on the strength of a competitor comparison, and
nobody ever asked for it. Demand, not differentiation on paper.
