# ZK flow, anti-replay and leaderboard — With difficulty balance

**ByteSurvivor** uses zero-knowledge proofs (Groth16) on Soroban for a **provably fair** leaderboard. This document describes the ZK flow, anti-replay, the per-season leaderboard, and how to submit `submit_zk` from the frontend with the new balance (reduced damage, enemy scaling).

---

## 1. Validation rule: score >= wave × MIN_SCORE_PER_WAVE

Both the **contract** and the **client** require the run to satisfy:

- **score ≥ wave × MIN_SCORE_PER_WAVE** (e.g. MIN_SCORE_PER_WAVE = 5).

This avoids submissions with an unreasonably low score for the wave. With the new balance (nerfed weapons, tougher enemies), it's still achievable: the player earns XP from kills and wave completions; if they reach wave 5, they must have at least 50 score (total XP).

- **In the contract:** `submit_zk` and `submit_result` check this rule. If it's not met, `submit_zk` returns `InvalidInput`.
- **In the client:** `validateGameRules(wave, score)` in `src/zk/gameProof.js` returns `{ valid, reason }`. The frontend must validate before calling `submitZk` / `submitZkFromProver`; additionally, `submitZk` validates again and throws if it isn't met.

---

## 2. ZK flow (submit_zk)

1. **New run:** the client generates a `runSeed` when the run starts.
2. **On death:** compute `run_hash = H(player || wave || score || runSeed || timestamp)` (SHA-256).
3. **Client validation:** `validateGameRules(wave, score)` → if invalid, don't submit.
4. **Proof request (option B):** the client calls the backend `POST /zk/prove` with `{ run_hash_hex, score, wave, nonce, season_id }`. The backend runs the prover (Circom/snarkjs) and returns `contract_proof.json`.
5. **On-chain submit:** the client signs and calls `submit_zk(player, proof, vk, pub_signals, nonce, run_hash, season_id, score, wave)`.
6. **In the contract:**
   - Checks the verifier is configured, the VK shape, `score > 0`, `wave > 0`, **score ≥ wave × MIN_SCORE_PER_WAVE**.
   - Checks anti-replay: if `(player, nonce, season_id)` was already used → `Replay`.
   - Invokes the zk_verifier; if the proof is valid, it marks the nonce as used, updates the season leaderboard, calls the Game Hub `end_game` and emits the `zk_run_submitted` event.

The real proof (Circom) integrates using the same flow: the backend generates the proof with the same `run_hash`, `score`, `wave`, `nonce`, `season_id` that are later submitted in `submit_zk`.

---

## 3. Anti-replay (player, nonce, season_id)

- Each ranked submission uses a unique **nonce** (e.g. `Date.now()`).
- The contract stores **ReplayKey = (player, nonce, season_id)**. After a successful `submit_zk`, that key is marked as used.
- A second submission with the same `(player, nonce, season_id)` returns **Replay** and doesn't update the leaderboard.
- The proof includes the nonce as a public signal; the same proof can't be reused with a different nonce without generating another proof.

---

## 4. On-chain per-season leaderboard

- **Ranked (ZK):** the contract keeps a leaderboard per **season_id**: `LeaderboardKey { season_id }` → list of `ScoreEntry { player, score }`, sorted by score descending.
- On each successful `submit_zk`: the player's entry is updated or inserted (only updated if the new score is higher) and the list is re-sorted.
- **Event:** `zk_run_submitted` is emitted with (player, season_id, score, wave, run_hash) for indexers and analytics.

---

## 5. How to submit submit_zk from the frontend (JS) with the new balance

With the current balance (harder), the total score (XP) may be lower for the same wave; it must still satisfy `score >= wave * MIN_SCORE_PER_WAVE`. Minimal example:

```javascript
import * as gameClient from './contracts/gameClient.js';
import { validateGameRules, computeGameHash, generateRunSeed } from './zk/gameProof.js';

// 1) When starting a new run (not "Continue")
const runSeed = generateRunSeed(); // keep in memory for this run

// 2) On death: wave, score = Math.floor(state.totalXP)
const wave = this.waveNumber;
const score = Math.floor(state.totalXP);

// 3) Validate the rules (required)
const { valid, reason } = validateGameRules(wave, score);
if (!valid) {
  console.warn('No submit_zk:', reason);
  return;
}

// 4) Option B: request the proof from the backend and submit
const run_hash_hex = await computeGameHash(addr, wave, score, runSeed, Date.now());
await gameClient.submitZkFromProver(addr, sign, proverUrl, {
  run_hash_hex,
  score,
  wave,
  nonce: Date.now(),
  season_id: 1
});
```

`submitZk` (and therefore `submitZkFromProver`) already calls `validateGameRules` internally and throws if the rule isn't met.

---

## 6. Tests

- **test_submit_zk_invalid_input_score_below_min:** `submit_zk` with score=40, wave=5 (minimum 50) must fail with InvalidInput.
- **test_submit_zk_valid_updates_nonce_leaderboard_and_emits_event:** checks that after a valid `submit_zk` the per-season leaderboard is updated.
- **test_real_proof_verifier_and_submit_zk:** with `circuits/build/contract_proof.json` generated, verifies the proof on the verifier and a successful `submit_zk` on the policy.

The tests use (wave, score) values that satisfy the rule (e.g. wave=5 score=100, wave=10 score=200) to reflect the current balance.