# Ambient Mindfulness

watchOS + iOS app that delivers adaptive mindfulness check-in notifications.

## Architecture

- **Watch app**: Schedules and receives notifications, logs responses, syncs to phone
- **Phone app**: Shows log of check-ins synced from watch
- **Shared/**: Types used by both targets (EntryPayload, MindfulEntry, Sentiment, AdaptiveRate)
- **Tests**: iOS test target, imports Shared types via `@testable import AmbientMindfulness`

## Adaptive Notification Scheduling

Notifications adapt their frequency based on how often the user responds:
- Measures response frequency (responses per unit time) with exponential time-weighting (24h half-life)
- `spacing = responseInterval / targetRate` — converges toward 80% response rate
- Maintains a buffer of 3 pending notifications, tops up on each trigger (app open, response)
- Sleep hours (22:00-07:00) skipped
- Cold-start protection: uses defaults (3h spacing) until enough response data

## Key Design Decisions

- **Response-frequency only**: Rate computation only counts user responses, not deliveries. Simpler and avoids the problem that `willPresent` only fires in foreground.
- **Never reschedule**: Only append new notifications, never cancel pending ones. Trades adaptation speed for simplicity.
- **Deterministic spacing**: No randomness. Easier to debug. Can add jitter later.
- **Buffer-based**: 3 notifications ahead. Tops up idempotently on triggers.

## Build & Deploy

- **No local Xcode** — builds happen in CI (GitHub Actions, `macos-15`)
- **XcodeGen** generates `.xcodeproj` from `project.yml`
- **Swift 6 strict concurrency** (`SWIFT_VERSION: "6.0"`)
- CI: push to main → test → deploy to TestFlight
- Export compliance: `ITSAppUsesNonExemptEncryption=NO` in both targets
- Build number: `github.run_number` (auto-incrementing)
- Upload verification: `grep -q "Upload succeeded"` in export logs
- Cert cleanup: `scripts/asc-cleanup-certs.js` runs before each deploy

## Scripts (in `scripts/`)

CI helpers (read-only, whitelisted):
- `ci-status.sh` — recent CI runs
- `ci-jobs.sh` — job results for a run
- `ci-wait.sh` — poll until run completes
- `ci-fetch-logs.sh` — download logs locally for analysis
- `ci-run-detail.sh` — detailed run info (runner allocation, etc.)

ASC helpers (read-only, zero deps):
- `asc-builds.js` — list TestFlight builds
- `asc-build-detail.js` — build state, compliance
- `asc-testflight.js` — beta groups and assigned builds

CI infra (read-only):
- `gh-billing.sh` — billing/quota info
- `gh-debug-ci.sh` — diagnose runner allocation failures

Write operations:
- `gh-make-public.sh` — change repo visibility (use with care)
- `asc-cleanup-certs.js` — revoke old signing certs (runs in CI)

All ASC scripts use `scripts/asc-lib.js` for JWT auth (zero npm dependencies).

## Coding Conventions

Follows Paul's "light functional" style from the root skroding CLAUDE.md:
- Immutability by default, no classes for app logic (enums with static functions)
- Swift 6 strict concurrency: `@MainActor` for SwiftData, `@unchecked Sendable` where needed, `nonisolated` for delegate callbacks
- `EntryPayload` enum as the log format — all events are payload cases
- Display logic (`emoji`, `label`, `isSentiment`) lives on `EntryPayload`, not in views

## Known Issues / Future Work

- Background task refresh not yet implemented (relies on app open + response triggers)
- Watch-to-phone sync (`WatchSync.sendAllEntries`) only fires on notification events, not on a schedule
- No randomness/jitter in notification timing yet
- `@unchecked Sendable` on `NotificationDelegate` is a known sharp edge
