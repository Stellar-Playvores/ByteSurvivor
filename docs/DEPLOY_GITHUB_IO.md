# Full GitHub Pages deployment (game + ZK contracts)

To get the game running at `https://bytesurvivor-games.vercel.app/` with contracts and ZK:

---

## Summary

| Component | Where                                 | Status                |
| --------- | ------------------------------------- | --------------------- |
| Frontend  | GitHub Pages (deploy on push to main) | ✅ Already configured |
| Contracts | Stellar Testnet (Policy + Verifier)   | ✅ Already deployed   |
| ZK Prover | Render / Railway (generates proofs)   | Deployment pending    |
| Secrets   | GitHub → Settings → Secrets           | Configuration pending |

---

## 1. GitHub Pages (frontend)

The `.github/workflows/deploy.yml` workflow already deploys on every push to `main`.

**Check:** GitHub → Settings → Pages → Source: GitHub Actions must be enabled.

---

## 2. Contracts on Stellar Testnet (already deployed)

Current contracts on Testnet:

| Contract               | ID                                                         |
| ---------------------- | ---------------------------------------------------------- |
| Policy (bytesurvivor)  | `CC73YP4HYHXG42QQDYQGLG3HAQ3VQC2GF4E5Z7ILUOGZNR4M7EUIZBUO` |
| Verifier (zk_verifier) | `CCQQDZBSOREFGWRX7BJKG4S42CPYASWVOUFLTFNKV5IQ3STOJ7ROSOBA` |
| Game Hub               | `CB4VZAT2U3UC6XFK3N23SKRF2NDCMP3QHJYMCHHFMZO7MRQO6DQ2EMYG` |

If you want to deploy your own: [DEPLOY_ZK_STEPS.md](DEPLOY_ZK_STEPS.md) or [DEPLOY_CHECKLIST.md](DEPLOY_CHECKLIST.md).

---

## 3. ZK Prover (Render)

The prover generates the proof when you die. It must run on a public server.

### 3.1 Generate and commit circuits/build

The prover's Dockerfile uses `circuits/build/`. Build locally and commit:

```bash
# From repo root
npm run zk:build
git add circuits/build/
git commit -m "Add circuits/build for prover"
git push
```

### 3.2 Deploy on Render

1. [render.com](https://render.com) → Log in (e.g. with GitHub)
2. **New → Blueprint** → Connect the `ByteSurvivor` repo
3. Render detects `render.yaml` and creates `bytesurvivor-zk-prover`
4. **Deploy**
5. When it finishes, copy the URL (e.g. `https://bytesurvivor-zk-prover.onrender.com`)

**Alternative without Blueprint:** New → Web Service → Repo → Environment: Docker → Dockerfile path: `Dockerfile.prover`

---

## 4. GitHub Secrets

For the GitHub Pages build to include the contract and prover:

1. GitHub → Repo → **Settings → Secrets and variables → Actions**
2. **New repository secret:**
   - **Name:** `VITE_BYTE_SURVIVOR_CONTRACT_ID`
   - **Value:** `CC73YP4HYHXG42QQDYQGLG3HAQ3VQC2GF4E5Z7ILUOGZNR4M7EUIZBUO`
3. **New repository secret:**
   - **Name:** `VITE_ZK_PROVER_URL`
   - **Value:** `https://bytesurvivor-zk-prover.onrender.com` (your URL from step 3)

---

## 5. Push and verify

```bash
git push origin main
```

The workflow will run and deploy. In 1–2 minutes the app will be at:

`https://bytesurvivor-games.vercel.app/`

**Check:**

1. Open the URL
2. Connect Freighter (required)
3. Start Game (ZK Ranked)
4. Play until you die
5. You should see "✓ ZK RANKED — Submitted to on-chain leaderboard"
6. On [Stellar Expert (Policy)](https://stellar.expert/explorer/testnet/contract/CC73YP4HYHXG42QQDYQGLG3HAQ3VQC2GF4E5Z7ILUOGZNR4M7EUIZBUO) you'll see `submit_zk` after dying

---

## Fallback

If the prover fails or is down, the game falls back to `submit_result` (casual leaderboard). Players can keep playing and submitting scores, but without ZK ranked.

---

## Checklist

- [ ] `npm run zk:build` and `git add circuits/build/` + commit
- [ ] Deploy the prover on Render, copy the URL
- [ ] Add secrets `VITE_BYTE_SURVIVOR_CONTRACT_ID` and `VITE_ZK_PROVER_URL`
- [ ] `git push origin main`
- [ ] Verify on the GitHub Pages URL
