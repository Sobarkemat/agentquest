// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {AgentQuestBadge} from "../src/AgentQuestBadge.sol";

/// @notice Deploy AgentQuestBadge.
/// @dev Usage (BSC testnet example):
///      REGISTRY=<registry> BASE_URI="" forge script script/Deploy.s.sol \
///        --rpc-url bsc_testnet --private-key $PRIVATE_KEY --broadcast
///      Mainnet registry: 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F
///      NOTE: mainnet deployment for this project goes through the Binance
///      Agentic Wallet (baw) with a preview + user confirmation, NOT through
///      this script. This script is for testnet/local use and as a
///      reproducible reference of the deployment.
contract Deploy is Script {
    function run() external returns (AgentQuestBadge badge) {
        address registry = vm.envOr("REGISTRY", address(0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F));
        string memory baseURI = vm.envOr("BASE_URI", string(""));

        vm.startBroadcast();
        badge = new AgentQuestBadge(registry, baseURI);
        vm.stopBroadcast();

        console.log("AgentQuestBadge deployed at:", address(badge));
        console.log("Agent ID registry:", registry);
        console.log("Owner:", badge.owner());
    }
}
