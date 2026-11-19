// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AgentQuestBadge} from "../src/AgentQuestBadge.sol";

/// @notice Fork test against BSC MAINNET state (read-only + local fork).
/// @dev Run with:
///      forge test --fork-url https://bsc-dataseed.binance.org/ --match-contract AgentQuestBadgeForkTest
///      No real transaction is ever broadcast: `vm.prank` impersonation only
///      exists inside the local fork. This validates the contract against the
///      REAL Agent ID registry and a REAL holder address.
contract AgentQuestBadgeForkTest is Test {
    // Real SPACE ID Agent ID registry on BNB Chain mainnet.
    address public constant REGISTRY = 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;

    // Ahmad's agent wallet — holder of Agent ID "kamasutra.ai".
    address public constant AHMAD_AGENT = 0xD7FCd6bD011253E32b8B96A0Dc815d30C6B930cB;

    // A random address that (verifiably, at fork time) holds no Agent ID.
    address public constant RANDOM_ADDR = 0x000000000000000000000000000000000000dEaD;

    AgentQuestBadge public badge;

    function setUp() public {
        badge = new AgentQuestBadge(REGISTRY, "");
    }

    function testRealRegistryRecognizesAhmad() public view {
        assertTrue(badge.hasAgentId(AHMAD_AGENT), "Ahmad agent wallet must hold an Agent ID");
        assertFalse(badge.hasAgentId(RANDOM_ADDR), "dead address must not hold an Agent ID");
    }

    function testRealHolderCanClaimOnFork() public {
        vm.prank(AHMAD_AGENT);
        badge.claim();
        assertEq(badge.ownerOf(1), AHMAD_AGENT);
        assertEq(badge.totalClaimed(), 1);
    }

    function testRealHolderCanCompleteQuestOnFork() public {
        vm.prank(AHMAD_AGENT);
        badge.completeQuest("quest board goes live");
        assertEq(badge.totalQuests(), 1);
        AgentQuestBadge.Quest memory q = badge.getQuest(0);
        assertEq(q.author, AHMAD_AGENT);
    }

    function testNonHolderRevertsOnFork() public {
        vm.prank(RANDOM_ADDR);
        vm.expectRevert(AgentQuestBadge.NotAgentIdHolder.selector);
        badge.claim();
    }
}
