# AI Calorie Coach — Backend Setup

Vanilla PHP + MySQL backend for Google/Apple sign-in and cloud sync. Runs on
typical cPanel shared hosting. No long-running processes, no shell access
required.

This guide is the **one-stop checklist** to go from zero to a working backend
that the iOS app talks to. Follow each step in order; skipping any one
breaks the rest.

> **A note on Firebase.** The backend does **not** use Firebase for anything —
> no Firebase Auth, no Firestore, no Firebase Storage. The PHP server is the
> only data backend.
>
> Firebase Console shows up in step 1 only as a *download source* for
> `GoogleService-Info.plist`. That file is the standard format the Google
> Sign-In iOS SDK reads to find `CLIENT_ID`. Because your project already has
> a Firebase project (`aicaloriecoach-1fd8b`), the easiest way to get an
> updated plist is to add the iOS OAuth client there and re-download. You
> could alternatively read the same `CLIENT_ID` from anywhere; we just use
> the standard convention.
>
> `pod 'Firebase/Analytics'` in the Podfile is a pre-existing usage
> analytics dependency, unrelated to sign-in. Remove it any time if you don't
> want it.

---

## 0. Prerequisites

- A domain you control (e.g. `api.yourdomain.com` or a subfolder of your
  existing site at `yourdomain.com/api`).
- cPanel shared hosting with PHP 8.1+ (tested on 8.3) and MySQL/MariaDB. Set the
  account's PHP version via cPanel → **MultiPHP Manager** before running
  `composer install` — earlier versions will fail dependency resolution because
  `google/apiclient` 2.18.4+ requires PHP `^8.1`.
- HTTPS enabled on the domain (Let's Encrypt via cPanel is free).
- A local machine with [Composer](https://getcomposer.org/) installed.
- Your Apple Developer account (Team ID `KJS5669LU6`).

---

## 1. Google Cloud — create the iOS OAuth client

The current `GoogleService-Info.plist` only has Firebase Analytics keys; it
does not yet contain a Sign-In `CLIENT_ID`. Add the iOS OAuth client now.

(The OAuth client itself lives in Google Cloud — Firebase Console is just a
convenient place to re-download the plist with the new `CLIENT_ID` baked in,
because Firebase projects are linked to Google Cloud projects under the hood.)

1. Go to <https://console.cloud.google.com/> and select the project
   `aicaloriecoach-1fd8b` (or whatever your Firebase project name is).
2. **APIs & Services → Credentials → "+ CREATE CREDENTIALS" → "OAuth client ID"**.
3. Application type: **iOS**.
4. Bundle ID: `com.mfaizanshaikh.caloriecounter`.
5. Click **Create**. You will see a new client with values like:
   ```
   Client ID:          12345-abcdef.apps.googleusercontent.com(807908453055-bt3p1mjlsi702sj2ci19ssfum1qus4dj.apps.googleusercontent.com)
   iOS URL scheme:     com.googleusercontent.apps.12345-abcdef
   ```
6. Download an updated `GoogleService-Info.plist` from **Firebase Console →
   Project Settings → Your apps → iOS**. The new plist will contain
   `CLIENT_ID` and `REVERSED_CLIENT_ID`. **Replace the file in the Xcode project.**
7. In `CalorieCounter/Info.plist`, replace the placeholder
   `REPLACE_WITH_REVERSED_CLIENT_ID` with the `REVERSED_CLIENT_ID` value
   (looks like `com.googleusercontent.apps.12345-abcdef`).
8. Copy the **Client ID** value — you'll paste it into `config.php` later.

---

## 2. Apple Developer Portal — Sign in with Apple

1. Go to <https://developer.apple.com/account>.
2. **Certificates, Identifiers & Profiles → Identifiers**. Find the app id
   `com.mfaizanshaikh.caloriecounter` and click into it.
3. Enable the **Sign In with Apple** capability. Save.
4. (Xcode will pick this up automatically because the entitlements file is
   already added to the project. Open the project once with the new
   provisioning profile so Xcode regenerates one with this capability.)

---

## 3. cPanel — MySQL database + user

1. cPanel → **MySQL Databases**.
2. Create a new database (note the full name, often prefixed like
   `youruser_calorie_coach`).
3. Create a new MySQL user with a strong password. Add the user to the new (dbname: u374583303_calorie_coach, db usr: u374583303_fshaikh, db pw: tV2p1JF7= )
   database with **ALL PRIVILEGES**.
4. cPanel → **phpMyAdmin** → select the new database → **Import** tab.
5. Upload `backend/schema.sql` and run it. All seven tables should appear.

---

## 4. Local — generate vendor/ via Composer

```bash
cd backend
composer install --no-dev --optimize-autoloader
```

This creates `backend/api/vendor/` containing `firebase/php-jwt`,
`google/apiclient`, and `ramsey/uuid`. The folder is git-ignored — you upload
it as a snapshot to the server.

---

## 5. Create the private uploads directory (outside webroot)

Via cPanel **File Manager** or SSH/FTP, create a directory **outside**
`public_html/` (e.g. one level above it):

```
/home/<your-cpanel-user>/private_uploads/
```

On Hostinger's multi-domain layout, "one level above public_html" is
`/home/<user>/domains/<your-domain>/private_uploads/` — same idea, still
outside the webroot.

The shipped `config.example.php` resolves `uploads_dir` via `__DIR__`
(`__DIR__ . '/../../../private_uploads'`), which lands one level above
`public_html/` automatically and works on either layout. You only need to
override the value if your install puts `api/` somewhere unusual.

Set permissions to `750` (owner read/write/execute, group read/execute, world
none). The directory must be writable by the PHP process and reachable under
`open_basedir` (if enabled by your host).

---

## 6. Configure `config.php`

1. On your local machine, copy `backend/api/config.example.php` to
   `backend/api/config.php` (this file is git-ignored).
2. Fill in:
   - `db.host` → usually `localhost` on cPanel
   - `db.name`, `db.user`, `db.password` → from step 3
   - `jwt_secret` → run `openssl rand -base64 48` and paste the output
   - `google_ios_client_id` → from step 1, value 8
   - `uploads_dir` → absolute path from step 5
3. Leave `apple_bundle_id` as `com.mfaizanshaikh.caloriecounter`.

---

## 7. Upload to the server

Via FTP (FileZilla, Cyberduck) or cPanel **File Manager**:

| Local                                       | Remote                                  |
| ------------------------------------------- | --------------------------------------- |
| `backend/api/*` (everything inside `api/`)  | `public_html/api/`                      |
| `backend/api/vendor/` (from Composer)       | `public_html/api/vendor/`               |
| `backend/api/config.php` (real one)         | `public_html/api/config.php`            |

You can also mount the API in a subfolder (e.g.
`public_html/ai-calorie-coach/api/`) — the router auto-detects its install
path from `SCRIPT_NAME`, so both `yourdomain.com/api/...` and
`yourdomain.com/ai-calorie-coach/api/...` work without code changes. Just make
sure the iOS app's `BackendBaseURL` (step 9) matches the path you chose.

Confirm `.htaccess` was uploaded alongside `index.php` — sometimes FTP clients
hide dotfiles. The dispatcher routes everything through it, so without it
nothing works.

---

## 8. Smoke test from your computer

```bash
curl -i https://yourdomain.com/api/health
# or, if you uploaded to a subfolder:
curl -i https://yourdomain.com/ai-calorie-coach/api/health
```

Expected response:

```
HTTP/2 200
Content-Type: application/json; charset=utf-8

{"status":"ok"}
```

If you see HTML or a 500 error, check `public_html/api/error_log` (cPanel
creates one alongside your scripts).

---

## 9. Point the iOS app at the backend

In `CalorieCounter/Services/BackendConfig.swift`, the URL is read from the
Info.plist key `BackendBaseURL`. Two ways to set it:

**Quick**: edit `CalorieCounter/Info.plist` and replace
`https://example.com/api` with `https://yourdomain.com/api`.

**Per-build-configuration (recommended)**: in Xcode → Project → Target →
Build Settings → User-Defined → add `BACKEND_BASE_URL` for Debug and Release
separately, then in `Info.plist` set `BackendBaseURL` to `$(BACKEND_BASE_URL)`.

---

## 10. Pod install & first build

```bash
cd /path/to/CalorieCounter
pod install
open CalorieCounter.xcworkspace   # NOT the .xcodeproj — use .xcworkspace from now on
```

Run on a real device (Sign in with Apple does not work on simulator with a
generic iCloud account). Sign in with Google or Apple. You should see the
disclosure sheet, then the main app. Log a meal; within seconds a row should
appear in your `meals` table.

---

## 11. App Store Connect updates

These are required before submitting a new build with sync + sign-in.

- **Privacy Policy**: update the policy at
  <https://mfaizanshaikh.wordpress.com/2026/02/27/privacy-policy-ai-calorie-coach/>
  to mention:
  - Account data (name, email) stored on your server.
  - Meal logs (food items, calories, photos) stored on your server.
  - Retention: until account is deleted from Settings.
  - Third-party processors: Apple, Google (sign-in only), OpenAI (analysis).
- **Privacy nutrition labels** (App Store Connect → App Privacy):
  - Name → Linked to user → App functionality
  - Email → Linked to user → App functionality
  - Photos → Linked to user → App functionality
  - Other user content (food logs) → Linked to user → App functionality
- **Sign in info**: under Build → App Review Information, mention that
  reviewers can sign in with their own Apple ID (Sign in with Apple).

---

## 12. Operational notes

- **Backup**: cPanel → Backup Wizard, run a full backup before major releases.
- **Log rotation**: PHP errors go to `public_html/api/error_log`. Trim it
  every few weeks.
- **JWT secret rotation**: changing the secret invalidates every active
  session. Tell users they will need to sign in again, or coordinate with a
  release.
- **Account deletion** is irreversible by design — the schema cascades
  everything. Don't add an "are you sure" alert that re-enters the user; the
  iOS client already double-confirms via the alert.

---

## Endpoints quick reference

| Method | Path                          | Auth     | Purpose                                  |
| ------ | ----------------------------- | -------- | ---------------------------------------- |
| GET    | `/api/health`                 | none     | Health check                             |
| POST   | `/api/auth/login`             | none     | Verify Google/Apple ID token, return JWT |
| POST   | `/api/auth/refresh`           | none     | Rotate refresh token                     |
| POST   | `/api/auth/logout`            | Bearer   | Revoke all refresh tokens                |
| GET    | `/api/auth/me`                | Bearer   | Current user profile                     |
| GET    | `/api/sync/state?since=ISO`   | Bearer   | Incremental pull                         |
| POST   | `/api/meals`                  | Bearer   | Upsert a meal                            |
| PATCH  | `/api/meals/{id}`             | Bearer   | Same as upsert (id from path)            |
| DELETE | `/api/meals/{id}`             | Bearer   | Soft-delete a meal + unlink its photo    |
| POST   | `/api/saved-foods`            | Bearer   | Upsert a saved food                      |
| DELETE | `/api/saved-foods/{id}`       | Bearer   | Soft-delete a saved food                 |
| GET    | `/api/settings`               | Bearer   | Current user settings                    |
| POST   | `/api/settings`               | Bearer   | Upsert user settings                     |
| POST   | `/api/photos`                 | Bearer   | Upload a photo, returns photo id         |
| GET    | `/api/photos/{id}`            | Bearer   | Stream a photo (owner only)              |
| DELETE | `/api/photos/{id}`            | Bearer   | Delete a photo (file + DB ref)           |
| POST   | `/api/migrate/bulk`           | Bearer   | First-sign-in mass upload                |
| DELETE | `/api/account`                | Bearer   | Permanent account deletion               |
