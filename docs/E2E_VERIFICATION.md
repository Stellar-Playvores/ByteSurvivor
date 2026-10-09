# E2E verification checklist

Use this checklist to confirm the full flow works.

## Visual walkthrough

**The end-to-end flow:**

1. **Start run** → Connect Freighter → **Start Game** → signs `start_match()` → the contract calls `start_game()` on the Game Hub.
2. **Play off-chain** → The player plays in the browser until they die (health 0).
3. **On death** → The client requests the proof from the prover → sends `submit_zk` to the contract → verifier validates the proof on-chain → leaderboard updated.
4. **Verify on-chain** → On Stellar Expert (Policy or Game Hub), see `submit_zk` / `end_game` and the leaderboard entries.

**Expected message on death:** "Submitted to ZK leaderboard" or "Submitted to casual leaderboard".

**Real circuit:** the Circom circuit requires `score >= wave * 5` (MIN_SCORE_PER_WAVE = 5); an invalid proof (e.g. score < wave*5) doesn't verify. Anti-replay: the same (player, nonce, season_id) can't be used twice.

## Contract tests (automated)

**Quick option (real proof + tests):**

```bash
npm run zk:e2e
```

Compiles the circuit, generates a real proof (score=100, wave=5) and runs the verifier + policy tests (incl. `test_real_proof_verifier_and_submit_zk`).

**Or manually (from repo root):**

```bash
npm run zk:proof   # genera contract_proof.json
cd contracts
cargo test -p zk_verifier -p bytesurvivor
```

All tests should pass. These cover verifier behaviour, policy init, `submit_zk` (anti-replay, invalid proof, valid proof), and `submit_result`.

## Manual E2E (game + chain)

1. **Deploy and config**
   - [ ] Verifier and policy deployed on Stellar Testnet (see [DEPLOY_ZK_STEPS.md](DEPLOY_ZK_STEPS.md)). Current deployment: Policy `CC73YP4HYHXG42QQDYQGLG3HAQ3VQC2GF4E5Z7ILUOGZNR4M7EUIZBUO`, Verifier `CCQQDZBSOREFGWRX7BJKG4S42CPYASWVOUFLTFNKV5IQ3STOJ7ROSOBA`.
   - [ ] Policy initialized: `init(game_hub)`, `set_verifier(verifier_id)` (already done for the IDs above).
   - [ ] Frontend: `.env` has `VITE_BYTE_SURVIVOR_CONTRACT_ID=CC73YP4HYHXG42QQDYQGLG3HAQ3VQC2GF4E5Z7ILUOGZNR4M7EUIZBUO` (or your POLICY_ID) and `VITE_ZK_PROVER_URL` (local or production prover).

2. **Start game**
   - [ ] Connect wallet (Freighter) on title screen — **required to play**; the game requires a linked Freighter account.
   - [ ] If ZK prover is configured, menu shows "START GAME (ZK Ranked)".
   - [ ] Click **Start Game** (new run, not Continue). Sign the transaction.
   - [ ] Optional: On Stellar Expert, open the Game Hub contract and confirm a `start_game` invocation from your policy.

3. **Play and die**
   - [ ] Play until death (health reaches 0).
   - [ ] On death you see BITS earned and one of: "Submitted to ZK leaderboard", "Submitted to casual leaderboard", or "Could not submit to chain".
   - [ ] Optional: On Stellar Expert, confirm `end_game` on the Game Hub and/or `submit_zk` / `submit_result` on the policy.

4. **Fallback**
   - [ ] If the ZK prover is down or returns an error, the game should fall back to `submit_result` (casual) and show "Submitted to casual leaderboard" (or "Could not submit to chain" if that also fails).

5. **Leaderboard**
   - [ ] Open Leaderboard in the game; if using on-chain data, entries should reflect recent runs.
   - [ ] Ranked runs (ZK) update the per-season leaderboard; casual runs update the legacy leaderboard.

## Production (GitHub Pages)

- [ ] Repo secrets set: `VITE_BYTE_SURVIVOR_CONTRACT_ID`, `VITE_ZK_PROVER_URL` (public prover URL).
- [ ] After push to `main`, the built game uses these and shows ZK Ranked when the prover is configured.
- [ ] Players can play at the deployed URL (they must connect Freighter to play) and see submissions on-chain.
