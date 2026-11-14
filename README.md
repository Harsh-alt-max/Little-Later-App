# Little Later

Save links, reminders and to-dos from any app, and get them back right when you need them.

| Folder | What it is |
|---|---|
| `app/` | The Android app (Flutter), v1.4 |
| `website/` | Download page, invite page, privacy and terms. Published to https://harsh-alt-max.github.io/Little-Later-App/ |
| `firebase/` | Firestore security rules (paste into Firebase console → Firestore → Rules) |
| `extension/` | Chrome extension (coming next) |

## How releases work

Nothing to install. Every change pushed to `main`:

1. **Build app** (Actions tab) checks the code, runs the tests, and builds `Little-Later.apk` and `Little-Later.aab`.
2. It publishes them as the latest **Release**. The website's *Download for Android* button always points to the newest one.
3. **Publish website** updates the site whenever `website/` changes.

## One-time setup (repo owner)

**Settings → Secrets and variables → Actions → New repository secret**, add:

| Name | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | the signing key file, base64 (sent privately) |
| `ANDROID_KEYSTORE_PASSWORD` | its password (sent privately) |
| `ANDROID_KEY_ALIAS` | `littlelater` |
| `GOOGLE_WEB_CLIENT_ID` | optional, turns on "Continue with Google" |

**Settings → Pages**: Source *Deploy from a branch*, branch `gh-pages`, folder `/ (root)`.

Never delete or share the signing key: every future update must be signed with it.

## Firebase (project `littlelater-61969`)

- Authentication → Sign-in method → turn on **Email/Password** (and **Google** if wanted).
- Firestore → Rules → paste `firebase/firestore.rules` → Publish.
- For Google sign-in: Project settings → Android app `com.littlelater.app` → add fingerprints
  SHA-1 `C8:A1:17:0D:6A:72:62:C4:CE:BC:B8:42:CA:86:04:E2:C7:59:E3:72` and
  SHA-256 `59:C7:83:44:F7:94:79:29:FF:14:3F:A6:78:F4:D2:42:C6:D2:9E:CB:07:21:4F:3D:D8:7C:8C:C1:A3:25:0A:D6`,
  then copy the **Web client ID** (Authentication → Google → Web SDK configuration) into the `GOOGLE_WEB_CLIENT_ID` secret.
