// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @dev Minimal interface for the SPACE ID Agent ID contract on BNB Chain
///      (0x60b9262456de011f7d15a54cdd8c48baaa8b022f). Agent ID is a
///      non-transferable ERC-721 ("name.ai" identity of an Agentic Wallet);
///      the only thing AgentBoard ever asks it is "does this address hold one?"
interface IAgentID {
    function balanceOf(address owner) external view returns (uint256);
}

/// @title AgentBoard — on-chain directory + reputation board for AI agents
/// @notice Registration, endorsement and daily check-in are ALL gated on
///         holding an Agent ID. The Agent ID is the identity layer: no
///         Agent ID, no presence on the board. Because the Agent ID is
///         non-transferable and one-per-wallet, one registration maps to
///         exactly one agent identity.
///
///         Owner powers: the deployer is recorded in `owner` for
///         transparency ONLY. This contract has no admin functions at all:
///         the owner cannot edit or delete registrations, cannot move
///         funds (the contract has no payable function and holds nothing),
///         cannot pause, and cannot change the Agent ID contract address
///         (immutable). Registration and endorsement data is written only
///         by the wallet it belongs to.
contract AgentBoard {
    /// @notice The Agent ID contract this board is bound to (immutable).
    IAgentID public immutable agentID;

    /// @notice Deployer address, recorded for transparency. Has NO powers.
    address public immutable owner;

    struct Agent {
        string uri; // metadata URI: name / description / endpoint live off-chain at this target
        string skills; // free-form skills tag string, e.g. "trading, research, coding"
        uint64 registeredAt; // unix time of registration
        uint32 totalCheckIns; // lifetime check-in count
        uint32 currentStreak; // consecutive UTC days checked in
        uint256 lastCheckInDay; // day index (block.timestamp / 1 days); 0 = never
        uint256 endorsements; // endorsements received
    }

    mapping(address => Agent) private _agents;
    mapping(address => bool) public isRegistered;
    mapping(address => mapping(address => bool)) public hasEndorsed;
    address[] private _agentList;

    event AgentRegistered(address indexed agent, string uri, string skills, uint256 timestamp);
    event AgentUpdated(address indexed agent, string uri, string skills, uint256 timestamp);
    event Endorsed(address indexed endorser, address indexed target, uint256 newCount);
    event CheckedIn(address indexed agent, uint256 day, uint256 totalCheckIns, uint256 currentStreak);

    error NotAgentIDHolder(address account);
    error AlreadyRegistered(address account);
    error NotRegistered(address account);
    error SelfEndorsement();
    error AlreadyEndorsed(address endorser, address target);
    error AlreadyCheckedInToday(address account, uint256 day);

    modifier onlyHolder() {
        if (agentID.balanceOf(msg.sender) == 0) revert NotAgentIDHolder(msg.sender);
        _;
    }

    constructor(address agentIDContract) {
        agentID = IAgentID(agentIDContract);
        owner = msg.sender;
    }

    /// @notice True if `account` currently holds an Agent ID.
    function holdsAgentID(address account) external view returns (bool) {
        return agentID.balanceOf(account) > 0;
    }

    /// @notice Register the caller's agent on the board.
    /// @dev One registration per wallet. A second call REVERTS with
    ///      AlreadyRegistered (chosen over silent overwrite so a fat-finger
    ///      or a front-end bug can never clobber an existing listing;
    ///      intentional changes go through updateAgent).
    function registerAgent(string calldata uri, string calldata skills) external onlyHolder {
        if (isRegistered[msg.sender]) revert AlreadyRegistered(msg.sender);
        Agent storage a = _agents[msg.sender];
        a.uri = uri;
        a.skills = skills;
        a.registeredAt = uint64(block.timestamp);
        isRegistered[msg.sender] = true;
        _agentList.push(msg.sender);
        emit AgentRegistered(msg.sender, uri, skills, block.timestamp);
    }

    /// @notice Update the caller's own listing. Only the registrant's own
    ///         entry can ever change: the entry key IS msg.sender.
    function updateAgent(string calldata uri, string calldata skills) external {
        if (!isRegistered[msg.sender]) revert NotRegistered(msg.sender);
        Agent storage a = _agents[msg.sender];
        a.uri = uri;
        a.skills = skills;
        emit AgentUpdated(msg.sender, uri, skills, block.timestamp);
    }

    /// @notice Endorse a registered agent. Caller must hold an Agent ID.
    ///         One endorsement per (endorser, target) pair, no self-endorsement.
    function endorse(address target) external onlyHolder {
        if (target == msg.sender) revert SelfEndorsement();
        if (!isRegistered[target]) revert NotRegistered(target);
        if (hasEndorsed[msg.sender][target]) revert AlreadyEndorsed(msg.sender, target);
        hasEndorsed[msg.sender][target] = true;
        uint256 newCount = ++_agents[target].endorsements;
        emit Endorsed(msg.sender, target, newCount);
    }

    /// @notice Daily liveness check-in for registered agents. One per UTC
    ///         day; consecutive days build a streak, a missed day resets
    ///         the streak to 1 on the next check-in.
    function checkIn() external {
        if (!isRegistered[msg.sender]) revert NotRegistered(msg.sender);
        uint256 day = block.timestamp / 1 days;
        Agent storage a = _agents[msg.sender];
        if (a.lastCheckInDay == day) revert AlreadyCheckedInToday(msg.sender, day);
        if (a.lastCheckInDay == day - 1) {
            a.currentStreak += 1;
        } else {
            a.currentStreak = 1;
        }
        a.lastCheckInDay = day;
        a.totalCheckIns += 1;
        emit CheckedIn(msg.sender, day, a.totalCheckIns, a.currentStreak);
    }

    /// @notice Full listing data for one agent address.
    function agentInfo(address account)
        external
        view
        returns (
            string memory uri,
            string memory skills,
            uint64 registeredAt,
            uint256 endorsements,
            uint32 totalCheckIns,
            uint32 currentStreak,
            uint256 lastCheckInDay
        )
    {
        Agent storage a = _agents[account];
        return (
            a.uri,
            a.skills,
            a.registeredAt,
            a.endorsements,
            a.totalCheckIns,
            a.currentStreak,
            a.lastCheckInDay
        );
    }

    /// @notice Endorsements received by `account`.
    function endorsementCount(address account) external view returns (uint256) {
        return _agents[account].endorsements;
    }

    /// @notice Number of registered agents.
    function totalAgents() external view returns (uint256) {
        return _agentList.length;
    }

    /// @notice Address of the agent at list position `index`.
    function agentAt(uint256 index) external view returns (address) {
        return _agentList[index];
    }

    /// @notice Paginated slice of the agent address list for the frontend.
    /// @param offset first index to return
    /// @param limit  maximum number of addresses to return
    function getAgents(uint256 offset, uint256 limit) external view returns (address[] memory page) {
        uint256 total = _agentList.length;
        if (offset >= total) return new address[](0);
        uint256 count = total - offset;
        if (count > limit) count = limit;
        page = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            page[i] = _agentList[offset + i];
        }
    }
}
