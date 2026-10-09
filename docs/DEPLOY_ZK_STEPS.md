# Deploying ZK (Stellar Testnet)

Run these commands **from the repo root** once you have Stellar CLI configured and an account with XLM on testnet.

## Deployed contracts (reference)

If they are already deployed on testnet, you can use these IDs in the frontend (`.env` and GitHub Secrets):

| Contract | ID (Testnet) | Stellar Expert |
|----------|--------------|----------------|
| **Policy (bytesurvivor)** | `CC73YP4HYHXG42QQDYQGLG3HAQ3VQC2GF4E5Z7ILUOGZNR4M7EUIZBUO` | [View policy](https://stellar.expert/explorer/testnet/contract/CC73YP4HYHXG42QQDYQGLG3HAQ3VQC2GF4E5Z7ILUOGZNR4M7EUIZBUO) |
| **Verifier (zk_verifier)** | `CCQQDZBSOREFGWRX7BJKG4S42CPYASWVOUFLTFNKV5IQ3STOJ7ROSOBA` | [View verifier](https://stellar.expert/explorer/testnet/contract/CCQQDZBSOREFGWRX7BJKG4S42CPYASWVOUFLTFNKV5IQ3STOJ7ROSOBA) |
| **Game Hub** | `CB4VZAT2U3UC6XFK3N23SKRF2NDCMP3QHJYMCHHFMZO7MRQO6DQ2EMYG` | [View Game Hub](https://stellar.expert/explorer/testnet/contract/CB4VZAT2U3UC6XFK3N23SKRF2NDCMP3QHJYMCHHFMZO7MRQO6DQ2EMYG) |

To play with this deployment: `VITE_BYTE_SURVIVOR_CONTRACT_ID=CC73YP4HYHXG42QQDYQGLG3HAQ3VQC2GF4E5Z7ILUOGZNR4M7EUIZBUO`.

---

## 1. Compile the contract WASM

Use **rustup** (not Homebrew). For Soroban testnet you need the **wasm32v1-none** target (with `wasm32-unknown-unknown` it may fail with "reference-types not enabled"):

```bash
export PATH="$HOME/.cargo/bin:$PATH"
rustup target add wasm32v1-none
cd contracts
cargo build -p zk_types
cargo build -p zk_verifier --target wasm32v1-none --release
cargo build -p bytesurvivor --target wasm32v1-none --release
cd ..
```

## 2. Deploy the verifier

You need a testnet account with XLM (e.g. from [Friendbot](https://laboratory.stellar.org/#explorer?resource=friendbot&endpoint=create)). Replace `<SOURCE>` with your public key (G...) or with an identity from `stellar keys list`.

```bash
cd contracts
stellar contract deploy --source-account <SOURCE> --network testnet --wasm target/wasm32v1-none/release/zk_verifier.wasm
```

**Save the ID it returns** as `VERIFIER_ID`.

## 3. Deploy the policy (bytesurvivor)

```bash
stellar contract deploy --source-account <SOURCE> --network testnet --wasm target/wasm32v1-none/release/bytesurvivor.wasm
```

**Save the ID** as `POLICY_ID`.

## 4. Initialize the policy with Game Hub and verifier

The `bytesurvivor` contract has `init(env, game_hub: Address)` and `set_verifier(env, verifier: Address)`.

**Game Hub (verified):** the policy calls `start_game(game_id, session, player, system_player, x, y)` and `end_game(session, success)`. This matches the mock in `contracts/bytesurvivor/src/tests.rs` and the Game Hub of Stellar Game Studio.

Game Hub on Testnet: `CB4VZAT2U3UC6XFK3N23SKRF2NDCMP3QHJYMCHHFMZO7MRQO6DQ2EMYG`

```bash
# Init: pass the Game Hub address as --game_hub
stellar contract invoke --id <POLICY_ID> --source-account <SOURCE> --network testnet -- \
  init --game_hub CB4VZAT2U3UC6XFK3N23SKRF2NDCMP3QHJYMCHHFMZO7MRQO6DQ2EMYG

# Register the verifier (required for submit_zk)
stellar contract invoke --id <POLICY_ID> --source-account <SOURCE> --network testnet -- \
  set_verifier --verifier <VERIFIER_ID>
```

## 5. Configure the frontend

In the `.env` at the project root:

```env
VITE_BYTE_SURVIVOR_CONTRACT_ID=<POLICY_ID>
VITE_ZK_PROVER_URL=http://localhost:3333
```

Restart the frontend (`npm run dev`) so it loads the new contract.

## Checklist

- [ ] Circuit compiled (`circuits/build/GameRun_final.zkey` exists)
- [ ] Server running (`npm run server` → http://localhost:3333)
- [ ] `circom` 2.x and `snarkjs` installed (to recompile the circuit if needed)
- [ ] WASM contracts compiled and deployed on testnet
- [ ] Policy initialized with Game Hub and `set_verifier(VERIFIER_ID)`
- [ ] `.env` with `VITE_BYTE_SURVIVOR_CONTRACT_ID` and `VITE_ZK_PROVER_URL`
- [ ] **New** run (not "Continue") and wallet connected to use ZK on death