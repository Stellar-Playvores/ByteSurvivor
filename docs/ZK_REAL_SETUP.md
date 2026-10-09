# ZK Real Proof Setup (ByteSurvivor)

Guide to compile the Circom circuit, generate a real VK/proof, and use them with `zk_verifier` and `submit_zk`.

## Requirements

- **Node** 18+
- **circom** 2.1.x — [Installation](https://docs.circom.io/getting-started/installation/)
- **snarkjs** — `npm i -g snarkjs`
- **Rust + wasm32** — for contracts (already covered in `contracts/README.md`)

## 1. Circuit (Circom)

The `circuits/GameRun.circom` circuit **validates the game rule**: `score >= wave * 5` (MIN_SCORE_PER_WAVE = 5). It uses `GreaterEqThan` from circomlib; a proof is only valid if it satisfies the rule.

It has **6 public signals**:

| Signal      | Use                          |
|-------------|------------------------------|
| run_hash_hi | high 128 bits of run_hash    |
| run_hash_lo | low 128 bits of run_hash     |
| score       | u32                          |
| wave        | u32                          |
| nonce       | u64                          |
| season_id   | u32                          |

The contract requires `vk.ic.len() == pub_signals.len() + 1`, i.e. **7 elements in `ic`** (6 signals + constant term).

## 2. Compile the circuit and trusted setup

```bash
# From repo root
chmod +x scripts/zk/build_circuit.sh
./scripts/zk/build_circuit.sh
```

This generates in `circuits/build/`:

- `GameRun.r1cs`, `GameRun_js/GameRun.wasm`
- `GameRun_final.zkey`
- `vkey.json`

If `pot12_final.ptau` doesn't exist, the script tries to download it; if that fails, you have to generate the ceremony (see snarkjs docs).

## 3. Generate a real proof

Create `circuits/input.json` (or copy `input.json.example`):

```json
{
  "run_hash_hi": "0",
  "run_hash_lo": "0",
  "score": "100",
  "wave": "5",
  "nonce": "1",
  "season_id": "1"
}
```

Generate the proof and the contract export:

```bash
node scripts/zk/generate_proof.js circuits/input.json circuits/build
```

Output: `circuits/build/contract_proof.json` (proof, vk and pub_signals in hex for the contract).

## 4. Verify with the verifier (Soroban)

After deploying the verifier (see [DEPLOY_ZK_STEPS.md](DEPLOY_ZK_STEPS.md); build with **wasm32v1-none**). On testnet it's best to use `--source-account <SOURCE>` in the invocations.

**Reference (Testnet):** Verifier `CCQQDZBSOREFGWRX7BJKG4S42CPYASWVOUFLTFNKV5IQ3STOJ7ROSOBA`, Policy `CC73YP4HYHXG42QQDYQGLG3HAQ3VQC2GF4E5Z7ILUOGZNR4M7EUIZBUO`.

```bash
# Replace VERIFIER_ID and the values with the ones from contract_proof.json
stellar contract invoke --id <VERIFIER_ID> --source-account <SOURCE> --network testnet --sim-only -- \
  verify_proof \
  --vk '{"alpha":"<hex>","beta":"<hex>","gamma":"<hex>","delta":"<hex>","ic":["<hex>",...]}' \
  --proof '{"a":"<hex>","b":"<hex>","c":"<hex>"}' \
  --pub_signals '["<hex>","<hex>",...]'
```

To build the arguments from `contract_proof.json`:

```bash
node scripts/zk/contract_args_from_proof.js circuits/build
```

(You can use the output to fill vk/proof/pub_signals in the invocation.)

## 5. Option B: backend generates the proof (flow integrated into the game)

The server (`npm run server`) exposes `POST /zk/prove` with body:

`{ "run_hash_hex", "score", "wave", "nonce", "season_id" }`

The backend writes `circuits/build/input.json`, runs `generate_proof.js` and returns the JSON ready for the contract. The frontend calls `requestZkProof(proverUrl, payload)` and then `submitZkFromProver(addr, sign, proverUrl, payload)`.

- **Environment variable (frontend):** `VITE_ZK_PROVER_URL` (default `http://localhost:3333`). If it's defined and so is the contract, dying in a new run uses **ranked (ZK)** instead of casual.
- **Requirement:** a new run (not "continue") to have a `runSeed`; server with the compiled circuit and `snarkjs` in PATH.

## 6. submit_zk with a real proof (policy)

From the frontend (or with Stellar CLI):

- **player**: the player's address (auth).
- **proof / vk / pub_signals**: the ones from `contract_proof.json` (in ScVal format; the client already uses proof/vk/pubSignals).
- **nonce**: unique per (player, season_id); it must match the `nonce` used in the circuit (the same one as in input.json).
- **run_hash**: 32 bytes; it can be the first 32 bytes of the binding (e.g. `pub_signals[0]` in hex = 32 bytes).
- **season_id, score, wave**: the same as in input.json (and as in pub_signals).

Minimal JS example (with `contract_proof.json` loaded). Convert hex to `Buffer` so the SDK builds the ScVals:

```js
import { submitZk } from './contracts/gameClient.js';

const contractProof = await fetch('/circuits/build/contract_proof.json').then(r => r.json());

// contract_proof.json uses hex; the client can expect proof/vk/pubSignals as ScVal or as objects with Buffers
const toBuf = (hex) => Buffer.from(hex, 'hex');
const zk = {
  proof: {
    a: toBuf(contractProof.proof.a),
    b: toBuf(contractProof.proof.b),
    c: toBuf(contractProof.proof.c),
  },
  vk: {
    alpha: toBuf(contractProof.vk.alpha),
    beta: toBuf(contractProof.vk.beta),
    gamma: toBuf(contractProof.vk.gamma),
    delta: toBuf(contractProof.vk.delta),
    ic: contractProof.vk.ic.map(toBuf),
  },
  pubSignals: contractProof.pub_signals.map(toBuf),
};
const runHashHex = contractProof.pub_signals[0]; // 32 bytes = run_hash_hi
const nonce = 1;
const seasonId = 1;
const score = 100;
const wave = 5;

await submitZk(
  signerPublicKey,
  signTransaction,
  zk,
  nonce,
  runHashHex,
  seasonId,
  score,
  wave
);
```

If your `gameClient.submitZk` builds the ScVals internally, pass `zk` with the structure it expects (e.g. already converted to `xdr.ScVal` according to the SDK).

## 7. Resource simulation (Testnet)

```bash
stellar contract invoke --sim-only \
  --id <POLICY_ID> \
  --source-account <SOURCE> \
  --network testnet \
  -- submit_zk \
  --player <ADDRESS> \
  --proof '...' \
  --vk '...' \
  --pub_signals '...' \
  --nonce 1 \
  --run_hash <32_BYTES_HEX> \
  --season_id 1 \
  --score 100 \
  --wave 5
```

Check the output for: CPU/memory and events (e.g. `zk_run_submitted`).

## 8. End-to-end validation checklist

- [ ] **Circuit**: `circuits/GameRun.circom` compiles with `build_circuit.sh` (r1cs, wasm, zkey, vkey.json).
- [ ] **Real proof**: `input.json` + `generate_proof.js` → `contract_proof.json` without errors.
- [ ] **Verifier**: `stellar contract invoke --sim-only` with proof/vk/pub_signals from `contract_proof.json` → success (true result or no verification error).
- [ ] **Policy**: `submit_zk` with the same proof, unique nonce, consistent run_hash/season_id/score/wave → Ok(()); leaderboard and `zk_run_submitted` event visible.
- [ ] **Anti-replay**: second `submit_zk` call with the same (player, nonce, season_id) → fails (Replay).
- [ ] **Frontend**: manual submission with a real proof from JS (submitZk + contract_proof.json) reaches the verifier and the tx succeeds.
- [ ] **Resources**: Testnet simulation with a real proof documented (CPU/memory) for the runbook.

## Notes

- **run_hash**: in the circuit it's two fields (hi/lo); in the contract it's a single `BytesN<32>`. For binding, use e.g. the 32 bytes of the first public signal as the on-chain run_hash.
- **Byte order**: G1 and Fr: big-endian 32 bytes. G2: 128 bytes as **x0‖x1‖y0‖y1** (each limb 32 bytes big-endian); Soroban BN254 does not use the Ethereum/snarkjs x1‖x0‖y1‖y0 order. The `export_for_contract.js` script already exports in the correct format.
- **Powers of Tau**: in production use a multi-participant ceremony; the script uses a small ptau for development/demo.