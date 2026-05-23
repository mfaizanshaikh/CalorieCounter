# CLAUDE.md

Orientation file for Claude Code. Goal: spend tokens on the work, not on re-exploring the repo each session. If anything below goes stale, fix it as part of the same change.

## Project at a glance

AI Calorie Coach — live iOS app (App Store id 6741466804). SwiftUI + SwiftData, iOS 17+, CocoaPods. Bundle id `com.mfaizanshaikh.caloriecounter`, team `KJS5669LU6`.

As of 2026-05-22 the app is gaining Google + Apple sign-in and cloud sync via a vanilla PHP + MySQL backend on shared cPanel hosting. See `backend/README.md` for setup and `changes.md` for what shipped when.

## Repo layout

```
CalorieCounter/                 iOS app source (one Xcode target)
├── Models/                     @Model classes + UserSettings (ObservableObject)
├── ViewModels/                 ObservableObject classes; all mutations go through SyncStore
├── Views/                      SwiftUI screens, organised by feature (Auth, Camera, History, Settings, …)
├── Services/                   Actors: OpenAI, FoodSearch, APIClient, AuthService, SyncService, SyncCoordinator
├── Utilities/                  KeychainHelper, ImageProcessor, DateExtensions, AppReviewManager
├── Resources/                  FoodDatabase.json (~9.6k foods), PrivacyInfo.xcprivacy
├── Info.plist                  contains placeholders BackendBaseURL + REPLACE_WITH_REVERSED_CLIENT_ID
├── CalorieCounter.entitlements Sign in with Apple
└── GoogleService-Info.plist    Firebase config (needs CLIENT_ID for Sign-In — see backend/README.md §1)

backend/                        PHP + MySQL backend (uploaded to cPanel via FTP)
├── schema.sql                  7 tables, run once via phpMyAdmin
├── composer.json               firebase/php-jwt + google/apiclient + ramsey/uuid
└── api/                        Upload entire contents to public_html/api/
    ├── index.php               front controller / router
    ├── .htaccess               HTTPS redirect, security headers, rewrite to index.php
    ├── config.example.php      template (copy to config.php; gitignored)
    ├── lib/                    shared helpers (db, jwt, auth, http, photo_storage)
    └── routes/                 one file per endpoint (meals, saved_foods, settings, photos, …)

changes.md                      Running log of project changes. Keep updated.
README.md                       Public-facing app description (App Store / GitHub readers).
```

For the active sync feature design, read `/Users/faizan/.claude/plans/i-have-a-ai-cuddly-wave.md`.

## Standing conventions

1. **App Store Review Guidelines apply to every change.** Audit 4.8 (Sign in with Apple if any third-party login), 5.1.1(v) (in-app account deletion), 5.1.1 / 5.1.2 (disclosure + minimization), privacy policy, App Store Connect nutrition labels. The app is live and has been through one audit already — don't ship a regression.
2. **Never add `Co-Authored-By: Claude` trailers** to commits. User has stated this explicitly.
3. **Update `changes.md` as part of the change.** Newest entry on top under the first `---`. Heading `## YYYY-MM-DD — Summary`. Body covers *why*, grouped by area, plus any manual follow-ups for the user. Don't promise to do this later.
4. **All SwiftData mutations go through `Services/SyncStore.swift`.** `SyncStore.save(meal:)`, `delete(meal:)`, `save(savedFood:)`, etc. handle `updatedAt` bumping, `ownerUserId` tagging, and triggering a debounced sync. Don't call `context.insert / delete / save` directly from new view models.
5. **Open the `.xcworkspace`, not the `.xcodeproj`.** The project uses CocoaPods. `pod install` after any `Podfile` change.
6. **Backend secrets stay out of git.** `backend/api/config.php`, `vendor/`, and `private_uploads/` are gitignored at both the root `.gitignore` and `backend/.gitignore`.
7. **OpenAI API key is per-device** (Keychain via `KeychainHelper`). Don't sync it; the user can use a different key per device, and we want data minimization.

## Build & run

```bash
# After pulling a fresh checkout or after Podfile changes:
pod install

# Open in Xcode going forward:
open CalorieCounter.xcworkspace

# Quick parse check on Xcode files (sanity check after pbxproj edits):
plutil -lint CalorieCounter.xcodeproj/project.pbxproj
plutil -lint CalorieCounter/Info.plist CalorieCounter/CalorieCounter.entitlements
```

Sign in with Apple **does not work in the iOS simulator** with a generic iCloud account — test on a real device.

PHP is not installed locally; the backend can only be smoke-tested after upload (`curl https://yourdomain.com/api/health`).

## Architecture notes

- **Single source of truth on device** is SwiftData. The server is a mirror. Sync model: per-mutation push (debounced 300ms), cold-launch pull from `/api/sync/state?since=`, last-write-wins by `updatedAt`.
- **Soft-delete tombstones**: rows carry `deletedAt`. For local→server deletes, a `SyncOp` queue entry is created before physical delete so we don't lose the id mid-flight.
- **Photos** live as files outside the webroot at `{uploads_dir}/{user_uuid}/{photo_uuid}.jpg`. Streamed through PHP after auth. Server cascade unlinks them when a meal or account is deleted.
- **Auth** is short-lived access JWT (HS256, 15 min) + opaque refresh token (random 256-bit, stored hashed). `APIClient` handles 401 → single refresh attempt → retry.
- **GoogleService-Info.plist** as committed today only has Firebase Analytics keys. Adding the iOS OAuth client in Google Cloud Console produces a new plist with `CLIENT_ID` and `REVERSED_CLIENT_ID` — both are needed for Sign-In. See `backend/README.md` §1.

## Common gotchas

- `Info.plist` ships with two placeholders: `REPLACE_WITH_REVERSED_CLIENT_ID` (Google URL scheme) and `BackendBaseURL = https://example.com/api`. Both must be set to real values before a release build will work.
- SourceKit shows spurious "Cannot find type X in scope" errors in fresh checkouts before `pod install` runs and the project is built once. The real compiler is authoritative.
- The pbxproj uses traditional file refs, **not** synchronized folder references. New Swift files must be registered in `PBXBuildFile`, `PBXFileReference`, the parent `PBXGroup`, and `PBXSourcesBuildPhase` — Xcode does this when you drag files in; manual edits need all four.
- `MealType` enum has both `snack` and `lateSnack` cases — `lateSnack` is kept for backward compatibility with existing user data and should not be removed.
- Bundled foods from `Resources/FoodDatabase.json` (~9.6k entries, seeded once per install) are local-only and do not sync. Only user-added `SavedFood` rows (`isFromAI == true` or `searchCount > 0`) sync.

## Useful docs

- `backend/README.md` — full backend setup (Google Cloud, Apple Dev portal, cPanel, FTP, App Store Connect updates).
- `changes.md` — what changed and when.
- `/Users/faizan/.claude/plans/i-have-a-ai-cuddly-wave.md` — sync feature design doc.
- `~/.claude/projects/-Users-faizan-Documents-Personal-Projects-CalorieCounter/memory/MEMORY.md` — auto-loaded per-machine notes (already in context).
