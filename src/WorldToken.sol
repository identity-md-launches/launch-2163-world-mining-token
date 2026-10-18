// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title World mining token (WORLD)
/// @notice Fixed-supply ERC-20. The whole supply of 1,000,000,000 WORLD (18 decimals) is minted once,
/// in the constructor, to the deployer. There is no owner, no mint, no burn, no pause, no blacklist
/// and no transfer fee: every transfer moves exactly the amount requested.
contract WorldToken is ERC20 {
    string public constant NAME = "World mining token";
    string public constant SYMBOL = "WORLD";
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * 10 ** 18;

    constructor() ERC20(NAME, SYMBOL) {
        _mint(msg.sender, TOTAL_SUPPLY);
    }
}
