# HydroLite — Adversarial App Store Review Audit (FINAL)

**Run date:** 2026-04-17
**Reviewer persona:** Apple App Store Review
**Target:** `/Users/tony/Developer/hydrolite` @ current HEAD
**ASC app ID:** 6762470335
**State:** WAITING_FOR_REVIEW; reviewer notes + demo video attached.
**Verdict:** **2 HARD, 3 SIGNIFICANT.** Do NOT let this review without fixes.

## HARD

### H1 — 2.5.1 / 5.1.1 — HealthKit used without entitlement
Same pattern as WalkCue. `HealthKitManager.swift:10,26` calls HealthKit; no `.entitlements` file exists.
- **Fix:** strip HealthKit from v1. Remove manager, Settings toggle, usage strings.

### H2 — 2.3.1 — Description advertises Apple Health write that never happens
- `asc_driver.py:306` + `docs/index.html:26` + Settings toggle all promise Health sync.
- `HealthKitManager.writeWater(...)` is defined but **never called** — `TodayView.logAmount:179-183` only saves to local store.
- **Fix:** cleared by H1 fix (remove Health integration + remove the marketing claim from asc_driver.py description).

## SIGNIFICANT

### S1 — 2.3.1 — SleepWindow/WalkCue bleed in `asc_driver.py` IAP review note
- `asc_driver.py:197` IAP reviewNote says "custom routines, full walk history, advanced cue packs" — WalkCue copy.
- `asc_driver.py:216-217` create-IAP branch says "SleepWindow Lifetime Unlock" + "every calculator, nap planner."
- **Fix:** rewrite strings to describe HydroLite's actual premium (custom presets, electrolyte, full history, advanced reminders). Patch live IAP reviewNote in ASC.

### S2 — 2.1 / 4.2 — Default config paywalls free-tier reminders instantly
- Defaults: 120-min interval, 22-07 quiet hours → 15 h waking → 7 predicted reminders. Free tier cap is 2 (`PricingConfig:21`). `canEnableAnotherReminder(6)` → false. Free user can never toggle reminders on.
- **Fix:** raise `freeReminderSlots` to 8 OR change gate semantics so one toggle is always allowed for free users.

### S3 — 5.1.1 — HealthKit read permission requested, never used
Cleared by H1 fix.

## Prioritized fix list
1. **H1 + H2** — strip HealthKit; remove the marketing claim in description.
2. **S1** — scrub SleepWindow/WalkCue strings from `asc_driver.py`; patch live IAP reviewNote.
3. **S2** — fix free-reminder gate math or cap.
4. Regenerate, re-archive, re-upload, cancel current submission, submit new build.
