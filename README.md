# AgentQuestBadge — Agent ID Hackathon project

A free Quest Board + collectible badge for Agent ID holders, built for the
Agent ID Hackathon (Binance Wallet x BNB Chain, submission period
18 Nov – 9 Dec 2026, 60,000 USDC prize pool).

**What it is:** Agent ID holders connect their wallet, claim one free
"Agent Quest Badge" NFT (ERC-721, 1 per holder), and complete one free daily
quest with a short on-chain note. All quests appear on a public board.
No payments, no fees, no promised returns — the badge is a souvenir.

**How Agent ID is used (core, not decoration):**
1. **Access control** — `claim()` and `completeQuest()` both require the
   caller to hold an Agent ID, checked on-chain every call via
   `registry.balanceOf(caller) > 0`.
2. **Identity** — every quest is recorded with the holder's address; the
   frontend resolves it to the holder's `name.ai` Agent ID for display.

## Contract

- `src/AgentQuestBadge.sol` — ERC-721 "Agent Quest Badge" (AQB).
  Solidity ^0.8.24, OpenZeppelin Contracts v5.4.0
  (ERC721, Ownable, ReentrancyGuard).
- `src/mocks/MockAgentIdRegistry.sol` — TEST/TESTNET ONLY mock of the
  Agent ID registry (the real registry does not exist on testnet).
- Agent ID registry (BNB Chain mainnet):
  `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`

### Owner permissions (minimal, disclosed)

The ONLY owner function is `setBaseURI()` (change where token metadata is
served from). The owner CANNOT mint badges, pause the contract, freeze or
burn tokens, or withdraw funds. There is no payable function — the contract
can never receive or hold user funds. No return/yield promises anywhere.

### Functions

| Function | Who | Cost | Notes |
|---|---|---|---|
| `claim()` | Agent ID holder | free, 1 per address | Mints badge, tokenId from 1 |
| `completeQuest(string note)` | Agent ID holder | free, 1 per UTC day | Note 1–280 bytes, stored on-chain |
| `hasAgentId(address)` | anyone | view | `registry.balanceOf > 0` |
| `canCompleteQuestToday(address)` | anyone | view | |
| `getQuest(uint256)` / `quests(uint256)` | anyone | view | Board data |
| `questCountOf(address)` | anyone | view | |
| `setBaseURI(string)` | owner only | — | Metadata base URI |

Events: `BadgeClaimed(holder, tokenId)`, `QuestCompleted(holder, day, questId, note)`,
`BaseURIUpdated(baseURI)`.

## Build & test

Requires [Foundry](https://getfoundry.sh) (forge 1.9.0 used).

```bash
forge build
forge test --match-contract AgentQuestBadgeTest          # 18 unit tests
forge test --fork-url https://bsc-dataseed.binance.org/ \
  --match-contract AgentQuestBadgeForkTest               # 5 fork tests vs real registry
```

See [TEST-REPORT.md](TEST-REPORT.md) for full results and gas numbers.

## Deploy (mainnet) — via the canonical CREATE2 factory

The Binance Agentic Wallet (`baw`) cannot deploy a contract directly
(`contract-call preview` requires `--to`; there is no deploy command), so
mainnet deployment goes through the **canonical CREATE2 factory** (Arachnid
deterministic deployment proxy), already present on BSC mainnet:

- Factory: `0x4e59b44847b379578588920cA78FbF26c0B4956C`
  (bytecode verified on-chain: the canonical deployer proxy)
- Salt: `keccak256("agentquest-badge-v1")` =
  `0x9a794cf8e75229665bf6b340ad95962bd8e3f6dc0eaedeba9d641a050ed72b64`
- Factory calldata (raw, NO function selector): salt (32 bytes) ++ initCode
  — precomputed in `artifacts/factory-calldata.txt` (8,547 bytes).
- **Expected contract address (deterministic CREATE2):**
  `0x00c5579F105fE340eE197E9aF103E06b33fFEa3a`
  — verified three ways (`cast create2` with init-code and with
  init-code-hash, plus manual `keccak256(0xff ++ factory ++ salt ++
  keccak256(initCode))`) AND by a read-only `eth_call` simulation against
  BSC mainnet, which returned exactly this address. The target address was
  confirmed empty (no code) at simulation time. Full proof in
  [TEST-REPORT.md](TEST-REPORT.md) §7, details in
  `artifacts/factory-deploy.json`.

Because the factory is `msg.sender` during construction, the owner is passed
explicitly as a constructor argument (see `src/AgentQuestBadge.sol`):
registry `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`, baseURI `""`
(set later via `setBaseURI` after metadata is hosted), owner = Ahmad's agent
wallet `0xD7FCd6bD011253E32b8B96A0Dc815d30C6B930cB`.

- Deploy gas: **1,779,304** (eth_estimateGas, BSC mainnet RPC);
  1,749,203 measured on a local anvil fork of mainnet. Suggested gas limit
  **2,000,000**. Cost at 1 gwei ≈ **0.00178 BNB** (~Rp 19.200 at
  BNB $590.37); at the current 0.05 gwei ≈ 0.000089 BNB (~Rp 960).
  Agent wallet balance 0.007028 BNB covers the 1-gwei cost ~3.95x.

### Preview command (run by the main agent AFTER Ahmad confirms)

```bash
baw contract-call preview --binanceChainId 56 \
  --from 0xD7FCd6bD011253E32b8B96A0Dc815d30C6B930cB \
  --to 0x4e59b44847b379578588920cA78FbF26c0B4956C \
  --value 0 --gasLimit 2000000 \
  --inputData $(cat artifacts/factory-calldata.txt)
```

After the preview is approved in the Binance app and the transaction is
broadcast, verify the deployed contract on BscScan at the expected address
above, then update the frontend note (deployment no longer pending).

**DEPLOYED 19 Nov 2026 ~16:12 WIB** — tx
`0x031adfd5ab069f790e2ba2f1a87dd83707eee2027adb0dff6f364ecf864dd568`
(block 134477117, gas 1,749,203, fee 0.000243 BNB). Contract live at
`0x00c5579F105fE340eE197E9aF103E06b33fFEa3a`; owner/name/symbol/registry/
hasAgentId all verified on-chain.

For testnet/local reproduction, `script/Deploy.s.sol` works with forge
(direct deploy, not via the factory):

```bash
REGISTRY=0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F BASE_URI="" \
  OWNER=0xD7FCd6bD011253E32b8B96A0Dc815d30C6B930cB \
  forge script script/Deploy.s.sol --rpc-url bsc_testnet \
  --private-key $PRIVATE_KEY --broadcast
```

## Verify on BscScan

Compiler settings (also in `artifacts/compiler-settings.json`):

- Solidity **0.8.24+commit.e11b9ed9**
- Optimizer: **enabled, 200 runs**
- EVM version: **cancun**
- License: MIT

Verification options:
1. **Standard JSON input** (recommended): `artifacts/standard-json-input.json`
   (built from the artifact metadata; verified locally with solc 0.8.24 to
   reproduce the deployed creation bytecode byte-for-byte). Upload that file
   on BscScan's "Verify via Standard JSON Input" page, with constructor args
   from `artifacts/constructor-args.txt` (paste WITHOUT the leading `0x`).
2. **CLI** (needs a free BscScan API key):
   `forge verify-contract --chain-id 56 --constructor-args $(cat artifacts/constructor-args.txt) <deployed-address> src/AgentQuestBadge.sol:AgentQuestBadge --etherscan-api-key $BSCSCAN_API_KEY`
3. **Sourcify** (no key needed — DONE 19 Nov 2026, exact match):
   `forge verify-contract --chain-id 56 --verifier sourcify --constructor-args $(cat artifacts/constructor-args.txt) 0x00c5579F105fE340eE197E9aF103E06b33fFEa3a src/AgentQuestBadge.sol:AgentQuestBadge`

## Frontend

`frontend/index.html` — static single-file app (ethers.js v6 via CDN).
Connect wallet → check Agent ID → claim badge → post daily quest → board.
`CONTRACT_ADDRESS` is the deployed contract
`0x00c5579F105fE340eE197E9aF103E06b33fFEa3a`. Hosted via GitHub Pages from
`docs/` (same file): https://sobarkemat.github.io/agentquest/

## Decisions still needed from Ahmad

1. **Badge artwork + metadata hosting** — baseURI is empty at deploy; the
   badge needs art (image + JSON metadata per token). Options: simple
   generated badge image hosted on IPFS (free via Pinata free tier / NFT
   storage), or a plain on-chain SVG later. Owner can set baseURI any time.
2. **Project/website name** — must NOT contain "Binance" or "BNB".
   Working name: "AgentQuest". Needs a public repo + a hosted frontend URL
   for the hackathon submission form.
3. **Promotion to 30+ Agent ID holders** — the Innovation Award requires at
   least 30 Agent ID addresses interacting during the submission period.
   Needs X posts + community outreach (Ahmad's call on how to promote).
4. **Hackathon submission** — one project per team; the submission form
   link still needs to be located (announcement text does not embed it).
