# Little Later for Chrome

Save the page you're on (or any link, by right-clicking it) to Little Later. It appears in the phone app, with a reminder if you pick one. Shared folders send it to your friends too.

## Install (no Chrome Web Store needed)
1. Download `Little-Later-Chrome-Extension.zip` from the latest release and unzip it.
2. Open `chrome://extensions` and switch on **Developer mode** (top right).
3. Click **Load unpacked** and pick the unzipped folder.
4. Pin Little Later from the puzzle-piece menu. Shortcut: Ctrl+Shift+S (⌘⇧S on Mac).

Sign in with the same email and password as the app, or with Google.

## How it works
- `popup.*`: the save window. `background.js`: right-click menu and the Google sign-in hand-off.
- `lib/auth.js`: Firebase sign-in over HTTPS (email must be confirmed, as in the app).
- `lib/cloud.js`: adds the save to `/users/{email}` and, for shared folders, `/collab_folders/{id}`, the same documents the app syncs.
- Google sign-in runs on `website/auth.html` (GitHub Pages) and passes the session to the extension. The `key` in `manifest.json` keeps the extension ID fixed (`bnjempplmmjhmhefphffeamopfimiomb`) so the website can find it.
