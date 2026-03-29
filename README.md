# Memories

Supabase-backed book app: database migrations and a Flutter mobile client.

## Repository layout

| Path | Purpose |
|------|---------|
| [`supabase/migrations/`](supabase/migrations/) | Ordered SQL migrations (enum, RLS, profiles, triggers, indexes) |
| [`memories_app/`](memories_app/) | Flutter app (`supabase_flutter`, login/register, home placeholders) |

## Apply database migrations

1. Open the [Supabase SQL Editor](https://supabase.com/dashboard) for your project.
2. Run each file in **numeric order** (`20250329120000` → `20250329120004`), or use the Supabase CLI:

   ```bash
   supabase link --project-ref YOUR_PROJECT_REF
   supabase db push
   ```

**Notes:**

- If `user_book_status.status` is not yet type `book_read_status`, fix the column type before relying on [`20250329120000_book_read_status_enum.sql`](supabase/migrations/20250329120000_book_read_status_enum.sql) (the default change assumes the column already uses that enum).
- If you already created `profiles` manually, [`20250329120002_profiles_and_policies.sql`](supabase/migrations/20250329120002_profiles_and_policies.sql) uses `CREATE TABLE IF NOT EXISTS` and replaces policies by name.
- **Home screen buttons** are hardcoded in Flutter (no `home_actions` table) per project plan.
- **Storage** buckets are not created here; add them when you store avatars or files in Supabase.

## Flutter app

See [`memories_app/README.md`](memories_app/README.md) for `flutter create`, `dart-define` setup, and run instructions.
