// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AgentBoard} from "../contracts/AgentBoard.sol";
import {MockAgentID} from "./MockAgentID.sol";

/// @dev Minimal cheatcode interface — the project is dependency-free, so
///      tests talk to Foundry's cheatcode address directly instead of
///      importing forge-std.
interface Vm {
    function prank(address msgSender) external;
    function warp(uint256 newTimestamp) external;
    function expectRevert(bytes calldata revertData) external;
}

contract AgentBoardTest {
    Vm private constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    AgentBoard private board;
    MockAgentID private agentID;

    address private constant ALICE = address(0xA11CE); // Agent ID holder
    address private constant BOB = address(0xB0B); // Agent ID holder
    address private constant CAROL = address(0xCA401); // Agent ID holder
    address private constant NOBODY = address(0xDEAD); // no Agent ID

    uint256 private constant T0 = 1_700_000_000; // fixed start time

    function setUp() public {
        vm.warp(T0);
        agentID = new MockAgentID();
        board = new AgentBoard(address(agentID));
        agentID.mint(ALICE);
        agentID.mint(BOB);
        agentID.mint(CAROL);
    }

    // ---------- tiny assertion helpers (no forge-std) ----------

    function assertTrue(bool cond, string memory msg_) internal pure {
        if (!cond) revert(msg_);
    }

    function assertEq(uint256 a, uint256 b, string memory msg_) internal pure {
        if (a != b) revert(msg_);
    }

    function assertEq(address a, address b, string memory msg_) internal pure {
        if (a != b) revert(msg_);
    }

    function assertEq(string memory a, string memory b, string memory msg_) internal pure {
        if (keccak256(bytes(a)) != keccak256(bytes(b))) revert(msg_);
    }

    // ---------- registration ----------

    function testNonHolderCannotRegister() public {
        vm.prank(NOBODY);
        vm.expectRevert(abi.encodeWithSelector(AgentBoard.NotAgentIDHolder.selector, NOBODY));
        board.registerAgent("ipfs://nobody", "none");
    }

    function testHolderCanRegister() public {
        vm.prank(ALICE);
        board.registerAgent("ipfs://alice", "trading, research");

        assertTrue(board.isRegistered(ALICE), "alice should be registered");
        assertTrue(board.holdsAgentID(ALICE), "alice holds an Agent ID");
        assertTrue(!board.holdsAgentID(NOBODY), "nobody holds no Agent ID");
        assertEq(board.totalAgents(), 1, "one agent on the board");
        assertEq(board.agentAt(0), ALICE, "first listed agent is alice");

        (string memory uri, string memory skills, uint64 registeredAt,,,,) = board.agentInfo(ALICE);
        assertEq(uri, "ipfs://alice", "uri stored");
        assertEq(skills, "trading, research", "skills stored");
        assertEq(uint256(registeredAt), T0, "registration time stored");
    }

    function testSecondRegisterReverts() public {
        vm.prank(ALICE);
        board.registerAgent("ipfs://alice", "trading");
        vm.prank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(AgentBoard.AlreadyRegistered.selector, ALICE));
        board.registerAgent("ipfs://alice-v2", "other");
    }

    function testUpdateByRegistrant() public {
        vm.prank(ALICE);
        board.registerAgent("ipfs://alice", "trading");
        vm.prank(ALICE);
        board.updateAgent("ipfs://alice-new", "trading, coding");
        (string memory uri, string memory skills,,,,,) = board.agentInfo(ALICE);
        assertEq(uri, "ipfs://alice-new", "uri updated");
        assertEq(skills, "trading, coding", "skills updated");
    }

    function testUpdateByUnregisteredReverts() public {
        // BOB holds an Agent ID but never registered: there is no entry of
        // his to update, and he certainly cannot touch ALICE's.
        vm.prank(ALICE);
        board.registerAgent("ipfs://alice", "trading");
        vm.prank(BOB);
        vm.expectRevert(abi.encodeWithSelector(AgentBoard.NotRegistered.selector, BOB));
        board.updateAgent("ipfs://hijack", "hijack");
        (string memory uri,,,,,,) = board.agentInfo(ALICE);
        assertEq(uri, "ipfs://alice", "alice entry untouched");
    }

    // ---------- endorsement ----------

    function testNonHolderCannotEndorse() public {
        vm.prank(ALICE);
        board.registerAgent("ipfs://alice", "trading");
        vm.prank(NOBODY);
        vm.expectRevert(abi.encodeWithSelector(AgentBoard.NotAgentIDHolder.selector, NOBODY));
        board.endorse(ALICE);
    }

    function testEndorseIncrementsAndRecords() public {
        vm.prank(ALICE);
        board.registerAgent("ipfs://alice", "trading");
        vm.prank(BOB);
        board.endorse(ALICE);
        assertEq(board.endorsementCount(ALICE), 1, "one endorsement");
        assertTrue(board.hasEndorsed(BOB, ALICE), "endorsement recorded");
        // A holder does NOT need to be registered themselves to endorse.
        vm.prank(CAROL);
        board.endorse(ALICE);
        assertEq(board.endorsementCount(ALICE), 2, "two endorsements");
    }

    function testEndorseSelfReverts() public {
        vm.prank(ALICE);
        board.registerAgent("ipfs://alice", "trading");
        vm.prank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(AgentBoard.SelfEndorsement.selector));
        board.endorse(ALICE);
    }

    function testEndorseDuplicateReverts() public {
        vm.prank(ALICE);
        board.registerAgent("ipfs://alice", "trading");
        vm.prank(BOB);
        board.endorse(ALICE);
        vm.prank(BOB);
        vm.expectRevert(abi.encodeWithSelector(AgentBoard.AlreadyEndorsed.selector, BOB, ALICE));
        board.endorse(ALICE);
    }

    function testEndorseUnregisteredTargetReverts() public {
        vm.prank(BOB);
        vm.expectRevert(abi.encodeWithSelector(AgentBoard.NotRegistered.selector, CAROL));
        board.endorse(CAROL);
    }

    // ---------- check-in ----------

    function testUnregisteredCannotCheckIn() public {
        // Holder but not registered.
        vm.prank(BOB);
        vm.expectRevert(abi.encodeWithSelector(AgentBoard.NotRegistered.selector, BOB));
        board.checkIn();
        // No Agent ID at all.
        vm.prank(NOBODY);
        vm.expectRevert(abi.encodeWithSelector(AgentBoard.NotRegistered.selector, NOBODY));
        board.checkIn();
    }

    function testCheckInOncePerDay() public {
        vm.prank(ALICE);
        board.registerAgent("ipfs://alice", "trading");
        vm.prank(ALICE);
        board.checkIn();
        (,,, uint256 ends, uint32 total, uint32 streak,) = board.agentInfo(ALICE);
        assertEq(ends, 0, "no endorsements");
        assertEq(uint256(total), 1, "one check-in");
        assertEq(uint256(streak), 1, "streak 1");

        uint256 today = T0 / 1 days;
        vm.prank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(AgentBoard.AlreadyCheckedInToday.selector, ALICE, today));
        board.checkIn();
    }

    function testCheckInStreakBuildsAndResets() public {
        vm.prank(ALICE);
        board.registerAgent("ipfs://alice", "trading");

        vm.prank(ALICE);
        board.checkIn(); // day D: streak 1
        vm.warp(T0 + 1 days);
        vm.prank(ALICE);
        board.checkIn(); // day D+1: streak 2
        vm.warp(T0 + 2 days);
        vm.prank(ALICE);
        board.checkIn(); // day D+2: streak 3
        (,,,, uint32 total, uint32 streak,) = board.agentInfo(ALICE);
        assertEq(uint256(total), 3, "three check-ins");
        assertEq(uint256(streak), 3, "streak 3");

        vm.warp(T0 + 5 days); // skipped two days
        vm.prank(ALICE);
        board.checkIn(); // streak resets to 1
        (,,,, total, streak,) = board.agentInfo(ALICE);
        assertEq(uint256(total), 4, "four check-ins total");
        assertEq(uint256(streak), 1, "streak reset to 1 after a gap");
    }

    // ---------- listing / pagination ----------

    function testPagination() public {
        vm.prank(ALICE);
        board.registerAgent("ipfs://alice", "a");
        vm.prank(BOB);
        board.registerAgent("ipfs://bob", "b");
        vm.prank(CAROL);
        board.registerAgent("ipfs://carol", "c");

        assertEq(board.totalAgents(), 3, "three agents");
        address[] memory page1 = board.getAgents(0, 2);
        assertEq(page1.length, 2, "page 1 has 2");
        assertEq(page1[0], ALICE, "page1[0]");
        assertEq(page1[1], BOB, "page1[1]");
        address[] memory page2 = board.getAgents(2, 2);
        assertEq(page2.length, 1, "page 2 has 1");
        assertEq(page2[0], CAROL, "page2[0]");
        address[] memory empty = board.getAgents(3, 2);
        assertEq(empty.length, 0, "past-the-end page is empty");
    }
}
