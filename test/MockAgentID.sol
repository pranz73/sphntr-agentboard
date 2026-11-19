// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @dev Test stub for the SPACE ID Agent ID contract. AgentBoard only ever
///      calls balanceOf(address), so the stub implements exactly that plus
///      a mint helper to hand out "Agent IDs" to test accounts.
contract MockAgentID {
    mapping(address => uint256) private _balances;

    function mint(address to) external {
        _balances[to] += 1;
    }

    function balanceOf(address owner) external view returns (uint256) {
        return _balances[owner];
    }
}
