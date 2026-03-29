# Memories (Flutter)

Flutter client for your Supabase project: email/password sign-in, auth-only access, and a home screen with placeholder actions.

## Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) SDK (stable channel)
- A Supabase project URL and **anon** public key (Dashboard → Project Settings → API)

## First-time setup

From this folder (`memories_app`):

```bash
flutter create .
flutter pub get
```

`flutter create .` adds Android, iOS, web, and desktop runners if they are missing.

## Run with Supabase credentials

**Recommended (avoids PowerShell pitfalls):** copy `dart_defines.example.json` to `dart_defines.json` in this folder (that file is gitignored). Fill in your project URL and the **client** API key from **Dashboard → Project Settings → API**:

- **New keys:** use **publishable** `sb_publishable_...` (safe in the app).
- **Legacy:** use **anon** `public` — long `eyJ...` JWT.
- **Never** use **secret** `sb_secret_...` or **service_role** in the app — Supabase returns errors like *Invalid API key*.

```bash
flutter run -d web-server --web-port=8080 --dart-define-from-file=dart_defines.json
```

**Run and Debug** in Cursor/VS Code: [.vscode/launch.json](.vscode/launch.json) already uses `--dart-define-from-file=dart_defines.json`.

### PowerShell: `--dart-define=`

There must be **no space** after `=`. Wrong: `--dart-define= https://...` (Flutter will say it cannot find a target file named `SUPABASE_URL=https://...`). Correct:

```powershell
flutter run -d web-server --web-port=8080 `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=eyJ...
```

## Auth behavior

- No session → **Login** screen (and **Create an account**).
- Valid session → **Home** with four placeholder buttons; each shows a snackbar until you wire features.
- **Sign out** in the app bar clears the session.

Configure **Site URL** and **Redirect URLs** in Supabase Auth if you use email confirmation or password recovery.

For **local web** (`flutter run -d web-server`), add your exact origin to **Redirect URLs**, e.g. `http://localhost:8090` and `http://localhost:8090/**` (use the port you run on). The app passes `emailRedirectTo` as `Uri.base.origin` on web so PKCE/email confirmation can return to the same dev server.

## Database

SQL migrations for RLS, profiles, and triggers live in [`../supabase/migrations`](../supabase/migrations). Apply them with the Supabase CLI (`supabase db push`) or by running the files in order in the SQL Editor.
