# Test Report — AgentQuestBadge

Date: 19 Nov 2026. Toolchain: Foundry 1.9.0, solc 0.8.24+commit.e11b9ed9,
optimizer enabled (200 runs), EVM Cancun, OpenZeppelin Contracts v5.4.0.

## 1. Unit tests — 16/16 PASS

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

Note: tests warp to a realistic timestamp (2026-11-19) because Foundry's
default `block.timestamp` is 1 (UTC day 0), which collides with the default
`lastQuestDay` value of 0. On any live chain the current day is far above 0,
so this is a test-only concern.

## 2. Fork tests vs BSC mainnet — 4/4 PASS

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

## 5. Measured gas (anvil receipts)

| Operation | Gas |
|---|---|
| Deploy AgentQuestBadge | 1,742,982 |
| claim() | 127,461 |
| completeQuest() (26-char note) | 211,215 |
| setBaseURI() | 48,546 |

Deployed bytecode size: 7,203 bytes (limit 24,576). Creation code: 8,265 bytes.

## 6. Cost estimates (BNB $588.55, CoinGecko 19 Nov 2026)

| Operation | @ 0.05 gwei | @ 1 gwei | @ 3 gwei |
|---|---|---|---|
| Deploy | 0.000087 BNB (~Rp 940) | 0.001743 BNB (~Rp 18.700) | 0.005229 BNB (~Rp 56.200) |
| claim() | ~Rp 70 | ~Rp 1.370 | ~Rp 4.100 |
| completeQuest() | ~Rp 110 | ~Rp 2.270 | ~Rp 6.800 |

Full mainnet sequence (deploy + 1 claim + 1 quest + setBaseURI = 2,130,204 gas):
~0.00213 BNB (~Rp 22.900) at 1 gwei. Agent wallet balance 0.007028 BNB
covers this ~3.3x. Recommend deploying at ~1 gwei.
