// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title AgentQuestBadge
/// @notice A free Quest Board + collectible badge for Agent ID holders.
///
/// @dev Built for the Agent ID Hackathon (Binance Wallet x BNB Chain).
///      How Agent ID is used (core to the product, not decoration):
///        1. ACCESS CONTROL — `claim()` and `completeQuest()` both require the
///           caller to hold an Agent ID (an ERC-721 in the SPACE ID Agent ID
///           registry). Ownership is checked on-chain via
///           `registry.balanceOf(caller) > 0` on every call.
///        2. IDENTITY — every quest completion is recorded with the holder's
///           address, which frontends resolve to the holder's `name.ai` Agent ID
///           for display on the board.
///
///      What this contract deliberately does NOT do (owner permissions are
///      minimal and fully disclosed):
///        - No payments: `claim()` and `completeQuest()` are free (value 0).
///          There is no payable function, no price, no fee, and no way for the
///          contract to receive or hold user funds.
///        - No owner minting: the owner cannot mint badges. Badges are only
///          minted by `claim()`, one per Agent ID holder.
///        - No pause / freeze / burn: the owner cannot pause the contract,
///          freeze transfers, or burn anyone's badge.
///        - No return promises: badges are collectible souvenirs with no
///          monetary value, yield, or redemption promise.
///        - No credential collection: the contract never asks for seed phrases,
///          private keys, API secrets, or pairing codes.
///      The ONLY owner function is `setBaseURI()`, which only changes where
///      token metadata is served from.
///
///      Deployment route: this contract is deployed via the canonical CREATE2
///      factory (Arachnid deterministic deployment proxy,
///      0x4e59b44847b379578588920cA78FbF26c0B4956C) with salt
///      keccak256("agentquest-badge-v1"). During a factory deployment
///      `msg.sender` in the constructor is the factory itself, so the owner
///      is passed explicitly as a constructor argument instead of defaulting
///      to `msg.sender` — otherwise the contract would end up ownerless.
contract AgentQuestBadge is ERC721, Ownable, ReentrancyGuard {
    /// @notice The SPACE ID Agent ID registry (ERC-721, non-transferable).
    /// @dev Mainnet (BNB Chain): 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F.
    ///      Immutable: set once at deployment, never changeable afterwards.
    IERC721 public immutable agentIdRegistry;

    /// @notice Maximum length of a quest note, in bytes (tweet-sized).
    uint256 public constant MAX_NOTE_LENGTH = 280;

    /// @notice Next token ID to mint. Token IDs start at 1.
    uint256 public nextTokenId = 1;

    /// @notice Total number of badges claimed.
    uint256 public totalClaimed;

    /// @notice Total number of quests completed.
    uint256 public totalQuests;

    /// @notice Whether an address has already claimed its badge.
    mapping(address => bool) public hasClaimed;

    /// @notice Last UTC day (block.timestamp / 1 days) an address completed a quest.
    mapping(address => uint256) public lastQuestDay;

    /// @notice One quest completion: who, what note, and when.
    struct Quest {
        address author;
        string note;
        uint256 timestamp;
        uint256 day; // UTC day number (block.timestamp / 1 days)
    }

    /// @notice All quests, in completion order. Quest IDs are array indices.
    Quest[] public quests;

    /// @notice Quest IDs completed by each author (for per-user history).
    mapping(address => uint256[]) public questIdsByAuthor;

    /// @notice Base URI for token metadata (e.g. "ipfs://<cid>/").
    string private _baseTokenURI;

    /// @notice Emitted when an Agent ID holder claims their free badge.
    event BadgeClaimed(address indexed holder, uint256 indexed tokenId);

    /// @notice Emitted when an Agent ID holder completes a daily quest.
    event QuestCompleted(address indexed holder, uint256 indexed day, uint256 indexed questId, string note);

    /// @notice Emitted when the owner updates the metadata base URI.
    event BaseURIUpdated(string baseURI);

    /// @notice Caller does not hold an Agent ID.
    error NotAgentIdHolder();

    /// @notice Caller already claimed their one badge.
    error AlreadyClaimed();

    /// @notice Caller already completed today's quest (one per UTC day).
    error QuestAlreadyDoneToday();

    /// @notice Quest note is empty.
    error NoteEmpty();

    /// @notice Quest note exceeds MAX_NOTE_LENGTH bytes.
    error NoteTooLong();

    /// @param registry_ Address of the Agent ID registry contract.
    /// @param baseURI_ Initial metadata base URI (may be empty; owner can set later).
    /// @param owner_ Address that becomes the contract owner. Must be non-zero.
    /// @dev The owner is an explicit parameter (not `msg.sender`) because the
    ///      contract is deployed via the canonical CREATE2 factory: during a
    ///      factory deployment `msg.sender` in the constructor is the factory
    ///      itself, which would leave the contract ownerless. Passing the
    ///      owner explicitly keeps ownership with the project wallet.
    constructor(address registry_, string memory baseURI_, address owner_)
        ERC721("Agent Quest Badge", "AQB")
        Ownable(owner_)
    {
        require(registry_ != address(0), "registry is zero address");
        require(owner_ != address(0), "owner is zero address");
        agentIdRegistry = IERC721(registry_);
        _baseTokenURI = baseURI_;
    }

    // ------------------------------------------------------------------------
    // Agent ID gating
    // ------------------------------------------------------------------------

    /// @notice Returns true if `account` holds at least one Agent ID.
    /// @dev Per the hackathon spec: `balanceOf(account) > 0` on the registry.
    function hasAgentId(address account) public view returns (bool) {
        return agentIdRegistry.balanceOf(account) > 0;
    }

    /// @notice Returns true if `account` can complete a quest right now
    ///         (holds an Agent ID and has not completed today's quest yet).
    function canCompleteQuestToday(address account) public view returns (bool) {
        return hasAgentId(account) && lastQuestDay[account] != _currentDay();
    }

    /// @notice Current UTC day number.
    function _currentDay() internal view returns (uint256) {
        return block.timestamp / 1 days;
    }

    // ------------------------------------------------------------------------
    // Badge claim (free, one per Agent ID holder)
    // ------------------------------------------------------------------------

    /// @notice Claim your free Agent Quest Badge.
    /// @dev Free (no ETH required). One badge per address, only for Agent ID
    ///      holders. State is updated BEFORE minting (checks-effects-
    ///      interactions) and the function is reentrancy-guarded, because
    ///      `_safeMint` calls the receiver's `onERC721Received` hook.
    function claim() external nonReentrant {
        if (!hasAgentId(msg.sender)) revert NotAgentIdHolder();
        if (hasClaimed[msg.sender]) revert AlreadyClaimed();

        hasClaimed[msg.sender] = true;
        uint256 tokenId = nextTokenId++;
        totalClaimed++;

        _safeMint(msg.sender, tokenId);
        emit BadgeClaimed(msg.sender, tokenId);
    }

    // ------------------------------------------------------------------------
    // Daily quest (free, one per Agent ID holder per UTC day)
    // ------------------------------------------------------------------------

    /// @notice Complete today's quest with a short note (max 280 bytes).
    /// @dev Free (no ETH required). One quest per address per UTC day.
    ///      The note is stored on-chain and emitted in the event so the
    ///      board can display it without an off-chain database.
    /// @param note A short note about today's quest (1-280 bytes).
    function completeQuest(string calldata note) external {
        if (!hasAgentId(msg.sender)) revert NotAgentIdHolder();
        uint256 day = _currentDay();
        if (lastQuestDay[msg.sender] == day) revert QuestAlreadyDoneToday();
        if (bytes(note).length == 0) revert NoteEmpty();
        if (bytes(note).length > MAX_NOTE_LENGTH) revert NoteTooLong();

        lastQuestDay[msg.sender] = day;

        uint256 questId = quests.length;
        quests.push(Quest({author: msg.sender, note: note, timestamp: block.timestamp, day: day}));
        questIdsByAuthor[msg.sender].push(questId);
        totalQuests++;

        emit QuestCompleted(msg.sender, day, questId, note);
    }

    // ------------------------------------------------------------------------
    // Views
    // ------------------------------------------------------------------------

    /// @notice Number of quests completed by `account`.
    function questCountOf(address account) external view returns (uint256) {
        return questIdsByAuthor[account].length;
    }

    /// @notice Returns the quest at `questId`.
    function getQuest(uint256 questId) external view returns (Quest memory) {
        return quests[questId];
    }

    // ------------------------------------------------------------------------
    // Owner-only: metadata base URI (the ONLY owner power)
    // ------------------------------------------------------------------------

    /// @notice Update the base URI used by `tokenURI` (e.g. after uploading
    ///         badge artwork/metadata to IPFS). Does not affect ownership,
    ///         claims, or quests in any way.
    function setBaseURI(string calldata baseURI_) external onlyOwner {
        _baseTokenURI = baseURI_;
        emit BaseURIUpdated(baseURI_);
    }

    /// @dev OZ ERC721 hook: `tokenURI(tokenId)` returns `baseURI + tokenId`.
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }
}
