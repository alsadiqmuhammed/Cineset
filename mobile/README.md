# CINESET for Android

An offline Android app with the same screens as the web app. Everything is stored on the phone:
accounts (passwords hashed with PBKDF2), projects, feedback, approvals, quotes, invoices,
contracts, calendar, portfolio and uploaded files. Nothing is sent to a server.

## Features
- **Works offline.** The `/api` routes from `server.js` run inside the app (`web/local-backend.js`) with the same rules for creators and clients.
- **Data stays on the phone.** Records and files are kept in the app's private storage (IndexedDB) and survive restarts and updates.
- **First start:** create a creator account, or tap "Try it with sample data".
- **Clients:** "Invite client" creates the client's account on the phone and shows a one-time password to hand over, so clients can sign in on the same device to review and approve.
- **Backup and restore** (Settings): export everything, with or without files, to a `.json` file and restore it on another phone.
- **Files:** play videos in the app (full screen supported), preview images, and save any file to the phone.
- **Claude AI (optional):** add an Anthropic API key in Settings and the AI Assistant writes full production plans with `claude-opus-5-5`. Without a key it uses the built-in template. Claude needs internet; everything else works offline.
- **Android back button:** closes dialogs, returns to the overview, then leaves the app.

## Limits
- One phone, no sync. Two phones don't see each other's data; use backup and restore to move data.
- Backups that include large videos are built in memory. For many large videos, use "Export without files" and keep the video masters elsewhere.
- Uninstalling the app or using Android's "Clear storage" deletes the data. Export a backup first.

## Build

Requirements: Node 20+, JDK 17+, Android SDK (platform 35, build-tools 35).

```bash
npm install                      # once, from the repo root
npm run build:mobile             # copies public/ + mobile/web into the app's assets
cd mobile/android
echo "sdk.dir=/path/to/Android/sdk" > local.properties
./gradlew assembleRelease        # -> app/build/outputs/apk/release/app-release.apk
```

### Signing
Release builds are signed with the keystore given in environment variables:

```bash
export CINESET_KEYSTORE=/path/to/cineset-release.jks
export CINESET_KEYSTORE_PASSWORD=...
export CINESET_KEY_ALIAS=cineset        # optional, default "cineset"
```

Without them, the release APK is signed with the debug key. **Always sign updates with the same
keystore.** Android refuses to install an update signed with a different key, and the only way
around that is uninstalling, which deletes the data on the phone. Keep the keystore and its
password safe and out of the repository.

### Updating
Raise `versionCode` (and `versionName`) in `app/build.gradle`, rebuild and install the new APK
over the old one. Data is kept.
