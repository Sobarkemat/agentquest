// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/// @notice Minimal stand-in for the SPACE ID Agent ID registry (ERC-721).
/// @dev TEST/TESTNET ONLY — never deploy on mainnet. The real registry is
///      non-transferable; for testing only `balanceOf` matters, so a plain
///      mintable ERC-721 is enough. Used by the unit tests and by the BSC
///      testnet end-to-end deployment (the real Agent ID registry does not
///      exist on testnet).
contract MockAgentIdRegistry is ERC721 {
    uint256 private _nextId = 1;

    constructor() ERC721("Agent ID", "AI") {}

    function mint(address to) external returns (uint256) {
        uint256 id = _nextId++;
        _mint(to, id);
        return id;
    }
}
