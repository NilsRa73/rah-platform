# RAH Project Brain Cloud Sync Setup

The application code is already integrated into Command Center v1.4. Supabase needs one database setup operation before cloud synchronization can store data.

## One-time activation

1. Open the Supabase project dashboard:
   https://supabase.com/dashboard/project/zespiaujgkyclsfhayji
2. Open **SQL Editor**.
3. Open this repository file:
   `supabase/001_project_brain_sync.sql`
4. Copy the complete SQL file into SQL Editor.
5. Press **Run**.
6. Refresh the RAH Command Center and log in.
7. Open **Innstillinger** and use **Project Brain Cloud Sync**.

## What the SQL creates

- One `rah_user_state` row per authenticated user
- A JSONB state document containing projects, tasks, Project Brain, missions and settings
- Row Level Security
- Policies that allow users to access only their own row
- Automatic server-side `updated_at` timestamps
- Account deletion cleanup through `on delete cascade`

## Sync behavior

- Local browser storage remains the primary offline fallback.
- When a user logs in, Raven compares local and cloud timestamps.
- The newest state is used automatically.
- Changes are uploaded after a short debounce and every 30 seconds.
- Manual controls allow forced upload or forced download.
- Failed cloud sync never deletes the local state.

## Security

The browser uses only the Supabase publishable key. Access is enforced by authenticated-user RLS policies. Never place a Supabase service-role key in this repository or browser code.

## Recovery

If synchronization behaves unexpectedly:

1. Use **Eksporter lokale data** in Command Center settings.
2. Turn **Auto-sync** off.
3. Use **Bruk denne enheten** to overwrite cloud state, or **Hent fra skyen** to restore the cloud copy.

The local export remains the independent recovery copy.
