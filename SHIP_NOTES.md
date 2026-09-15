# HydroLite — Ship Notes (Portfolio Audit 2026-05-15)

## Install-trial SoT (code only, 2026-09-15)

Master install-trial source of truth is now **14 days**. `PricingConfig.annualTrialDays = 14` is what `PurchaseManager.computeTrialActive` / `installTrialDaysRemaining` read for the local install-time Premium grant. Yearly paywall copy is renewal-only (`$14.99/year, auto-renews`); this is not an ASC intro and this note is code-only — no App Store Connect submit.

Source audit: `/Users/tony/Documents/portfolio-audit/01-hydrolite.md`
Verdict baseline: 2 HARD · 4 SIGNIFICANT · 3 POLISH

## Summary

**3 HARDs fixed, 2 SIGNIFICANTs fixed, 1 POLISH fixed, 4 DEFERRED.**

(H1 counts as fixed via the strip path. H2 is fixed via the "surface + disclose"
path — the install trial is no longer silent, but it still exists. P1 is folded
into the H2 fix because it was the same banner.)

## Fixed in this commit

### H1 — Custom-presets advertised but no UI: STRIPPED from copy
Chose the audit's fast path (strip, don't build the editor). Removed "Custom
drink presets" from every user-facing surface:

- `HydroLite/Core/Pricing/PricingConfig.swift:38` — dropped from `paywallBenefits`
- `HydroLite/Resources/Configuration.storekit:11,38,64` — dropped from all three
  product `description` strings (lifetime / monthly / yearly)
- `HydroLite/Features/Today/TodayView.swift:171-173` — UpsellCard message no
  longer mentions "Custom presets"; trigger feature switched
  `customPresets` → `electrolyteTracking`
- `docs/asc-description-v-next.md:35` — monthly tier description no longer
  advertises "custom presets"

The `PremiumFeature.customPresets` enum case + `PresetsStore.addOrUpdate(_:)`
are intentionally left in place (referenced by tests + an internal DEBUG
paywall trigger in `RootView.swift:55`). They are no longer reachable from any
shipping UI surface, which matches the "advertised feature now removed from the
sales pitch" outcome.

### H2 — Silent install trial: SURFACED + DISCLOSED (option b)
Chose the in-UI disclosure path over removing the install trial. Killing the
trial would break a working free-Premium-for-N-days experience the rest of the
app already gates on (`PurchaseManager.isEntitled`); the audit explicitly
called option (a) "safer for reviewer" but it would also invert the free-user
experience and is borderline architecture.

- `HydroLite/Core/Purchases/PurchaseManager.swift` — added
  `installTrialDaysRemaining` computed prop (read-only convenience; does not
  touch the trial-determination math or StoreKit plumbing).
- `HydroLite/Features/Paywall/PaywallView.swift` — added `installTrialBanner`
  shown between header and benefits when `purchases.installTrialActive`.
  Copy explicitly says "no card required" and "Subscribe before it ends to
  keep Premium," which reframes the silent grant as a disclosed preview and
  removes the refund-bait of a user buying yearly while already on day 4 of
  the install trial.
- `HydroLite/Features/Settings/SettingsView.swift` premiumSection — same
  preview banner appears for non-Premium users when the install trial is active.

### S1 — Analytics opt-out toggle wired in SettingsView.dataSection
`HydroLite/Features/Settings/SettingsView.swift`:

- Added `@AppStorage("portfolio.analytics.opted_out")` and an
  `analyticsEnabled` Binding that calls `PortfolioAnalytics.shared.optIn()`
  / `optOut()` (pattern A from FIX_GUIDELINES).
- Toggle rendered as the first row of the Data section.
- Footer text updated to match the App Store description's "anonymous,
  opt-out product analytics only" promise.

### S2 — Manage-subscription deep link
`HydroLite/Features/Settings/SettingsView.swift` premiumSection:

- For Premium users: new "Manage subscription" row calls
  `AppStore.showManageSubscriptions(in:)` on the active `UIWindowScene`
  (pattern B), falling back to `https://apps.apple.com/account/subscriptions`
  via `openURL` if no scene is available.
- Restore button preserved alongside it.
- `import StoreKit` added at the top of the file.

### S3 — docs/index.html "7-day history" → "3-day history"
Marketing page now matches `PricingConfig.freeHistoryWindow = 3`.

### P1 — Paywall now honors install-trial state
Same banner as H2 — paywall copy reflects the disclosed preview state when
`installTrialActive` is true.

## Deferred (needs owner)

### S4 — Free reminder cap is fragile across the allowed interval range
DEFERRED — needs owner.

The current `freeReminderSlots = 8` passes the 120-min default by exactly one,
and fails as soon as a free user steps the interval down toward 30 min. The
fix needs a product decision the audit explicitly flags:

- Option A: cap slots at whatever the shortest allowed interval (30 min)
  produces against the user's quiet window (~34 reminders) — simple math
  change in `PremiumGate.canEnableAnotherReminder` but it effectively makes
  reminders unlimited for free users, undercutting the "Advanced reminders"
  paywall benefit.
- Option B: stop gating on count entirely and gate "Advanced reminders" on
  the actual advanced behaviors the App Store description implies (custom
  per-day quiet hours, per-day variation). This is the path the description
  already promises but is a structural reminder-engine change.

Recommend Option B; out of scope for a surgical fix.

### P2 — Dead `AnalyticsEvent` enum / dual analytics layers
DEFERRED — refactor, not a reject. `ConsoleAnalytics` only print-debugs; all
real telemetry flows through `PortfolioAnalytics.shared.track`. Collapsing the
two layers is portfolio-wide work (every app has the same shape) — should be
done in coordination with the portfolio-spec, not one-off in HydroLite.

### P3 — PostHog API key in source
DEFERRED — hygiene, not a reject. Moving the key into an `xcconfig` excluded
from git is a build-system change. Note: the same key is in WalkCue /
RackTimer / SleepWindow per the same drop-in pattern, so this should be a
portfolio-wide migration, not a single-app fix.

### H1 (architecture path) — Build the custom-presets editor UI
DEFERRED — needs owner decision.

The strip path (above) is what shipped. If you want to actually deliver
custom presets as a Premium feature, that's roughly:

- An "Edit presets" row in `SettingsView` (Premium-only) opening a sheet.
- A list view backed by `PresetsStore.customPresets` with edit/delete.
- An add/edit form (label + amount + drink type) calling
  `PresetsStore.addOrUpdate(_:)`.
- A `PremiumGate.canSaveAnotherCustomPreset` check (already exists, gated on
  `freeCustomPresetSlots = 0`).
- Restore "Custom drink presets" to `paywallBenefits[0]`, the three StoreKit
  descriptions, and the ASC description.

Comfortably >30 minutes of careful work + UI polish + at least one new test
file. Defer to a focused custom-presets task.

## ASC metadata edits required (owner action in App Store Connect)

Code now disagrees with the live App Store description on two points. The new
draft description at `docs/asc-description-v-next.md` already drops "custom
presets" from the monthly tier — but the **live** description and the
existing v1.2.0 ASC draft may still advertise it on monthly / yearly /
lifetime. Verify and edit in ASC before submitting:

1. **Remove "custom presets"** from the Pricing block in the App Store
   description (Monthly / Yearly / Lifetime feature lists) for any draft you
   plan to ship as v1.2.0. The repo's `docs/asc-description-v-next.md` is now
   the source of truth.

2. **Disclose the install-time free Premium preview** in the App Store
   description. Suggested addition under "Pricing" or "Privacy-first":

   > New installs get a 7-day free Premium preview, no card required. After
   > 7 days, Premium features lock unless you subscribe or buy Lifetime.

   This pairs with the in-app banner now shown on the paywall + Settings.
   Without this, the description still says "Free forever: logging, built-in
   presets, basic reminders, 3-day history" — which is technically false on
   days 1-7.

3. (Confirm only — already correct in v-next draft.) Free-tier history window
   is 3 days, not 7. Marketing page (`docs/index.html`) is now also 3 days.

## Risk notes

- The `installTrialDaysRemaining` computed prop reads `firstLaunchKey` /
  `clock()` directly on `PurchaseManager`. It does NOT mutate state and does
  NOT touch the trial anchor. Safe to call from view-render context.
- The `Manage subscription` button uses `try? await
  AppStore.showManageSubscriptions(in:)` with an explicit
  `connectedScenes`-derived `UIWindowScene` lookup + `openURL` fallback. iOS 16+
  (the app minimum) supports both paths.
- `@AppStorage("portfolio.analytics.opted_out")` reads the same UserDefaults
  key as `PortfolioAnalytics.shared.isOptedOut` (which uses the constant
  `kOptedOut = "portfolio.analytics.opted_out"`). The toggle and the SDK
  state stay in lockstep across launches.
- The `PremiumFeature.customPresets` case is now unreachable from any user-
  facing surface in code; only `RootView.swift:55` (DEBUG-only paywall
  preview) and tests reference it. Nothing user-facing routes through it.

## Build / submit

Per FIX_GUIDELINES: did NOT run `xcodebuild`, did NOT bump version, did NOT
push, did NOT submit to ASC. Commit-only.
