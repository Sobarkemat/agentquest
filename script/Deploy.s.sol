// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {AgentQuestBadge} from "../src/AgentQuestBadge.sol";

/// @notice Deploy AgentQuestBadge.
/// @dev Usage (BSC testnet example):
///      REGISTRY=<registry> BASE_URI="" OWNER=<owner> forge script script/Deploy.s.sol \
///        --rpc-url bsc_testnet --private-key $PRIVATE_KEY --broadcast
///      Mainnet registry: 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F
///      Mainnet owner: Ahmad's agent wallet 0xD7FCd6bD011253E32b8B96A0Dc815d30C6B930cB
///      NOTE: mainnet deployment for this project goes through the Binance
///      Agentic Wallet (baw) calling the canonical CREATE2 factory
///      (0x4e59b44847b379578588920cA78FbF26c0B4956C) with a preview + user
///      confirmation, NOT through this script. This script is for
///      testnet/local use and as a reproducible reference of the deployment.
///      The owner is an explicit constructor argument (not msg.sender)
///      because during a factory deployment msg.sender is the factory.
contract Deploy is Script {
    function run() external returns (AgentQuestBadge badge) {
        address registry = vm.envOr("REGISTRY", address(0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F));
        string memory baseURI = vm.envOr("BASE_URI", string(""));
        address owner = vm.envOr("OWNER", address(0xD7FCd6bD011253E32b8B96A0Dc815d30C6B930cB));

        vm.startBroadcast();
        badge = new AgentQuestBadge(registry, baseURI, owner);
        vm.stopBroadcast();

        console.log("AgentQuestBadge deployed at:", address(badge));
        console.log("Agent ID registry:", registry);
        console.log("Owner:", badge.owner());
    }
}
