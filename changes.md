# Changes

Running log of changes made to AI Calorie Coach. Newest entry on top. Each entry lists what changed, why, and any follow-up the user still has to do manually.

---

## 2026-05-23 — Fix `SQLSTATE[HY093]: Invalid parameter number` on sync

**Why:** After the `uploads_dir` fix landed, the Settings screen surfaced `Sync failed: Server error (500): SQLSTATE[HY093]: Invalid parameter number`. Five upserts in the codebase (`routes/meals.php`, `routes/saved_foods.php`, `routes/settings.php`, plus the meals / saved_foods / user_settings upserts in `routes/migrate_bulk.php`) use `INSERT … ON DUPLICATE KEY UPDATE` and reuse the same named placeholders (`:d`, `:mt`, `:p`, etc.) on both sides of the statement. With `PDO::ATTR_EMULATE_PREPARES => false`, some shared-host PHP/PDO_MySQL builds (notably PHP < 8.1) reject placeholder reuse with HY093. PHP 8.1+ generally allows it, but the user's Hostinger PHP build is throwing the error, so we can't rely on the runtime supporting reuse.

### Changes
- `backend/api/lib/db.php` — flipped `PDO::ATTR_EMULATE_PREPARES` to `true` so PHP performs the substitution before sending the statement, which always supports placeholder reuse. Safe under `utf8mb4` (the documented emulated-prepares risk is limited to charsets like GBK). Comment in the file explains the choice so a future reader doesn't quietly flip it back.

### Follow-ups for the user
- Re-upload `backend/api/lib/db.php` to the server.
- Re-trigger sync from the app (Settings screen). The remaining sync flow (meals, saved foods, settings, photos) should now complete without HY093.

---

## 2026-05-23 — Make `uploads_dir` portable; fix sync 500 on photo upload

**Why:** With sign-in working, the Settings screen surfaced `Sync failed: Server error (500): Could not create uploads directory.` from `photo_storage.php`. The deployed `config.php` had `uploads_dir` set to `/public_html/ai-calorie-coach/private_uploads/`. PHP interprets that as an absolute filesystem path rooted at `/` (a directory that doesn't exist) — and even if the user meant it relative to their account home, that location is *inside* the webroot, contradicting the "outside webroot" requirement. Hostinger's layout can also vary (`/home/<user>/public_html/...` vs `/home/<user>/domains/<domain>/public_html/...`), so a hand-typed absolute path is easy to get wrong.

### Changes
- `backend/api/config.php` — set `uploads_dir` to `__DIR__ . '/../../../private_uploads'`. Because `config.php` lives at `<webroot>/ai-calorie-coach/api/config.php`, this resolves one level above `public_html/` on either Hostinger layout, putting photo storage outside the webroot.
- `backend/api/config.example.php` — same `__DIR__`-based default so future installs work out of the box, with a comment explaining when to override.
- `backend/api/lib/photo_storage.php` — `Could not create uploads directory` now includes the path it tried and the `realpath()` of the base, so the next failure (e.g. open_basedir restriction, missing parent) reports the actual location rather than guessing.
- `backend/README.md` §5 — replaced the stale parenthetical that suggested an inside-webroot path; documents the new `__DIR__`-based default and notes the `open_basedir` requirement.

### Follow-ups for the user
- Re-upload `backend/api/config.php` and `backend/api/lib/photo_storage.php` to the server.
- Via cPanel File Manager or FTP, create the `private_uploads/` directory one level *above* `public_html/` (the exact location depends on your Hostinger layout — should be either `/home/<user>/private_uploads` or `/home/<user>/domains/mfaizanshaikh.com/private_uploads`). Set permissions to `750`.
- Re-trigger sync from the app (Settings screen). If it still 500s, the new error will name the resolved path, which tells us exactly where to create the directory or whether `open_basedir` is blocking access.

---

## 2026-05-23 — Fix `Undefined variable $CONFIG` 500 at sign-in

**Why:** Both Google and Apple sign-in were returning `Server error (500)` from the iOS app the moment the OAuth flow completed. With `debug => true` flipped on, the underlying PHP error surfaced as `Undefined variable $CONFIG`. The `$CONFIG` array is loaded at the top level of `backend/api/index.php`, but routing happens inside the `route()` function which `require`s each route file. Files included from inside a function inherit only that function's local scope, so the global `$CONFIG` was invisible to `routes/auth_login.php` (and `auth_refresh.php`, `photos.php`, `account_delete.php`, `migrate_bulk.php`, all of which reference `$CONFIG` at top level). The function declared the parameter as `$config` (lowercase), so the include couldn't see it under either name.

### Changes
- `backend/api/index.php` — renamed `route()`'s `array $config` parameter to `array $CONFIG` so route files included via `require` from inside the function now see the config under the name they reference. `require_auth($CONFIG)` updated to match.

### Follow-ups for the user
- Re-upload `backend/api/index.php` to `public_html/ai-calorie-coach/api/index.php`. Sign-in should work for both Google and Apple after that.
- Once sign-in is confirmed working, re-upload `backend/api/config.php` (now back to `debug => false`) so error details aren't exposed in prod responses.
- Separately: `config.php`'s `uploads_dir` (`/public_html/ai-calorie-coach/private_uploads/`) is not a valid absolute cPanel filesystem path and is also *inside* the webroot, defeating the "outside webroot" requirement. The first photo upload will 500 until this is changed to something like `/home/<cpanel-user>/private_uploads` (outside `public_html/`) and that directory exists and is writable.

---

## 2026-05-23 - Unblock the workspace iPhone build

**Why:** The iPhone build failed in Xcode with a cascade of `Unable to find module dependency` errors for Apple SDK modules. Once the dependency-scanner noise was suppressed, the first actionable compiler error was `redefinition of module 'Firebase'`: Firebase Analytics was wired through both CocoaPods and a direct Firebase Swift Package product. After that duplicate integration was removed, the build reached sync feature code and exposed main-actor concurrency mismatches. The next Xcode run then failed in CocoaPods' embed-frameworks script with `Sandbox: rsync deny(1) file-write-create` while copying `AppAuth.framework`.

### Changes
- `CalorieCounter.xcodeproj/project.pbxproj` - removed the direct `FirebaseAnalytics` Swift Package product and package reference from the app target. Firebase and Google Sign-In continue to come from the `Podfile` and CocoaPods workspace.
- `CalorieCounter.xcodeproj/project.pbxproj` - disabled User Script Sandboxing for the app project build configurations so CocoaPods' `[CP] Embed Pods Frameworks` rsync script can copy framework bundles into the app.
- `CalorieCounter/Services/SyncService.swift` - made the merge helper async so it can legally apply pulled settings on the main actor.
- `CalorieCounter/Services/SyncStore.swift` - marked SwiftData mutation helpers that touch auth/sync UI state as main-actor work, and schedules settings-triggered sync notification back onto the main actor.

### Follow-ups for the user
- Open `CalorieCounter.xcworkspace`, not `CalorieCounter.xcodeproj`, when building the app with CocoaPods.

---

## 2026-05-23 — Router auto-detects install path (subfolder support)

**Why:** User uploaded the API to `public_html/ai-calorie-coach/api/` rather than `public_html/api/`, then hit `https://mfaizanshaikh.com/ai-calorie-coach/api/health` and got `{"error":"Missing or invalid Authorization header."}` instead of `{"status":"ok"}`. The path-stripping in `index.php` only matched `/api` at the very start of the request path, so `/ai-calorie-coach/api/health` was left intact, didn't match the `/health` route, and fell through to `require_auth()`.

### Changes
- `backend/api/index.php` — replaced the hard-coded `^/api` strip with one that derives the install prefix from `dirname($_SERVER['SCRIPT_NAME'])`. Works for root mounts (`/api/...`) and subfolder mounts (`/ai-calorie-coach/api/...`) alike.
- `backend/README.md` §7, §8 — call out that subfolder installs are supported, give the matching `curl` example, and remind users to point `BackendBaseURL` (§9) at whichever path they chose.

### Follow-ups for the user
- Re-upload `backend/api/index.php` to the server.
- Hit `https://mfaizanshaikh.com/ai-calorie-coach/api/health` again — should now return `{"status":"ok"}`.
- When you set `BackendBaseURL` in `CalorieCounter/Info.plist` (step 9), use `https://mfaizanshaikh.com/ai-calorie-coach/api` (no trailing slash).

---

## 2026-05-23 — Unblock `composer install` (PHP 8.3 platform + audit ignore)

**Why:** User ran `composer install --no-dev --optimize-autoloader` and it failed with two compounding problems:

1. **PHP platform mismatch.** `composer.json` pinned `config.platform.php` to `"8.0"`, but `google/apiclient` v2.18.4+ requires `php ^8.1`. Composer fell back to v2.18.3 and earlier, which require the old `firebase/php-jwt ^6.0` — also blocked (see below). The user's cPanel runs PHP 8.3, so the 8.0 pin was just wrong.
2. **Security advisory blocking install.** Composer 2.7+ runs an audit on install. `PKSA-y2cr-5h3j-g3ys` (CVE-2025-45769, severity LOW) flags **every** `firebase/php-jwt` <7.0.0, and no 7.x release exists yet. Advisory is about the library accepting weak secrets. Our `jwt_secret` comes from `openssl rand -base64 48` (384 bits) and is used only for HS256 sign/verify in `api/lib/jwt.php` — no algorithm negotiation, no `kid` lookup, no JWKS. Not exploitable in our usage. Decision: ignore it in `composer.json` with a written justification so it's auditable later.

### Changes
- `backend/composer.json`:
  - `require.php` bumped `>=8.0` → `>=8.1` (matches what `google/apiclient` actually needs).
  - `config.platform.php` bumped `"8.0"` → `"8.3"` (matches production cPanel).
  - Added `config.audit.ignore` entry for `PKSA-y2cr-5h3j-g3ys` with the rationale above.
- `backend/README.md` §0 — Prerequisites: PHP 8.0+ → PHP 8.1+ (tested on 8.3), with a note to set the cPanel PHP version via MultiPHP Manager before running `composer install`.

### Follow-ups for the user
- Re-run `composer install --no-dev --optimize-autoloader` in `backend/`. Should now resolve cleanly.
- If a future `firebase/php-jwt` 7.x ships, upgrade and remove the audit-ignore entry.

---

## 2026-05-23 — Clarify Firebase is not the backend

**Why:** User read `backend/README.md` and reasonably asked "why does this mention Firebase if we're not using it?" The backend is pure PHP + MySQL; Firebase mentions were only about (a) the pre-existing `Firebase/Analytics` pod and (b) using Firebase Console as a convenient download source for `GoogleService-Info.plist`. Wording risked making the architecture confusing for future readers (and future Claude sessions).

**Decision:** keep the current "GoogleService-Info.plist via Firebase Console" path (it leverages the already-configured Firebase project), but document explicitly that Firebase is not the backend.

- `backend/README.md` — added a top-of-file note explaining: backend uses no Firebase services; Firebase Console appears only as a `GoogleService-Info.plist` download source; `pod 'Firebase/Analytics'` is a separate pre-existing analytics dependency. Reworded step 1 intro to match.

---

## 2026-05-22 — Add Google/Apple sign-in + PHP backend sync

**Why:** App was on-device only — uninstall meant total data loss. Goal is "sign in and your data comes back." Plan: `/Users/faizan/.claude/plans/i-have-a-ai-cuddly-wave.md`.

**Architecture chosen:** mandatory sign-in at first launch · Sign in with Apple alongside Google (App Store Guideline 4.8) · vanilla PHP + MySQL on shared cPanel hosting · single front controller at `/api/index.php` · immediate per-mutation sync with offline queue · launch-time pull for multi-device · soft-delete tombstones · last-write-wins by `updatedAt`.

### iOS — SwiftData model layer
- `Models/MealEntry.swift` — added `ownerUserId`, `updatedAt`, `deletedAt`, `photoRemoteId` (all defaulted for SwiftData lightweight migration of existing 1.2 users).
- `Models/FoodItem.swift` — added `updatedAt`, `deletedAt`.
- `Models/SavedFood.swift` — added `ownerUserId`, `updatedAt`, `deletedAt`.
- `Models/UserSettings.swift` — `didSet` on each `@Published` now calls `SyncStore.settingsChanged()`.
- `Models/AuthUser.swift` (new) — `@Model` for the signed-in user (id/email/name/photoURL/provider/providerSubject/dates).
- `Models/SyncOp.swift` (new) — `@Model` for queued delete ops (used for retrying server-side deletes when the network is down).

### iOS — Service layer
- `Services/APIClient.swift` (new) — actor; URLSession wrapper, attaches Bearer JWT, 401→refresh→retry, 5xx exponential backoff, multipart upload helper.
- `Services/AuthService.swift` (new) — `@MainActor` `ObservableObject`; Google sign-in via `GIDSignIn.signIn(withPresenting:)`; Apple sign-in via `SignInWithAppleButton`'s `onCompletion`; tokens stored in Keychain; `restoreSession()` called from app start; `deleteAccount()` calls `DELETE /api/account`.
- `Services/SyncService.swift` (new) — actor; `flush(using:ownerUserId:)` pushes dirty records via `updatedAt > lastPushedAt`; `pull(using:ownerUserId:)` consumes `/api/sync/state` and merges with last-write-wins; `runMigrationIfNeeded(...)` claims pre-account local data and bulk-uploads.
- `Services/SyncCoordinator.swift` (new) — `@MainActor` `ObservableObject`; debounces triggerSync, listens for foreground + reachability, exposes `state` (idle/syncing/failed) and `lastSyncedAt` for UI.
- `Services/SyncStore.swift` (new) — thin wrapper for all SwiftData mutations: `save(meal:)`, `delete(meal:)`, `save(savedFood:)`, `delete(savedFood:)`, `recordSearch(of:)`, `deleteAllMeals(in:)`, `settingsChanged()`. Updates `updatedAt` + sets `ownerUserId` + triggers sync.
- `Services/BackendConfig.swift` (new) — reads `BackendBaseURL` from Info.plist (so it can be set per build config). Holds Keychain key constants.

### iOS — Mutation site rewires
- `ViewModels/AnalysisViewModel.swift` — meal save now goes through `SyncStore.save(meal:)`.
- `ViewModels/HistoryViewModel.swift` — meal delete now goes through `SyncStore.delete(meal:)`.
- `ViewModels/ManualFoodLogViewModel.swift` — AI-search SavedFood insert, search-count bump, and meal save now go through `SyncStore`.
- `Views/History/MealDetailView.swift` — meal/food edit + delete paths go through `SyncStore`.
- `Views/Settings/SettingsView.swift` — "Clear all data" now uses `SyncStore.deleteAllMeals(in:)` so the wipe propagates to the server. New `AccountSection()` sits at the top of the Settings form.

### iOS — Authentication UI (`Views/Auth/`)
- `AuthGateView.swift` (new) — wraps `ContentView`; shows `SignInView` when `auth.isAuthenticated == false`.
- `SignInView.swift` (new) — Apple button (`SignInWithAppleButton` native), Google button, "What data is stored?" link, footer with privacy policy.
- `DataSyncDisclosureView.swift` (new) — pre-sign-in modal listing what stays local vs. what is uploaded, why, retention, third-party processors. Required for Guideline 5.1.1 / 5.1.2.
- `AccountSection.swift` (new) — Settings block with profile row, sync status indicator (idle/syncing/failed + last-synced relative time), Sign out, Delete account (with confirmation alert; Guideline 5.1.1(v)).

### iOS — App entry + project config
- `CalorieCounterApp.swift` — registers `AuthUser` and `SyncOp` in the SwiftData schema; wraps root in `AuthGateView`; injects `AuthService.shared` and `SyncCoordinator.shared` as environment objects; calls `syncCoordinator.attach(container:)` and `authService.restoreSession()` on first appear; `onOpenURL` routes Google's OAuth callback into `GIDSignIn`.
- `Podfile` — added `pod 'GoogleSignIn', '~> 7.1'`.
- `Info.plist` — added `CFBundleURLTypes` (placeholder `REPLACE_WITH_REVERSED_CLIENT_ID`) and `BackendBaseURL` (placeholder `https://example.com/api`).
- `CalorieCounter.entitlements` (new) — declares `com.apple.developer.applesignin`.
- `project.pbxproj` — registered all 12 new Swift files (PBXBuildFile + PBXFileReference + group membership + Sources phase); created new `Views/Auth` group; wired `CODE_SIGN_ENTITLEMENTS` for both Debug and Release configs.

### PHP backend (`backend/`)
- `schema.sql` — seven tables: `users`, `meals`, `food_items`, `saved_foods`, `user_settings`, `refresh_tokens`, `auth_rate_limit`. UUID CHAR(36) primary keys throughout; FKs cascade on user delete.
- `composer.json` — declares `firebase/php-jwt`, `google/apiclient`, `ramsey/uuid`. User runs `composer install` locally and uploads `vendor/`.
- `.gitignore` — blocks `config.php`, `vendor/`, `private_uploads/`.
- `api/.htaccess` — HTTPS redirect, security headers (HSTS, X-Frame-Options, X-Content-Type-Options), blocks direct access to `config.php` / `lib/` / `routes/` / `vendor/`, rewrites everything to `index.php`.
- `api/config.example.php` — template the user copies to `config.php` (DB creds, JWT secret, Google iOS client ID, uploads path, token TTLs, rate-limit config).
- `api/index.php` — front controller, regex-based routing, exception → JSON error response.
- `api/lib/http.php` — `json_ok`, `json_error`, `read_json_body`, `iso_to_mysql`, `mysql_to_iso`, `uuid_valid`, IP detection.
- `api/lib/db.php` — PDO bootstrap, `db_now()` (UTC).
- `api/lib/jwt.php` — `jwt_issue_access` (HS256, 15-min default), `jwt_verify_access`, `refresh_token_create` (raw + SHA-256 hash), `uuid_v4`.
- `api/lib/auth.php` — `verify_google_id_token` (via `Google\Client::verifyIdToken`), `verify_apple_id_token` (fetches Apple JWKs, decodes ES256), `require_auth` (the per-route bearer-token gate), `rate_limit_login`.
- `api/lib/photo_storage.php` — saves uploaded photos outside webroot as `{uploads_dir}/{user_uuid}/{photo_uuid}.jpg`, re-encodes as JPEG to strip EXIF, enforces 4 MB / JPEG/PNG/HEIC.
- `api/routes/auth_login.php` — POST {provider, idToken[, email, name, photoURL]} → upserts user + issues access & refresh tokens.
- `api/routes/auth_refresh.php` — POST {refreshToken} → rotates the refresh token, returns new pair.
- `api/routes/auth_logout.php` — POST → revokes all of the caller's refresh tokens.
- `api/routes/auth_me.php` — GET → current user profile.
- `api/routes/meals.php` — POST upsert, PATCH /meals/{id}, DELETE /meals/{id} (soft-delete + unlinks photo file).
- `api/routes/saved_foods.php` — same shape for saved foods.
- `api/routes/settings.php` — GET + POST singleton.
- `api/routes/photos.php` — POST upload, GET authenticated stream via `readfile`, DELETE.
- `api/routes/sync_state.php` — GET ?since=ISO → returns meals/savedFoods/settings updated since the cutoff, including soft-deleted rows so the client can drop them.
- `api/routes/migrate_bulk.php` — POST multipart (JSON meta + photo files) → one-shot upload for first-sign-in migration.
- `api/routes/account_delete.php` — DELETE → wipes photo dir, revokes refresh tokens, deletes user row (cascades through all child tables).
- `README.md` — 12-step end-to-end setup guide (Google Cloud, Apple Dev portal, cPanel DB, Composer, file upload, smoke test, App Store Connect updates).

### Repo-level
- `.gitignore` — added belt-and-suspenders rules to keep backend secrets out of git.
- `changes.md` (new) — this file. A `feedback-changes-log` memory enforces that future changes add an entry here.
- `CLAUDE.md` (new) — project orientation for Claude Code: layout, standing conventions, build commands, architecture notes, common gotchas, links to authoritative docs (`backend/README.md`, `changes.md`, the plan file, and per-machine memory). Goal: future sessions spend tokens on the work instead of re-exploring.

### What syncs vs. what stays local

| Local-only | Synced |
| --- | --- |
| OpenAI API key (Keychain) | MealEntry + FoodItem + photos |
| `app_review_*` UserDefaults flags | user-added SavedFood (manual or AI-sourced) |
| `savedFoodPrefilled_v1` flag | UserSettings (calorie goal, range display, onboarding) |
| Bundled foods from `FoodDatabase.json` | — |

### Compliance ledger
- Guideline 4.8 — Sign in with Apple shown first, Google second.
- Guideline 5.1.1(v) — Account deletion reachable in 2 taps (Settings → AccountSection → Delete account); cascades local + server data.
- Guideline 5.1.1 / 5.1.2 — `DataSyncDisclosureView` shown on first launch before sign-in; data minimization in the sync table above.
- HTTPS enforced server-side via `.htaccess` redirect; ATS default on the client.
- All DB queries use PDO prepared statements with `ATTR_EMULATE_PREPARES = false`.
- JWT signing secret lives only in `config.php` on the server; never shipped in the app.

### What the user must do manually (in order)
See `backend/README.md` for the full version. Headlines:

1. Google Cloud Console → create iOS OAuth client for `com.mfaizanshaikh.caloriecounter`; download a new `GoogleService-Info.plist`; replace the placeholder reversed client ID in `Info.plist`.
2. Apple Developer portal → enable Sign in with Apple capability on the bundle id.
3. cPanel → create MySQL DB + user; run `backend/schema.sql`.
4. Local → `cd backend && composer install --no-dev --optimize-autoloader`.
5. cPanel → create `/home/<user>/private_uploads/` outside webroot.
6. Copy `backend/api/config.example.php` → `config.php`; fill in DB creds, JWT secret (`openssl rand -base64 48`), Google iOS client ID, uploads path.
7. FTP `backend/api/*` (with `.htaccess` and `vendor/`) into `public_html/api/`. Smoke test: `curl https://yourdomain.com/api/health`.
8. Replace `BackendBaseURL` placeholder in `CalorieCounter/Info.plist` with the real URL.
9. `pod install`; open `CalorieCounter.xcworkspace` (not `.xcodeproj`); build on a real device.
10. Update privacy policy at `https://mfaizanshaikh.wordpress.com/...` and App Store Connect privacy nutrition labels.
