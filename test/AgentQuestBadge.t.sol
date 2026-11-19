// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AgentQuestBadge} from "../src/AgentQuestBadge.sol";
import {MockAgentIdRegistry} from "../src/mocks/MockAgentIdRegistry.sol";

contract AgentQuestBadgeTest is Test {
    AgentQuestBadge public badge;
    MockAgentIdRegistry public registry;

    address public holder = makeAddr("holder");
    address public holder2 = makeAddr("holder2");
    address public nonHolder = makeAddr("nonHolder");

    event BadgeClaimed(address indexed holder, uint256 indexed tokenId);
    event QuestCompleted(address indexed holder, uint256 indexed day, uint256 indexed questId, string note);

    function setUp() public {
        // Foundry's default block.timestamp is 1, i.e. UTC day 0 — which
        // collides with the default `lastQuestDay` value of 0. Warp to a
        // realistic mainnet-like timestamp (2026-11-19 00:00 UTC). On any
        // live chain the current day is far above 0, so this is test-only.
        vm.warp(1795046400);
        registry = new MockAgentIdRegistry();
        registry.mint(holder);
        registry.mint(holder2);
        badge = new AgentQuestBadge(address(registry), "", address(this));
    }

    // -- gating views -------------------------------------------------------

    function testHasAgentId() public view {
        assertTrue(badge.hasAgentId(holder));
        assertFalse(badge.hasAgentId(nonHolder));
    }

    // -- claim --------------------------------------------------------------

    function testClaimSuccess() public {
        vm.expectEmit(true, true, false, true);
        emit BadgeClaimed(holder, 1);

        vm.prank(holder);
        badge.claim();

        assertEq(badge.ownerOf(1), holder);
        assertTrue(badge.hasClaimed(holder));
        assertEq(badge.totalClaimed(), 1);
        assertEq(badge.balanceOf(holder), 1);
    }

    function testClaimSecondHolderGetsTokenId2() public {
        vm.prank(holder);
        badge.claim();
        vm.prank(holder2);
        badge.claim();
        assertEq(badge.ownerOf(2), holder2);
        assertEq(badge.totalClaimed(), 2);
    }

    function testClaimRevertsForNonHolder() public {
        vm.prank(nonHolder);
        vm.expectRevert(AgentQuestBadge.NotAgentIdHolder.selector);
        badge.claim();
    }

    function testDoubleClaimReverts() public {
        vm.prank(holder);
        badge.claim();
        vm.prank(holder);
        vm.expectRevert(AgentQuestBadge.AlreadyClaimed.selector);
        badge.claim();
    }

    function testClaimIsFree() public {
        // No ETH is sent; claiming with zero balance still works.
        vm.prank(holder);
        badge.claim();
        assertEq(address(badge).balance, 0);
    }

    // -- daily quest --------------------------------------------------------

    function testCompleteQuestSuccess() public {
        uint256 day = block.timestamp / 1 days;
        vm.expectEmit(true, true, true, true);
        emit QuestCompleted(holder, day, 0, "shipped my first agent skill");

        vm.prank(holder);
        badge.completeQuest("shipped my first agent skill");

        assertEq(badge.totalQuests(), 1);
        assertEq(badge.questCountOf(holder), 1);
        AgentQuestBadge.Quest memory q = badge.getQuest(0);
        assertEq(q.author, holder);
        assertEq(q.note, "shipped my first agent skill");
        assertEq(q.day, day);
    }

    function testCompleteQuestRevertsForNonHolder() public {
        vm.prank(nonHolder);
        vm.expectRevert(AgentQuestBadge.NotAgentIdHolder.selector);
        badge.completeQuest("hello");
    }

    function testSecondQuestSameDayReverts() public {
        vm.prank(holder);
        badge.completeQuest("first");
        vm.prank(holder);
        vm.expectRevert(AgentQuestBadge.QuestAlreadyDoneToday.selector);
        badge.completeQuest("second");
    }

    function testQuestNextDaySucceeds() public {
        vm.prank(holder);
        badge.completeQuest("day one");
        vm.warp(block.timestamp + 1 days + 1);
        assertTrue(badge.canCompleteQuestToday(holder));
        vm.prank(holder);
        badge.completeQuest("day two");
        assertEq(badge.totalQuests(), 2);
    }

    function testQuestEmptyNoteReverts() public {
        vm.prank(holder);
        vm.expectRevert(AgentQuestBadge.NoteEmpty.selector);
        badge.completeQuest("");
    }

    function testQuestTooLongNoteReverts() public {
        string memory longNote = new string(281);
        // fill with 'a' bytes
        bytes memory b = bytes(longNote);
        for (uint256 i = 0; i < b.length; i++) {
            b[i] = "a";
        }
        vm.prank(holder);
        vm.expectRevert(AgentQuestBadge.NoteTooLong.selector);
        badge.completeQuest(string(b));
    }

    function testQuestExactly280BytesSucceeds() public {
        bytes memory b = new bytes(280);
        for (uint256 i = 0; i < b.length; i++) {
            b[i] = "a";
        }
        vm.prank(holder);
        badge.completeQuest(string(b));
        assertEq(badge.totalQuests(), 1);
    }

    // -- owner powers (minimal) ----------------------------------------------

    function testOnlyOwnerCanSetBaseURI() public {
        vm.prank(nonHolder);
        vm.expectRevert();
        badge.setBaseURI("ipfs://example/");
    }

    function testSetBaseURIAndTokenURI() public {
        vm.prank(holder);
        badge.claim();
        badge.setBaseURI("ipfs://QmExample/");
        assertEq(badge.tokenURI(1), "ipfs://QmExample/1");
    }

    function testOwnerIsDeployer() public view {
        assertEq(badge.owner(), address(this));
    }

    function testConstructorRevertsForZeroOwner() public {
        // OZ Ownable's constructor reverts first (base constructors run
        // before the derived constructor body), so the surfaced error is
        // OwnableInvalidOwner — our own require is belt-and-braces.
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new AgentQuestBadge(address(registry), "", address(0));
    }

    function testConstructorRevertsForZeroRegistry() public {
        vm.expectRevert("registry is zero address");
        new AgentQuestBadge(address(0), "", address(this));
    }
}
