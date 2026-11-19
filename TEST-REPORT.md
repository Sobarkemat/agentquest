# Test Report — AgentQuestBadge

Date: 19 Nov 2026. Toolchain: Foundry 1.9.0, solc 0.8.24+commit.e11b9ed9,
optimizer enabled (200 runs), EVM Cancun, OpenZeppelin Contracts v5.4.0.

**19 Nov 2026 (later same day):** the constructor gained an explicit `owner_`
parameter (see §7) because mainnet deployment goes through the canonical
CREATE2 factory, where `msg.sender` during construction is the factory, not
the project wallet. All tests below were re-run after the change.

## 1. Unit tests — 18/18 PASS

`forge test --match-contract AgentQuestBadgeTest`

| Test | Result |
|---|---|
| hasAgentId: holder true, non-holder false | PASS |
| claim: success, tokenId 1, owner = holder, BadgeClaimed emitted | PASS |
| claim: second holder gets tokenId 2 | PASS |
| claim: reverts for non-holder (`NotAgentIdHolder`) | PASS |
| claim: double claim reverts (`AlreadyClaimed`) | PASS |
| claim: is free (contract balance stays 0) | PASS |
| completeQuest: success, stored + event, questCountOf = 1 | PASS |
| completeQuest: reverts for non-holder | PASS |
| completeQuest: second quest same day reverts (`QuestAlreadyDoneToday`) | PASS |
| completeQuest: next day succeeds (warp) | PASS |
| completeQuest: empty note reverts (`NoteEmpty`) | PASS |
| completeQuest: 281-byte note reverts (`NoteTooLong`) | PASS |
| completeQuest: exactly 280-byte note succeeds | PASS |
| setBaseURI: non-owner reverts | PASS |
| setBaseURI + tokenURI returns baseURI + tokenId | PASS |
| owner is deployer | PASS |
| constructor: zero owner reverts (`OwnableInvalidOwner`) | PASS |
| constructor: zero registry reverts (`registry is zero address`) | PASS |

Note: tests warp to a realistic timestamp (2026-11-19) because Foundry's
default `block.timestamp` is 1 (UTC day 0), which collides with the default
`lastQuestDay` value of 0. On any live chain the current day is far above 0,
so this is a test-only concern.

## 2. Fork tests vs BSC mainnet — 5/5 PASS

`forge test --fork-url https://bsc-dataseed.binance.org/ --match-contract AgentQuestBadgeForkTest`

Validated against the REAL Agent ID registry
(0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F) and REAL mainnet state.
No transaction was broadcast — `vm.prank` impersonation exists only in the
local fork.

| Test | Result |
|---|---|
| Registry recognizes Ahmad's agent wallet 0xD7FC…930cB (kamasutra.ai) as holder; dead address is not a holder | PASS |
| Real holder can claim on the fork (tokenId 1) | PASS |
| Real holder can complete a quest on the fork | PASS |
| Non-holder claim reverts on the fork | PASS |
| Owner is Ahmad's agent wallet (explicit constructor owner) | PASS |

## 3. End-to-end on local anvil (real JSON-RPC) — PASS

Deployed MockAgentIdRegistry + AgentQuestBadge via `forge create`/`cast send`
on a local anvil chain; minted an Agent ID to a test account; claimed a badge
and completed a quest through real RPC calls.

- Mock registry: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
- Badge: 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9
- claim() status 1, ownerOf(1) = holder, totalClaimed = 1
- completeQuest("first quest on the board") status 1, totalQuests = 1
- setBaseURI status 1

## 4. BSC testnet deploy — BLOCKED on faucet captcha (not a code issue)

The BSC testnet faucet (https://www.bnbchain.org/en/testnet-faucet) requires
an interactive hCaptcha in a browser; it cannot be completed from this VM.
A throwaway testnet-only wallet was generated for this step:

- Address: 0xbfBA27Ac732110107292334D3D34bE48F9B0Ad7B
  (private key in /tmp/testnet-wallet.json — testnet only, worthless)

To finish the testnet deploy later: fund that address with ~0.01 tBNB from
the faucet (manual, 1 minute), then run:

```
REGISTRY=<mock registry on testnet> forge script script/Deploy.s.sol \
  --rpc-url bsc_testnet --private-key <key> --broadcast
```

(Deploy the mock registry to testnet first — the real Agent ID registry does
not exist on testnet.)

The fork test (§2) already validates the contract against real mainnet
registry state, so the missing testnet deploy does not block the mainnet
preview.

## 5. Measured gas (anvil receipts + mainnet RPC estimate)

| Operation | Gas |
|---|---|
| Deploy via CREATE2 factory (anvil fork of mainnet, §7) | 1,749,203 |
| Deploy via CREATE2 factory (eth_estimateGas, BSC mainnet RPC) | 1,779,304 |
| Direct deploy (previous, pre-factory; for reference) | 1,742,982 |
| claim() | 127,488 |
| completeQuest() (26-char note) | 211,215 |
| setBaseURI() | 48,546 |

Deployed bytecode size: 7,203 bytes (limit 24,576). Creation code: 8,387
bytes; full initCode with constructor args: 8,515 bytes; factory calldata
(salt + initCode): 8,547 bytes.

## 6. Cost estimates (BNB $590.37 / Rp 10.777.842, CoinGecko 19 Nov 2026)

Factory deploy (1,779,304 gas, mainnet RPC estimate):

| Gas price | Cost |
|---|---|
| 0.05 gwei (current BSC) | 0.0000890 BNB (~Rp 960) |
| 1 gwei | 0.0017793 BNB (~Rp 19.200) |
| 3 gwei | 0.0053379 BNB (~Rp 57.500) |

Suggested gas limit 2,000,000. Agent wallet balance 0.007028 BNB covers
the 1-gwei deploy cost ~3.95x (and the 3-gwei cost ~1.32x).

## 7. CREATE2 factory deployment — verification (19 Nov 2026)

**Why the factory:** the Binance Agentic Wallet (`baw`) cannot deploy a
contract directly — `contract-call preview` requires `--to` and there is no
deploy command. Deployment therefore goes through the canonical CREATE2
factory (Arachnid deterministic deployment proxy),
`0x4e59b44847b379578588920cA78FbF26c0B4956C`, already present on BSC
mainnet. Its on-chain bytecode was verified to be the canonical deployer
proxy. The deployer takes raw calldata = salt (32 bytes, no function
selector) ++ initCode, and returns the deployed address (20 bytes).

**The owner problem and fix:** during a factory deployment, `msg.sender`
in the constructor is the factory, so `Ownable(msg.sender)` would have made
the factory the owner (dead — nobody could ever call `setBaseURI`). The
constructor was changed to `constructor(address registry_, string memory
baseURI_, address owner_)` with `Ownable(owner_)` plus
`require(owner_ != address(0))`. The mainnet owner is Ahmad's agent wallet
`0xD7FCd6bD011253E32b8B96A0Dc815d30C6B930cB`. Claim/quest/gating logic is
untouched.

**Salt:** `keccak256("agentquest-badge-v1")` =
`0x9a794cf8e75229665bf6b340ad95962bd8e3f6dc0eaedeba9d641a050ed72b64`
(`artifacts/factory-salt.txt`).

**Expected address (deterministic CREATE2):**
`0x00c5579F105fE340eE197E9aF103E06b33fFEa3a`
(`artifacts/expected-address.txt`, `artifacts/factory-deploy.json`).
Init code hash: `0xc9bec122f3fd1157245147baeb7808dd37d7ec2846fd07d01cd3b5b8ee8d36dc`.

**Proof the address is correct (all three agree):**
1. `cast create2 --salt <salt> --init-code <initCode>` →
   `0x00c5579F105fE340eE197E9aF103E06b33fFEa3a`
2. `cast create2 --salt <salt> --init-code-hash <hash>` → same address.
3. Manual `keccak256(0xff ++ factory ++ salt ++ keccak256(initCode))[12:]`
   → same address.
4. **Read-only `eth_call` simulation on BSC mainnet** (no broadcast):
   calling the factory with the exact factory calldata returned
   `0x00c5579f105fe340ee197e9af103e06b33ffea3a`. The target address was
   confirmed empty (`eth_getCode` = `0x`) at simulation time.

**End-to-end on a local anvil fork of BSC mainnet** (no mainnet broadcast;
agent wallet impersonated locally only): the exact factory calldata was sent
to the factory — status 1, gas 1,749,203, contract deployed at the expected
address, `OwnershipTransferred(0x0 → 0xD7FC…930cB)` emitted. Then verified
on the fork-deployed contract:
- `owner()` = `0xD7FCd6bD011253E32b8B96A0Dc815d30C6B930cB` (agent wallet,
  NOT the factory) ✓
- `agentIdRegistry()` = `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F` ✓
- `hasAgentId(agent wallet)` = true ✓
- `claim()` from the agent wallet: status 1, `ownerOf(1)` = agent wallet,
  `totalClaimed` = 1 ✓
- `setBaseURI("ipfs://test/")` as owner: status 1,
  `tokenURI(1)` = `"ipfs://test/1"` ✓
- `completeQuest("factory deploy verified")`: status 1, `totalQuests` = 1 ✓

**Constructor args** (registry, baseURI, owner) were re-encoded with `cast
abi-encode` and decoded back with `cast abi-decode --input`, confirming the
round trip. Deployment calldata was verified to equal creation bytecode +
encoded args exactly.
