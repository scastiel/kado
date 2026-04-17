# Kadō — Product vision

## One-line pitch

**Kadō: the elegance of Streaks, the algorithm of Loop, and your privacy
stays yours.**

A native iOS habit tracker, open source, offline-first, with a non-binary
habit score algorithm (inspired by Loop Habit Tracker) and first-class
Apple Watch/HealthKit integration. No subscription. No telemetry. No
lock-in.

## Why this project exists

The iOS habit tracking market is dominated either by proprietary
subscription apps (Habitify, Productive, Way of Life), or by excellent
but closed ones (Streaks — $5.99 one-time, the reference). On the open
source side, the worldwide reference is **Loop Habit Tracker**, but it
is exclusively Android/F-Droid. No open source iOS habit tracker exists
with a modern, complete execution.

Market signal:
- On AlternativeTo, the top-rated alternative to almost every
  commercial habit tracker is Loop Habit Tracker — precisely because
  it's free, open source, privacy-focused, lightweight.
- Users regularly voice frustration with subscriptions (average price
  up 36% year over year) and lack of export.
- Since 2022, Apple allows developers to raise subscription prices
  without explicit consent — worsening the sense of lost control.

Kadō fills that gap.

## The three reference competitors

### Streaks (Crunchy Bagel) — the commercial reference
- **Price**: $5.99 one-time, no subscription.
- **Strengths**: Apple Design Award. Deep HealthKit (steps, exercise,
  sleep, mindfulness, medications). Native Apple Watch with
  complications. Live Activities. Siri Shortcuts. Widgets. No account
  required.
- **Weaknesses**: closed source, 24 habit maximum, no structured
  export, binary streak algorithm (one missed day = reset).

### Loop Habit Tracker (iSoron) — the open source reference
- **License**: GPLv3. 9.6k GitHub stars, 1.1k forks, 69 contributors.
- **Strengths**: non-binary **habit score** algorithm (exponential
  moving average) — the philosophical killer feature that distinguishes
  "I'm building a long-term habit" from "I must not break my chain."
  CSV and SQLite export. Widgets. No limits, no IAP, all features free.
  Fully offline.
- **Weaknesses**: Android/F-Droid only. No native iOS. No HealthKit.
  GPLv3 license incompatible with App Store — so the code itself isn't
  reusable, only the **ideas**.

### Teymia Habit (amanbayserkeev0377) — the modern iOS stack
- **License**: MIT. 12 stars, personal learning project.
- **Strengths**: exemplary modern stack (SwiftUI + `@Observable` +
  SwiftData + CloudKit + ActivityKit + WidgetKit). Live Activities and
  Dynamic Island. Concurrent counters + timers. 16 languages. On App
  Store. It's the architectural skeleton we draw inspiration from.
- **Weaknesses**: aggressive freemium model (3 habits on free tier),
  no HealthKit, no Apple Watch, no habit score, export as Pro only.

## The competitive gap table

| Feature                         | Streaks | Teymia | Loop    | Kadō |
|---------------------------------|:-------:|:------:|:-------:|:----:|
| **Non-binary habit score**      |    ❌   |   ❌   |    ✅   |  ✅  |
| **Flexible schedules**          |    ✅   |   ✅   |    ✅   |  ✅  |
| **Counters + timers**           |    ✅   |   ✅   |    ❌   |  ✅  |
| **No habit limit**              | ~(24)   |❌(3free)|    ✅   |  ✅  |
| **Home widgets**                |    ✅   |   ✅   |    ✅   |  ✅  |
| **Lock screen widgets**         |    ✅   |   ?    |    ❌   |  ✅  |
| **Live Activity / Dyn. Island** |    ✅   |   ✅   |    ❌   |  ✅  |
| **Native Apple Watch**          |    ✅   |   ❌   |    ❌   |  ✅  |
| **HealthKit auto-completion**   |    ✅   |   ❌   |    ❌   |  ✅  |
| **Siri / App Intents**          |    ✅   |   ~    |    ❌   |  ✅  |
| **CloudKit sync**               |    ✅   |   ✅   |    ❌   |  ✅  |
| **Export CSV/JSON (core)**      |    ~    |💰Pro   |    ✅   |  ✅  |
| **Import from competitors**     |    ❌   |   ❌   |    ❌   |  ✅  |
| **Biometrics**                  |    ✅   |   ✅   |    ❌   |  ✅  |
| **Open source**                 |    ❌   |  ✅MIT |  ✅GPL  | ✅MIT|
| **Price**                       |$5.99once|Freemium|Free    |Free+Tip|

## Kadō's differentiators

1. **Loop's habit score on native iOS.** Nobody has done it. We import
   Loop's anti-guilt philosophy into a modern iOS ecosystem.

2. **First-class native Apple Watch.** Teymia doesn't have it, Loop
   doesn't exist on iOS. Streaks has it but is proprietary. The
   phone/watch/widget trio is the true iOS promise.

3. **HealthKit + continuous habit score.** Streaks does
   auto-completion but feeds a binary streak. Kadō feeds a continuous
   score — a 3km run on a Tuesday adds strength to the habit without
   "repairing" a missed day artificially.

4. **Import from Streaks, Loop, generic CSV.** Nobody makes
   competitor migration easy. This is the anti-lock-in statement.

5. **Export in core, not Pro.** Teymia puts export in Pro —
   inconsistent with a privacy-first positioning. In Kadō, you can
   leave at any time with all your data.

6. **Open source MIT with real maintenance.** Teymia sits at 12 stars
   with one person. We can build a real community.

7. **Native FR localization.** Not machine translation, an authentic
   Québécois/French voice. Rare on the App Store.

## Business model

### Principle
No subscription. Ever.

### Envisioned structure (to validate by v1.0)
- **Kadō (free)**: all core features. All of them. No disguised
  "feature gating."
- **Kadō Pro (one-time purchase, ~$5-10)** — optional:
  - Advanced themes (not the basics: light/dark/sepia stay free)
  - Enriched custom icons
  - Maybe: unlimited categories, multi-profiles
- **Tip Jar**: for those who want to support without needing Pro.

### Principles
- A free user gets a 100% functional app. Pro adds comfort, not
  fundamentals.
- No features get taken away from free after the fact.
- Data belongs to the user, always, regardless of version.

## Explicit non-goals

What Kadō **will not be**:
- A wellness coach with programs and advice.
- A social app with followers, likes, community challenges.
- An all-in-one productivity tool (tasks + habits + calendar).
- A Habitica clone with RPG gamification.
- A cross-platform app. iOS/watchOS/iPadOS only, by choice.

## Identity

- **Voice**: sober, factual, no emotional pressure. We don't shame,
  we inform. Close to the spirit of Apple Journal, far from
  Duolingo's.
- **Design**: Apple minimalism, adaptive, accessible. No 3D
  illustrations, no aggressive gradients. Beauty comes from precision.
- **Code name**: Kadō (稼働, "in operation"). The final name is to
  be decided before v1.0.
