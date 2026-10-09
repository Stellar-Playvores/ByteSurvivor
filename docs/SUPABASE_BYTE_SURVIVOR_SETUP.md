# ByteSurvivor — Supabase (SEP-10 users)

Current project: **https://pdfflyvkkgtvsujiafkf.supabase.co**

> **Existing database (`cosmic_coder_*` tables):** before continuing, run
> `server/db/migrate_bytesurvivor_rename.sql` in the SQL Editor to rename them to
> `bytesurvivor_*`. The SQL below is only for new databases.

---

## 1. Create the table in Supabase

1. Go to the [Supabase Dashboard](https://supabase.com/dashboard) → your **pdfflyvkkgtvsujiafkf** project.
2. **SQL Editor** menu → **New query**.
3. Paste and run this SQL:

```sql
-- ByteSurvivor SEP-10: users by public_key + username; JWT stored on sign
CREATE TABLE IF NOT EXISTS public.bytesurvivor_users (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  public_key      VARCHAR(56) NOT NULL UNIQUE,
  username        VARCHAR(64) NULL,
  current_jwt     TEXT NULL,
  jwt_expires_at  TIMESTAMPTZ NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS bytesurvivor_users_public_key_idx
  ON public.bytesurvivor_users (public_key);

ALTER TABLE public.bytesurvivor_users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all for backend"
  ON public.bytesurvivor_users
  FOR ALL
  USING (true)
  WITH CHECK (true);
```

4. Press **Run**. The backend can now store users (wallet + username) and the JWT when the user signs the challenge.

### 1b. If you already had the table (only add the JWT columns) — **important if the JWT comes back null!**

If you created the table **before** having these columns, the backend can't store the JWT and in Supabase you'll see `current_jwt` and `jwt_expires_at` as **null**. Run this in the **SQL Editor** (once):

```sql
ALTER TABLE public.bytesurvivor_users
  ADD COLUMN IF NOT EXISTS current_jwt TEXT NULL,
  ADD COLUMN IF NOT EXISTS jwt_expires_at TIMESTAMPTZ NULL;
```

Do "Connect wallet" and sign again; after that the JWT should appear in the table.

---

## 2. Environment variables (backend)

The server uses **SUPABASE_URL** and **SUPABASE_ANON_KEY** (or **SUPABASE_SERVICE_ROLE_KEY**).  
**Do not commit the keys to the repo.** Configure them in:

- **Local**: `.env` file at the project root (make sure it's in `.gitignore`).
- **Render**: Service Dashboard → **Environment** → Add Variable.

| Variable | Value | Notes |
|--------|--------|-------|
| `SUPABASE_URL` | `https://pdfflyvkkgtvsujiafkf.supabase.co` | Project URL of your project. |
| `SUPABASE_ANON_KEY` | *(your Anon Key)* | In Supabase: **Project Settings → API**. You can use the **Anon key (legacy)** starting with `eyJ...` or the **Publishable key** `sb_publishable_...`. If something fails, try the legacy one. |

**Recommended so the JWT is stored:** use the **Service Role Key** on the backend (prevents RLS from blocking the JWT UPDATE). In Supabase: **Project Settings → API → service_role** (secret). Add on Render: `SUPABASE_SERVICE_ROLE_KEY` = that key. The code prefers it over the anon key.

---

## 3. Verify it works

1. Start the backend with the variables defined: `node server/index.js` (or your command).
2. Do a SEP-10 login from the game (Freighter → challenge → token).
3. In Supabase: **Table Editor** → `bytesurvivor_users` table. You should see a row with your `public_key`, the `username` (if you saved it) and the current JWT in `current_jwt` (stored when the user signs the challenge with Freighter).

---

## 4. (Optional) Direct PostgreSQL connection

If at some point you want to use **DATABASE_URL** instead of the Supabase client (for example for migrations or scripts), the connection string would be:

- Host: `db.pdfflyvkkgtvsujiafkf.supabase.co`
- Port: `5432`
- Database: **`postgres`** (not `postgresm`; the default name in Supabase is `postgres`).
- User: `postgres`
- Password: the one Supabase gave you when creating the project.

**Important:** don't put the password in the code or commit it to Git. Environment variables only (e.g. on Render as a **Secret**). For ByteSurvivor, **SUPABASE_URL + SUPABASE_ANON_KEY** is enough; you don't need `DATABASE_URL` if you're already using the Supabase client.

---

## 5. (Recommended) Leaderboard in Supabase

So that the ranking is always active and visible to everyone (even without login), the backend serving `GET/POST /leaderboard` (e.g. bytesurvivor.onrender.com or bytesurvivor-zk-prover) should persist entries in Supabase. Example table:

```sql
CREATE TABLE IF NOT EXISTS public.bytesurvivor_leaderboard (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  address      VARCHAR(56) NOT NULL UNIQUE,
  name         VARCHAR(64) NULL,
  score        BIGINT NOT NULL DEFAULT 0,
  wave         INT NOT NULL DEFAULT 0,
  games_played INT NOT NULL DEFAULT 0,
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS bytesurvivor_leaderboard_score_idx
  ON public.bytesurvivor_leaderboard (score DESC);

ALTER TABLE public.bytesurvivor_leaderboard ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read for leaderboard"
  ON public.bytesurvivor_leaderboard FOR SELECT USING (true);
```

The backend uses `SUPABASE_SERVICE_ROLE_KEY` to write (bypasses RLS). `GET/POST /leaderboard` uses Supabase when it's configured; otherwise it falls back to memory and file persistence in `server/data/leaderboard.json` (persists across restarts if the server has a persistent disk). The frontend, if the API returns empty, shows the runs saved in localStorage so you always see something when playing.

The backend should: on `POST /leaderboard` upsert by `address` (update name, score, wave, games_played); on `GET /leaderboard` return the entries sorted by score. That way the frontend only shows this ranking and there's no local leaderboard with "Anonymous".

### Progress table (optional)

To persist high score, high wave, upgrades and save state per player:

```sql
CREATE TABLE IF NOT EXISTS public.bytesurvivor_progress (
  address           VARCHAR(56) PRIMARY KEY,
  high_score        BIGINT NOT NULL DEFAULT 0,
  high_wave         INT NOT NULL DEFAULT 0,
  upgrades          JSONB NULL,
  legendaries       JSONB NULL,
  save_state        JSONB NULL,
  selected_character VARCHAR(32) NOT NULL DEFAULT 'bytesurvivor',
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.bytesurvivor_progress ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role full access progress"
  ON public.bytesurvivor_progress FOR ALL USING (true);
```

The backend uses this table in `GET/POST /player/:address/progress` when Supabase is configured; otherwise it uses memory.