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
forge test --match-contract AgentQuestBadgeTest          # 16 unit tests
forge test --fork-url https://bsc-dataseed.binance.org/ \
  --match-contract AgentQuestBadgeForkTest               # 4 fork tests vs real registry
```

See [TEST-REPORT.md](TEST-REPORT.md) for full results and gas numbers.

## Deploy (mainnet)

Deployment goes through the Binance Agentic Wallet with a preview + user
confirmation (see the deploy preview prepared for Ahmad). The raw deployment
data is precomputed in `artifacts/`:

- `artifacts/deployment-calldata.txt` — full creation code + encoded
  constructor args, ready to paste as transaction data (value 0).
- Constructor args: registry `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`,
  baseURI `""` (set later via `setBaseURI` after metadata is hosted).
- Deploy gas: 1,742,982 (measured from the exact deployment calldata).
  Suggested gas limit 2,000,000, gas price ~1 gwei → ~0.00174 BNB.

For testnet/local reproduction, `script/Deploy.s.sol` works with forge:

```bash
REGISTRY=0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F BASE_URI="" \
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
1. **Standard JSON input** (recommended): `forge build` writes the standard
   JSON input to `out/build-info/`. Upload that file on BscScan's "Verify
   via Standard JSON Input" page, with constructor args from
   `artifacts/constructor-args.txt` (paste WITHOUT the leading `0x`).
2. **CLI** (needs a free BscScan API key):
   `forge verify-contract --chain-id 56 --constructor-args $(cat artifacts/constructor-args.txt) <deployed-address> src/AgentQuestBadge.sol:AgentQuestBadge --etherscan-api-key $BSCSCAN_API_KEY`

## Frontend

`frontend/index.html` — static single-file app (ethers.js v6 via CDN).
Connect wallet → check Agent ID → claim badge → post daily quest → board.
Set `CONTRACT_ADDRESS` in the file after mainnet deployment.

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
