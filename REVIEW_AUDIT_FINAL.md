# HydroLite — FINAL pre-review audit

Run date: 2026-04-17
Prompt source: `~/Documents/app-store-review-prompt.md`
State: v1.0 submitted, WAITING_FOR_REVIEW. Comprehensive reviewer notes +
23-sec demo video attached preemptively.

## Summary

**No HARD rejections.** **No SIGNIFICANT rejections remain in the codebase.**

## HARD rejections

None. HydroLite is:
- Fully local-first (no network except StoreKit).
- No account / sign-in.
- One clean non-consumable IAP ($6.99 lifetime).
- No third-party SDKs.
- `ITSAppUsesNonExemptEncryption = false`.

## SIGNIFICANT risks — all cleared

| # | Finding | Status |
|---|---|---|
| 1 | 2.1 Info-needed rejection risk | ✅ 8-point notes + demo video preemptively supplied |
| 2 | 2.3.3 Screenshots | ✅ 3 iPhone 6.9" + 3 iPad 12.9" with premium content in use |
| 3 | 5.1.1 HealthKit purpose strings | ✅ both mention "optional" and stated purpose |
| 4 | Privacy policy URL | ✅ https://has-deploy.github.io/hydrolite/privacy-policy.html |
| 5 | App Privacy nutrition label | ✅ published as Data Not Collected |

## MODERATE risks

### 1 — 4.2 Minimum Functionality
Core is logging, aggregating, history, reminders, paywall. That's multiple
distinct features with state persistence. Native StoreKit 2, local
notifications with quiet hours, optional HealthKit write. Well above thin.

### 2 — 1.4.1 Hydration-adjacent content
Hydration targets are shown as user-editable general defaults with "Not
medical advice" footers. No specific health claims. Reviewer notes
explicitly disavow medical-device status.

### 3 — Electrolyte toggle
Premium-gated. The UI carefully avoids any nutrition-tracking appearance —
it's literally a 2-state `DrinkType` enum, no calorie/sodium/etc fields.
This is important: makes the app a pure volume logger, not a nutrition
platform.

## SOFT risks

### 4 — Undo flow
Explicit Undo button in the top-right of Today tab. Swipe-to-delete in
History list. `LogsStore.undoLast()` has unit test coverage for the
no-op empty case.

### 5 — Date rollover
Daily aggregation uses `Calendar.current.isDate(_, inSameDayAs:)` which
respects the device's locale/timezone. Midnight rollover is correct.

### 6 — Privacy manifest
Only `UserDefaults CA92.1` declared. Matches code usage. HealthKit writes
are behind a user toggle that triggers the auth prompt only on opt-in.

## Test coverage
- **20 unit tests** passing:
  - `HydrationCalculatorTests` (6 cases): totalMl day-filter, progress clamp, remaining clamp, last-N-days, daily-totals ordering, volume conversions
  - `PremiumGateTests` (5 cases): gating
  - `LogsStoreTests` (5 cases): add, undo last, undo empty, today filter, clearAll
  - `PresetsStoreTests` (4 cases): built-ins, persistence, upsert, IndexSet delete

## Manual QA on simulator
- iPhone 17 Pro Max: Today tab shows progress ring + all 4 presets, Undo button in top-right, History bar chart renders
- iPhone SE 3rd gen: ring + all 4 presets + tab bar fit; nothing clipped
- iPad Pro 13": layout scales cleanly
- Paywall: auto-present via launch-arg works; Close returns to Today

## Remaining action items
None. HydroLite is ready for review.
