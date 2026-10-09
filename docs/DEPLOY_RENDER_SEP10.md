# SEP-10 deployment on Render (ByteSurvivor)

## ✅ STEP 1 — Backend structure

The `server/` folder must contain:

```
server/
  config/     → sep10.js
  auth/       → challenge.js, token.js
  middleware/ → jwtAuth.js
  routes/     → auth.js
  db/         → schema.sql, pool.js, users.js
  index.js
```

If anything is missing, use the code that Cursor generated for SEP-10.

---

## 🗄 STEP 2 — Database (CRITICAL)

### On Render

1. **New → PostgreSQL** (if you don't have one yet).
2. Copy the **External Database URL** (or Internal if the backend is on Render).
3. In your **backend service** (Web Service) add the environment variable:
   - `DATABASE_URL` = that URL (Internal for the same Render account, External for local/other hosts).

### Run the schema (mandatory)

If you don't run the schema, the `users` table doesn't exist and nothing gets saved.

From your machine (with `psql` installed):

```bash
# Replace with your Render External Database URL (or use the variable if you have it)
psql "postgresql://bytesurvivor_user:YOUR_PASSWORD@dpg-XXXXX.oregon-postgres.render.com/bytesurvivor" -f server/db/schema.sql
```

Or if you already have `DATABASE_URL` in your environment:

```bash
psql "$DATABASE_URL" -f server/db/schema.sql
```

**Alternative without `psql`** (from the repo, with Node):

```bash
DATABASE_URL="postgresql://user:password@host:5432/bytesurvivor" node scripts/run_db_schema.js
```

Use your Render **External Database URL** (only to run this script once; don't commit the URL with the password to the repo). On Render (Dashboard → PostgreSQL → Info) you have the **PSQL Command**; you can also paste the contents of `server/db/schema.sql` into Render's SQL console.

---

## 🔐 STEP 3 — Environment variables (backend on Render)

In the backend **Web Service**, under **Environment** add:

| Variable | Value | Notes |
|----------|--------|-------|
| `DATABASE_URL` | *(Internal Database URL of your PostgreSQL on Render)* | E.g. `postgresql://...@dpg-XXX-a/bytesurvivor` |
| `SEP10_SERVER_SECRET_KEY` | `S...` | A **new** Stellar account used only by the server. Not the contract's nor your personal wallet. |
| `JWT_SECRET` | Long random string | E.g. `openssl rand -hex 32` |
| `SEP10_NETWORK_PASSPHRASE` | `Test SDF Network ; September 2015` | Testnet. For mainnet use the Public Network passphrase. |
| `SEP10_HOME_DOMAIN` | `bytesurvivor.app` | Your domain. |
| `SEP10_WEB_AUTH_DOMAIN` | Public URL of the backend | E.g. `https://bytesurvivor-api.onrender.com` (must be the URL you serve `/auth/challenge` from). |

Important: `SEP10_SERVER_SECRET_KEY` must be a real Stellar account generated for the server (create a new keypair and use its `S...` secret).

---

## 🧪 STEP 4 — Test before the frontend

### 1. Challenge

```http
GET https://your-backend.onrender.com/auth/challenge?account=GXXXXXXXX...
```

Expected response:

```json
{
  "transaction": "...XDR base64...",
  "network_passphrase": "Test SDF Network ; September 2015"
}
```

If you don't see that, check `server/config/sep10.js` and make sure `SEP10_SERVER_SECRET_KEY` is defined.

### 2. Token

1. Sign the `transaction` returned by the challenge in Freighter (using the indicated `network_passphrase`).
2. Send the signed XDR:

```http
POST https://your-backend.onrender.com/auth/token
Content-Type: application/json

{"transaction": "SIGNED_XDR_IN_BASE64"}
```

Expected response:

```json
{
  "token": "eyJ...",
  "public_key": "G..."
}
```

If you get that, SEP-10 is working on the backend.

---

## 🎮 STEP 5 — Frontend

1. In the project (or in the Render/GitHub Pages build) configure:
   - `VITE_API_URL=https://your-backend.onrender.com`  
   (no trailing slash; no `/auth`).

2. Login must use the wallet to sign, not the manual SDK:
   - Already in the code: `stellarWallet.signTransaction(xdr, networkPassphrase)`.
   - The `network_passphrase` comes in the challenge response and is passed to Freighter.

With that, the Connect wallet → Challenge → Sign in Freighter → Token → JWT and user in DB flow should work end to end.