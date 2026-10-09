# Deploying the ZK Prover server (production)

For the online game (GitHub Pages) to submit runs in **ranked (ZK)** mode, the frontend must call `POST /zk/prove` from the browser. That requires a publicly reachable server.

## Deploy the prover on Render (recommended)

1. Go to [render.com](https://render.com) and log in with GitHub.
2. **New** → **Blueprint** → connect the **Stellar-Playvores/ByteSurvivor** repo (or whichever you have).
3. Render will read `render.yaml`: it will create the **bytesurvivor-zk-prover** service with `Dockerfile.prover`. Don't change the name if you want to use the URL that's already in `config.json`.
4. **Apply** and wait for the first deploy. The URL will be `https://bytesurvivor-zk-prover.onrender.com`.
5. The app at [https://stellar-playvores.github.io/ByteSurvivor/](https://stellar-playvores.github.io/ByteSurvivor/) already has that URL configured in `public/config.json`; it will be used for the ZK proof when you die.

**Note:** on Render's free plan the service may sleep after inactivity; the first ZK request can take a few seconds to respond.

## If you see "Could not submit to chain" or "ZK prover unavailable"

- **Prover unreachable:** the URL in `public/config.json` (`VITE_ZK_PROVER_URL`) must point to a deployed server (Render, Railway, etc.). If the prover isn't deployed or the URL is wrong, the ZK proof won't be generated and the run is submitted as CASUAL (or it fails if the contract call fails too).
- **To make the ZK proof run:** deploy the prover following this guide, copy the public URL and update `public/config.json` with that URL. Commit and push so the deploy uses the new config.

## Option 1: Docker (Railway, Fly.io, etc.)

The repo includes `Dockerfile.prover`. Requirement: the `circuits/build/` folder must exist (with `GameRun_final.zkey`, `GameRun_js/`). It's already in the repo.

### Railway

1. Connect the repo at [railway.app](https://railway.app).
2. New Project → Deploy from GitHub → select the repo.
3. Settings → Root Directory: leave empty. Build: **Dockerfile** → Dockerfile path: `Dockerfile.prover`.
4. Variables: none required. Port 3333 (Railway assigns `PORT`; the server uses `process.env.PORT || 3333`).
5. Deploy. Use the public URL as `VITE_ZK_PROVER_URL` (e.g. `https://xxx.up.railway.app`).

**Important:** the current server listens on port 3333. Railway injects `PORT`; `server/index.js` must use `process.env.PORT || 3333`.

### Render

1. [render.com](https://render.com) → New → Web Service.
2. Connect the repo. Environment: **Docker**; Dockerfile path: `Dockerfile.prover`.
3. Deploy. Use the assigned URL as `VITE_ZK_PROVER_URL`.

### Fly.io

```bash
fly launch --dockerfile Dockerfile.prover --name bytesurvivor-zk-prover
fly deploy
```

Then `fly info` for the URL.

## Option 2: No Docker (Railway / Render with Node)

If you use "Native" on Railway/Render:

- Build command: `npm ci`
- Start command: `node server/index.js`
- Make sure `circuits/build/` is in the repo (already included).
- `snarkjs` must be available on the host (add it in package.json as a dependency or `npm install -g snarkjs` during the build).

## This project's URLs

- **App (game):** [https://stellar-playvores.github.io/ByteSurvivor/](https://stellar-playvores.github.io/ByteSurvivor/)
- **Prover (Render):** after deploying the Blueprint, the URL will be something like `https://bytesurvivor-zk-prover.onrender.com`. That URL is already in `public/config.json` as `VITE_ZK_PROVER_URL`.

## Configure the prover URL in the frontend

- **Deployed app:** `public/config.json` already has `VITE_ZK_PROVER_URL` pointing at the Render service. If you use a different service name, update that URL in `config.json` and commit.
- **Local:** you can use `.env` with `VITE_ZK_PROVER_URL=...` or `public/config.json`.

## CORS

`server/index.js` already sends `Access-Control-Allow-Origin: *` for API requests. If the frontend is on a different domain (e.g. GitHub Pages), requests to `/zk/prove` should work.