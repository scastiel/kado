# App Store Connect metadata

All copy Kadō needs to enter in App Store Connect — TestFlight first,
public App Store listing prepared for v1.0. Drafts in English and
native French. Tone follows `docs/PRODUCT.md`: sober, factual, no
emotional pressure, tutoiement in French.

**Brand**: `Kadō` (macron preserved everywhere — App Store Connect
supports it).

---

## Quick reference — field limits

| Field                  | Limit          | Where           | Status  |
|------------------------|----------------|-----------------|---------|
| App Name               | 30 chars       | App Information | ✅ 4    |
| Subtitle               | 30 chars       | App Information | ✅ 28   |
| Promotional Text       | 170 chars      | Version (any)   | ✅ <170 |
| Description            | 4000 chars     | Version (any)   | ✅ <4k  |
| Keywords               | 100 chars      | Version (any)   | ✅ <100 |
| What's New             | 4000 chars     | Version (any)   | ✅ <4k  |
| Support URL            | required URL   | App Information | GitHub  |
| Marketing URL          | optional URL   | App Information | GitHub  |
| Privacy Policy URL     | required URL   | App Information | GitHub  |
| Beta Description       | ~4000 chars    | TestFlight      | ✅      |
| What to Test           | ~4000 chars    | TestFlight      | ✅      |
| Beta Feedback Email    | email          | TestFlight      | ✅      |

Promotional Text and What's New can be updated **without** a new
review — useful to tweak messaging between builds.

---

## App Information (one-time setup)

### Name

> Kadō

### Subtitle — EN

> Private habits, honest score.

(29 chars)

### Subtitle — FR

> Habitudes privées, score juste.

(31 chars — one char over, alt below if needed)

Fallback FR (≤30): `Suivi d'habitudes privé et juste.` (33 — also
over). Safer fallback: `Habitudes privées et honnêtes.` (30).

### Primary Category

> Health & Fitness

### Secondary Category

> Productivity

### Content Rights
- **Does your app contain, display, or access third-party content?** No.

### Age Rating
All answers `None` → Final rating **4+**.

- Cartoon or Fantasy Violence: None
- Realistic Violence: None
- Sexual Content or Nudity: None
- Profanity or Crude Humor: None
- Alcohol, Tobacco, or Drug Use or References: None
- Mature/Suggestive Themes: None
- Horror/Fear Themes: None
- Prolonged Graphic or Sadistic Realistic Violence: None
- Gambling: None
- Unrestricted Web Access: No
- Medical/Treatment Information: No
- Contests: No
- User-Generated Content: No

### Support URL

> https://github.com/scastiel/kado

### Marketing URL (optional)

> https://github.com/scastiel/kado

(Swap to the landing page once `docs/ROADMAP.md` v1.0 landing ships.)

### Privacy Policy URL

> https://github.com/scastiel/kado/blob/main/PRIVACY.md

**Action item**: create `PRIVACY.md` at repo root before first
external TestFlight group. Content is short — we collect nothing.
Draft below in the Privacy Policy section.

### Copyright

> © 2026 Sébastien Castiel

---

## TestFlight metadata (fill this first)

### Beta App Feedback Email

> sebastien@castiel.me

### Marketing URL (TestFlight)

> https://github.com/scastiel/kado

### Privacy Policy URL (TestFlight)

> https://github.com/scastiel/kado/blob/main/PRIVACY.md

### License Agreement (TestFlight)
Accept the default **Apple Standard EULA** — no custom agreement
needed for a free, open-source app.

### Beta App Description — EN

> Kadō is a privacy-first habit tracker for iPhone and iPad.
>
> Instead of a binary streak that resets the moment you miss a day,
> Kadō uses a non-binary habit score — so your progress reflects
> real, long-term consistency without the all-or-nothing pressure.
>
> Offline-first, open source (MIT), no account required. Your data
> lives on your device and optionally syncs through your personal
> iCloud.
>
> This is an early beta. Thanks for helping shape it!

### Beta App Description — FR

> Kadō est un suivi d'habitudes privé pour iPhone et iPad.
>
> Plutôt qu'une série classique qui se remet à zéro dès que tu
> manques un jour, Kadō utilise un score d'habitude non-binaire —
> ton progrès reflète la régularité réelle sur la durée, sans la
> pression du tout-ou-rien.
>
> Hors-ligne d'abord, open source (MIT), aucun compte requis. Tes
> données restent sur ton appareil et peuvent se synchroniser via
> ton iCloud personnel.
>
> C'est une bêta précoce. Merci de m'aider à la façonner !

### What to Test — EN

> Thanks for trying Kadō!
>
> Priority areas for feedback:
>
> • Create a few habits with different frequencies (daily, N days
>   per week, specific days, every N days) and see how the habit
>   score evolves over a week.
> • Tap a habit on the Today view to complete it. Tap again to
>   undo. Long-press for partial / notes / timer (depending on
>   habit type).
> • Open the Habit Detail screen and explore the monthly calendar,
>   streak, and score-info popover (the "i" button next to the
>   score).
> • Try the Overview tab — the habits × days matrix.
> • Add the Kadō widgets to your Home screen and Lock screen. Check
>   they update after completing a habit.
> • Set up a few reminders (per-habit) and confirm they fire and
>   that the quick actions on the notification work.
> • Export your data (Settings → Data → Export JSON / CSV), delete
>   a habit, and re-import to verify the round-trip.
> • Switch your iPhone language to French and sanity-check the
>   translations feel natural.
> • Turn on iCloud sync (Settings) and check a second device picks
>   up your habits.
>
> Known gaps in this build (coming later):
> • Apple Watch companion app
> • HealthKit auto-completion
> • Siri Shortcuts / App Intents for full hands-free logging
> • Import from Streaks / Loop
>
> Report anything odd — UI, copy, algorithm, sync — by replying to
> the TestFlight invitation email or via GitHub Issues.

### What to Test — FR

> Merci de tester Kadō !
>
> Zones prioritaires pour les retours :
>
> • Crée quelques habitudes avec différentes fréquences
>   (quotidienne, N jours par semaine, jours précis, tous les N
>   jours) et observe l'évolution du score sur une semaine.
> • Tape une habitude dans la vue Aujourd'hui pour la compléter.
>   Tape à nouveau pour annuler. Appui long pour saisie partielle /
>   note / minuteur (selon le type d'habitude).
> • Ouvre le détail d'une habitude et explore le calendrier
>   mensuel, la série et la popover d'info sur le score (le "i" à
>   côté du score).
> • Essaie l'onglet Vue d'ensemble — la matrice habitudes × jours.
> • Ajoute les widgets Kadō à ton écran d'accueil et à ton écran
>   verrouillé. Vérifie qu'ils se mettent à jour après une
>   complétion.
> • Configure quelques rappels (par habitude) et vérifie qu'ils se
>   déclenchent et que les actions rapides sur la notification
>   fonctionnent.
> • Exporte tes données (Réglages → Données → Export JSON / CSV),
>   supprime une habitude et réimporte pour valider l'aller-retour.
> • Passe ton iPhone en français et vérifie que les traductions
>   sonnent naturellement.
> • Active la synchronisation iCloud (Réglages) et vérifie qu'un
>   second appareil récupère bien tes habitudes.
>
> Manques connus dans cette version (à venir) :
> • Application compagnon Apple Watch
> • Auto-complétion HealthKit
> • Raccourcis Siri / App Intents pour la saisie mains libres
> • Import depuis Streaks / Loop
>
> Remonte tout ce qui semble bizarre — interface, textes,
> algorithme, sync — en répondant à l'invitation TestFlight ou via
> GitHub Issues.

### Beta App Review — contact info
Automatic review is required the first time an external group is
added. Use:

- **First name**: Sébastien
- **Last name**: Castiel
- **Phone**: (your personal number)
- **Email**: `sebastien@castiel.me`
- **Demo account**: *not required* — Kadō has no login.
- **Notes**:

  > Kadō requires no sign-in. Launch the app and tap "Get started"
  > to create habits. Optional features to exercise: tap the "+" to
  > create a habit, tap a habit row to complete it, open Settings →
  > Data for export/import, enable iCloud sync from Settings. Source
  > code: https://github.com/scastiel/kado (MIT license).

---

## App Store listing (public launch — v1.0, draft)

### Promotional Text — EN (170 chars)

> Build long-term habits without the all-or-nothing pressure of
> streaks. Non-binary score, private by design, open source, no
> subscription. Yours to keep.

(166 chars)

### Promotional Text — FR (170 chars)

> Construis des habitudes durables sans la pression tout-ou-rien
> des séries. Score non-binaire, privé par design, open source,
> sans abonnement.

(147 chars)

### Description — EN

> Kadō is a mindful habit tracker that gives you a clear, honest
> picture of how you're building your routines — without the
> all-or-nothing guilt of a streak counter.
>
> ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
> A HABIT SCORE, NOT JUST A STREAK
> ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
>
> Kadō's core algorithm rewards long-term consistency. One missed
> day doesn't wipe your progress. A strong stretch matters more
> than a perfect one. You see the trend, not a fragile chain.
>
> ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
> PRIVATE BY DESIGN
> ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
>
> • No account required
> • No analytics, no telemetry, no advertising SDKs
> • No third-party services — only Apple frameworks
> • Your data lives on your device
> • Optional sync through your own iCloud (never on our servers)
>
> ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
> NATIVE TO APPLE
> ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
>
> • Universal app — iPhone and iPad
> • Home Screen widgets in three sizes
> • Lock Screen widgets (rectangular, circular, inline)
> • Rich monthly calendar with history
> • Full Dark Mode and Dynamic Type support
> • VoiceOver labels on every surface
>
> ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
> YOURS TO KEEP
> ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
>
> • CSV and JSON export in one tap
> • Import from Kadō backups (round-trip tested)
> • Source code on GitHub under the MIT license
> • No subscription, ever — optional Tip Jar if you want to
>   support development
>
> ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
> FLEXIBLE SCHEDULES
> ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
>
> • Daily habits
> • N days per week (e.g. 4 times a week)
> • Specific weekdays (e.g. Mon / Wed / Fri)
> • Every N days (e.g. every 3 days)
> • Binary, counter, or timer habit types
>
> ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
> BUILT IN THE OPEN
> ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
>
> Kadō is built in public. Browse the roadmap, file issues, or
> send a pull request — github.com/scastiel/kado.
>
> Localized in English and native French (not machine-translated).

### Description — FR

> Kadō est un suivi d'habitudes réfléchi qui t'offre un regard
> clair et honnête sur la façon dont tu construis tes routines —
> sans la culpabilité tout-ou-rien d'un compteur de série.
>
> ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
> UN SCORE, PAS SEULEMENT UNE SÉRIE
> ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
>
> L'algorithme de Kadō récompense la régularité sur la durée. Un
> jour manqué n'efface pas ton progrès. Une longue phase solide
> compte davantage qu'une phase parfaite. Tu vois la tendance, pas
> une chaîne fragile.
>
> ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
> PRIVÉ PAR DESIGN
> ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
>
> • Aucun compte requis
> • Aucune analytique, aucune télémétrie, aucun SDK publicitaire
> • Aucun service tiers — uniquement les frameworks Apple
> • Tes données restent sur ton appareil
> • Synchronisation optionnelle via ton propre iCloud (jamais sur
>   nos serveurs)
>
> ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
> NATIF APPLE
> ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
>
> • Application universelle — iPhone et iPad
> • Widgets d'écran d'accueil en trois tailles
> • Widgets d'écran verrouillé (rectangulaire, circulaire, inline)
> • Calendrier mensuel riche avec historique
> • Mode sombre complet et support Dynamic Type
> • Libellés VoiceOver sur chaque écran
>
> ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
> TES DONNÉES T'APPARTIENNENT
> ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
>
> • Export CSV et JSON en un geste
> • Import depuis les sauvegardes Kadō (aller-retour testé)
> • Code source sur GitHub sous licence MIT
> • Aucun abonnement, jamais — Tip Jar optionnel si tu veux
>   soutenir le développement
>
> ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
> HORAIRES FLEXIBLES
> ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
>
> • Habitudes quotidiennes
> • N jours par semaine (ex. 4 fois par semaine)
> • Jours précis (ex. lun / mer / ven)
> • Tous les N jours (ex. tous les 3 jours)
> • Types binaire, compteur ou minuteur
>
> ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
> CONSTRUIT À LA VUE DE TOUS
> ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
>
> Kadō est développé publiquement. Parcours la feuille de route,
> ouvre des issues, propose une pull request —
> github.com/scastiel/kado.
>
> Localisé en anglais et en français natif (pas de traduction
> automatique).

### Keywords — EN (100 chars, comma-separated, no spaces after commas)

> habit,tracker,streak,routine,goals,productivity,health,watch,widget,privacy,open source,loop

(94 chars)

Do not repeat words already in the app name or title. Do not use
plurals and singulars together — App Store Search handles
stemming.

### Keywords — FR (100 chars)

> habitude,suivi,routine,série,objectif,productivité,santé,widget,confidentialité,open source

(94 chars)

### What's New — first public release (EN)

> First public release of Kadō.
>
> • Non-binary habit score — inspired by Loop Habit Tracker
> • Today, Overview, and per-habit Detail views
> • Home Screen and Lock Screen widgets
> • iCloud sync (optional)
> • CSV and JSON export / import
> • Local reminders with quick actions
> • Full Dark Mode, Dynamic Type, VoiceOver
> • English and native French

### What's New — first public release (FR)

> Première version publique de Kadō.
>
> • Score d'habitude non-binaire — inspiré de Loop Habit Tracker
> • Vues Aujourd'hui, Vue d'ensemble et Détail par habitude
> • Widgets d'écran d'accueil et d'écran verrouillé
> • Synchronisation iCloud (optionnelle)
> • Export / import CSV et JSON
> • Rappels locaux avec actions rapides
> • Mode sombre complet, Dynamic Type, VoiceOver
> • Anglais et français natif

### What's New — 1.1 (EN)

> Version 1.1 — Siri, Shortcuts, and editable past days.
>
> • Siri and Shortcuts: complete a habit, log a value, or ask for
>   your score and streak — hands-free. Also available as Home
>   Screen actions and Shortcuts automations.
> • Edit past days straight from the calendar: tap any past or
>   today cell in the habit detail calendar to adjust that day's
>   completion — works for all habit types (check, counter, timer,
>   partial).
> • Fix: the Today view now refreshes correctly when you reopen
>   Kadō after midnight, so the right day is always shown.

### What's New — 1.1 (FR)

> Version 1.1 — Siri, Raccourcis et édition des jours passés.
>
> • Siri et Raccourcis : complète une habitude, saisis une valeur
>   ou demande ton score et ta série — mains libres. Disponible
>   aussi comme actions d'écran d'accueil et automatisations
>   Raccourcis.
> • Édite les jours passés directement depuis le calendrier :
>   touche n'importe quelle cellule passée ou du jour dans le
>   calendrier du détail d'une habitude pour ajuster sa
>   complétion — pour tous les types d'habitudes (case, compteur,
>   minuteur, partielle).
> • Correctif : la vue Aujourd'hui se met désormais correctement à
>   jour quand tu rouvres Kadō après minuit, et affiche toujours le
>   bon jour.

### What's New — 1.2 (EN)

> Version 1.2 — Notes, backdate, and month navigation.
>
> • Per-day notes: add a short note to any day's completion — tap a
>   day in the habit detail calendar and type in the note field.
>   Notes are included in JSON exports.
> • Backdate completions: log completions for days before the habit
>   was created. Your score, streak, and calendar adjust
>   automatically.
> • Month navigation: browse past months in the habit detail
>   calendar with the new ‹ / › arrows. Tap the month title to
>   jump back to today.

### What's New — 1.2 (FR)

> Version 1.2 — Notes, antidatage et navigation mensuelle.
>
> • Notes par jour : ajoute une courte note à la complétion de
>   n'importe quel jour — touche un jour dans le calendrier du
>   détail d'une habitude et saisis ta note. Les notes sont
>   incluses dans les exports JSON.
> • Antidater les complétions : enregistre des complétions pour des
>   jours antérieurs à la création de l'habitude. Ton score, ta
>   série et ton calendrier s'ajustent automatiquement.
> • Navigation mensuelle : parcours les mois passés dans le
>   calendrier du détail d'une habitude grâce aux nouvelles flèches
>   ‹ / ›. Touche le titre du mois pour revenir à aujourd'hui.

### What's New — 1.3 (EN)

> Version 1.3 — Reorder habits and gentle review prompt.
>
> • Drag to reorder: long-press and drag habits on the Today view to
>   arrange them in the order that works for you. Your custom order
>   syncs across devices via iCloud.
> • Gentle review prompt: after a week of use, Kadō may ask once if
>   you'd like to rate it. No interruptions, no dark patterns — just
>   a respectful ask you can dismiss forever.

### What's New — 1.3 (FR)

> Version 1.3 — Réorganisation des habitudes et demande d'avis.
>
> • Glisser pour réorganiser : appui long puis glisse tes habitudes
>   dans la vue Aujourd'hui pour les placer dans l'ordre qui te
>   convient. Ton ordre personnalisé se synchronise entre tes
>   appareils via iCloud.
> • Demande d'avis respectueuse : après une semaine d'utilisation,
>   Kadō peut te demander une seule fois si tu souhaites laisser un
>   avis. Pas d'interruption, pas de dark patterns — juste une
>   question que tu peux ignorer définitivement.

### App Review Information (public submission)
Same contact info as TestFlight. Extra notes:

> Kadō is an offline-first habit tracker with no sign-in or server
> component. All data stays on-device except for optional iCloud
> sync (user-initiated, uses Apple's CloudKit).
>
> No third-party services or SDKs are used.
>
> Source code (MIT license) is available at
> https://github.com/scastiel/kado — reviewers may audit directly.
>
> Testing flow:
> 1. Launch — tap "Get started".
> 2. Create a habit (+ button, pick a name, frequency, icon).
> 3. Complete it on the Today view.
> 4. Explore the habit's Detail screen for the score / calendar.
> 5. Settings → Data → export and reimport to exercise the CSV /
>    JSON flows.

---

## Privacy Nutrition Label

Fill out App Privacy in App Store Connect:

**Data Collection: "We do not collect any data from this app."**

Select the single checkbox at the top of the Data Collection
screen. No further questions appear.

Justification (keep a note in case Apple asks):
- No analytics SDK, no crash reporter, no ad identifier
- CloudKit writes go to the user's own iCloud private database —
  not "collected" in Apple's definition (their container, their
  keys)
- HealthKit data (when v0.3+ ships) is read-only on-device, never
  transmitted

---

## Screenshots (required)

### Specs
Apple requires the **6.7" iPhone** set and the **13" iPad** set
as of 2026. Older sizes auto-scale from the 6.7".

- **6.7" iPhone**: 1290 × 2796 px (iPhone 16/17 Pro Max)
- **13" iPad**: 2064 × 2752 px (iPad Pro 13")
- Minimum **3** screenshots per locale, maximum **10**
- PNG or JPEG, RGB color space, no transparency

### Suggested shots (order matters — first 3 show in Search)
1. **Today view** with ~5 habits, a mix of completed / partial /
   not-yet — shows the score shading
2. **Habit Detail** with monthly calendar + score info popover
   open (the "i" button) — our killer differentiator
3. **Overview** matrix — habits × days, score-shaded cells
4. **New habit** form — shows the flexible frequency options
5. **Widgets** on Home Screen (use the 6.7" bezel mockup)
6. **Dark mode** variant of Today
7. **Settings → Data** (export / import) — privacy message

Capture in both **EN** and **FR**. Reuse the same layouts, change
the locale.

### Capture workflow
```bash
# From XcodeBuildMCP:
# 1. Boot the target simulator
# 2. build_run_sim
# 3. snapshot_ui (for hierarchy) or screenshot (for image)
# 4. Repeat with iPhone 17 Pro Max and iPad Pro 13"
```

---

## Privacy Policy draft (`PRIVACY.md` at repo root)

> # Kadō — Privacy Policy
>
> Kadō does not collect any personal data.
>
> ## What Kadō stores
> Your habits, completions, reminders, and settings are stored
> locally on your device using Apple's SwiftData framework.
>
> ## iCloud sync (optional)
> If you enable iCloud sync, your data is replicated across your
> own Apple devices using Apple's CloudKit framework. It is stored
> in your private iCloud container — neither the app's developer
> nor any third party has access to it.
>
> ## HealthKit (optional, future releases)
> If you grant HealthKit permission, Kadō reads activity data to
> auto-complete habits. HealthKit data stays on your device. Kadō
> never writes to HealthKit and never transmits HealthKit data
> anywhere.
>
> ## Third-party services
> Kadō uses no third-party analytics, advertising, or crash
> reporting SDKs.
>
> ## Contact
> Questions? Open an issue at
> https://github.com/scastiel/kado/issues or email
> sebastien@castiel.me.
>
> Last updated: 2026-04-19

---

## Checklist before submitting for Beta App Review

- [ ] Beta App Description (EN + FR) pasted
- [ ] What to Test (EN + FR) pasted
- [ ] Feedback email set
- [ ] Privacy Policy URL reachable (commit `PRIVACY.md` first)
- [ ] Marketing URL reachable
- [ ] App Icon 1024×1024 present in the build
- [ ] Encryption declaration: `ITSAppUsesNonExemptEncryption = NO`
  already in Info.plist ✅
- [ ] External group created, testers added by email
- [ ] First build uploaded and shows "Ready to Submit"

## Checklist before submitting for App Store Review (v1.0)

All of the above, plus:

- [ ] Name, Subtitle, Description (EN + FR)
- [ ] Keywords (EN + FR)
- [ ] Promotional Text (EN + FR)
- [ ] What's New (EN + FR)
- [ ] Screenshots for 6.7" iPhone and 13" iPad (EN + FR)
- [ ] Primary / Secondary category
- [ ] Age Rating questionnaire
- [ ] App Privacy — "No data collected"
- [ ] Copyright
- [ ] Support / Marketing / Privacy URLs
- [ ] Pricing: Free, Tip Jar IAP configured separately
- [ ] Availability: all territories (default)
- [ ] Export compliance: already handled via Info.plist flag ✅
- [ ] App Review notes filled
