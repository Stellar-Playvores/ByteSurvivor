# Deployment checklist

Follow these steps in order. You need: a Stellar testnet account with XLM, and access to the repo on GitHub.

**Requirement to play:** players **must** link their [Freighter](https://www.freighterapp.com/) account on the title screen in order to play (browser extension).

**Contracts already deployed on Testnet (reference):** Policy `CC73YP4HYHXG42QQDYQGLG3HAQ3VQC2GF4E5Z7ILUOGZNR4M7EUIZBUO`, Verifier `CCQQDZBSOREFGWRX7BJKG4S42CPYASWVOUFLTFNKV5IQ3STOJ7ROSOBA`. If you use this deployment, step 1 is only about configuring the frontend with that POLICY_ID; if you want to deploy your own, follow 1.2.

---

## 1. Deploy contracts to Stellar Testnet (or use the existing ones)

### 1.1 Testnet account

If you don't have a testnet account:

- Create one at [Stellar Laboratory (testnet)](https://laboratory.stellar.org/#account-creator?network=test) or with Freighter.
- Get testnet XLM from [Friendbot](https://laboratory.stellar.org/#explorer?resource=friendbot&endpoint=create) (enter your public address).

### 1.2 Deploy and initialize

From the repo root, with the WASM already compiled:

```bash
# Use your Stellar public key (G...) or an identity configured with stellar keys add
export SOURCE_ACCOUNT=GXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
./scripts/deploy_contracts_testnet.sh
```

The script will deploy the verifier and policy, run `init` with the Game Hub and `set_verifier`, and at the end print something like:

- `VITE_BYTE_SURVIVOR_CONTRACT_ID=...` (POLICY_ID)

**If you prefer not to use the script**, [DEPLOY_ZK_STEPS.md](DEPLOY_ZK_STEPS.md) has the commands one by one. In all of them you must add `--source-account <YOUR_ACCOUNT>`.

### 1.3 Configure locally

In the `.env` at the project root (use the POLICY_ID from the script or the already deployed one):

```env
VITE_BYTE_SURVIVOR_CONTRACT_ID=CC73YP4HYHXG42QQDYQGLG3HAQ3VQC2GF4E5Z7ILUOGZNR4M7EUIZBUO
VITE_ZK_PROVER_URL=http://localhost:3333
```

If you deployed your own contracts, substitute your POLICY_ID.

To test locally with ZK, leave the prover at `http://localhost:3333` and start the server with `npm run server`.

---

## 2. Deploy the prover (production)

For the game on GitHub Pages to use ZK, the frontend has to call a public prover.

### Option A: Render (recommended)

1. Go to [render.com](https://render.com) and log in (e.g. with GitHub).
2. **New → Blueprint**. Connect the ByteSurvivor repo.
3. Render will detect `render.yaml` and create the `bytesurvivor-zk-prover` service.
4. **Deploy**. When it finishes, copy the service URL (e.g. `https://bytesurvivor-zk-prover.onrender.com`).

### Option B: Render without Blueprint

1. **New → Web Service**. Connect the repo.
2. **Environment**: Docker.
3. **Dockerfile path**: `Dockerfile.prover`.
4. **Deploy** and copy the URL.

### Option C: Railway

1. [railway.app](https://railway.app) → New Project → Deploy from GitHub.
2. In the service: Settings → Build → Dockerfile path: `Dockerfile.prover`.
3. Deploy and copy the public URL.

Save that URL as the **prover URL** (you'll use it in step 3).

---

## 3. Add secrets on GitHub (GitHub Pages build)

For the GitHub Pages build to include the contract and prover:

1. Open the repo on GitHub → **Settings → Secrets and variables → Actions**.
2. **New repository secret**:
   - **Name:** `VITE_BYTE_SURVIVOR_CONTRACT_ID`  
     **Value:** the POLICY_ID (if you use the current deployment: `CC73YP4HYHXG42QQDYQGLG3HAQ3VQC2GF4E5Z7ILUOGZNR4M7EUIZBUO`; if you deployed your own, the one the script printed).
3. **New repository secret**:
   - **Name:** `VITE_ZK_PROVER_URL`  
     **Value:** the prover URL from step 2 (e.g. `https://bytesurvivor-zk-prover.onrender.com`).

There's no need to prefix the secret name with `http://` or `https://`; the value is the full prover URL.

After the next push to `main`, the deploy workflow will use these secrets and the game on GitHub Pages will be configured with contract and ZK.

---

## 4. Verify everything works

1. **Local:** `npm run server` and `npm run dev`. **Connect Freighter** (required to play), new run, play until you die. You should see "Submitted to ZK leaderboard" or "Submitted to casual leaderboard".
2. **Online:** Open the GitHub Pages URL. **Link Freighter** (required), new run, play until you die. The same should happen if the secrets are correct and the prover is running.
3. **Stellar Expert:** On [Game Hub (testnet)](https://stellar.expert/explorer/testnet/contract/CB4VZAT2U3UC6XFK3N23SKRF2NDCMP3QHJYMCHHFMZO7MRQO6DQ2EMYG) you can review the `start_game` and `end_game` invocations after starting a run and after dying.

---

## Summary

| Step | Where | What |
|------|-------|------|
| 1 | Terminal (with SOURCE_ACCOUNT) | `./scripts/deploy_contracts_testnet.sh` |
| 2 | Render or Railway | Deploy with `Dockerfile.prover`, copy the prover URL |
| 3 | GitHub → Settings → Secrets | Add `VITE_BYTE_SURVIVOR_CONTRACT_ID` and `VITE_ZK_PROVER_URL` |
| 4 | Browser + Stellar Expert | Play and verify on-chain submissions |