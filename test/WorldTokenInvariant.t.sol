// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {WorldToken} from "../src/WorldToken.sol";

/// @notice Drives WorldToken with random transfers, approvals and transferFroms among a fixed set of
/// actors, including calls that must fail. Ghost state mirrors what each balance and allowance should be.
contract WorldTokenHandler is Test {
    WorldToken public immutable token;
    address[] public actors;

    mapping(address => uint256) public ghostBalance;
    mapping(address => mapping(address => uint256)) public ghostAllowance;
    uint256 public ghostUnexpectedOutcomes;
    uint256 public calls;
    uint256 public failedCallsAsExpected;

    constructor(WorldToken token_, address[] memory actors_) {
        token = token_;
        actors = actors_;
        for (uint256 i; i < actors_.length; ++i) {
            ghostBalance[actors_[i]] = token_.balanceOf(actors_[i]);
        }
    }

    function actorCount() external view returns (uint256) {
        return actors.length;
    }

    function _actor(uint256 seed) internal view returns (address) {
        return actors[seed % actors.length];
    }

    /// @dev Amounts range past the sender's balance so the insufficient-balance path is exercised too.
    function transfer(uint256 fromSeed, uint256 toSeed, uint256 amount) external {
        calls++;
        address from = _actor(fromSeed);
        address to = _actor(toSeed);
        amount = bound(amount, 0, ghostBalance[from] + 1 ether);
        vm.prank(from);
        try token.transfer(to, amount) returns (bool ok) {
            if (!ok || amount > ghostBalance[from]) {
                ghostUnexpectedOutcomes++;
                return;
            }
            ghostBalance[from] -= amount;
            ghostBalance[to] += amount;
        } catch {
            if (amount <= ghostBalance[from]) ghostUnexpectedOutcomes++;
            else failedCallsAsExpected++;
        }
    }

    function approve(uint256 ownerSeed, uint256 spenderSeed, uint256 amount) external {
        calls++;
        address owner = _actor(ownerSeed);
        address spender = _actor(spenderSeed);
        // Mostly bounded, occasionally the infinite allowance.
        amount = amount % 8 == 0 ? type(uint256).max : bound(amount, 0, 2_000_000_000 ether);
        vm.prank(owner);
        try token.approve(spender, amount) returns (bool ok) {
            if (!ok) ghostUnexpectedOutcomes++;
            ghostAllowance[owner][spender] = amount;
        } catch {
            ghostUnexpectedOutcomes++;
        }
    }

    function transferFrom(uint256 spenderSeed, uint256 fromSeed, uint256 toSeed, uint256 amount) external {
        calls++;
        address spender = _actor(spenderSeed);
        address from = _actor(fromSeed);
        address to = _actor(toSeed);
        uint256 allowed = ghostAllowance[from][spender];
        uint256 cap = allowed == type(uint256).max ? ghostBalance[from] : allowed;
        amount = bound(amount, 0, cap + 1 ether);
        bool shouldSucceed = amount <= allowed && amount <= ghostBalance[from];
        vm.prank(spender);
        try token.transferFrom(from, to, amount) returns (bool ok) {
            if (!ok || !shouldSucceed) {
                ghostUnexpectedOutcomes++;
                return;
            }
            if (allowed != type(uint256).max) ghostAllowance[from][spender] = allowed - amount;
            ghostBalance[from] -= amount;
            ghostBalance[to] += amount;
        } catch {
            if (shouldSucceed) ghostUnexpectedOutcomes++;
            else failedCallsAsExpected++;
        }
    }

    /// @dev Burning through a transfer to the zero address, or approving it, must always fail.
    function transferToZero(uint256 fromSeed, uint256 amount) external {
        calls++;
        address from = _actor(fromSeed);
        amount = bound(amount, 0, ghostBalance[from]);
        vm.prank(from);
        try token.transfer(address(0), amount) {
            ghostUnexpectedOutcomes++;
        } catch {
            failedCallsAsExpected++;
        }
        vm.prank(from);
        try token.approve(address(0), amount) {
            ghostUnexpectedOutcomes++;
        } catch {
            failedCallsAsExpected++;
        }
    }
}

contract WorldTokenInvariantTest is Test {
    uint256 constant SUPPLY = 1_000_000_000 ether;
    address constant DEPLOYER = address(0xFAC7);

    WorldToken token;
    WorldTokenHandler handler;
    address[] actors;

    function setUp() public {
        vm.prank(DEPLOYER);
        token = new WorldToken();
        actors.push(DEPLOYER);
        actors.push(address(0xA11CE));
        actors.push(address(0xB0B));
        actors.push(address(0xCA401));
        actors.push(address(0xD0D0));

        // Spread the supply so every actor starts with something to move.
        for (uint256 i = 1; i < actors.length; ++i) {
            vm.prank(DEPLOYER);
            token.transfer(actors[i], SUPPLY / 10);
        }
        handler = new WorldTokenHandler(token, actors);
        targetContract(address(handler));
    }

    /// forge-config: default.invariant.runs = 256
    /// forge-config: default.invariant.depth = 64
    function invariant_supplyNeverChanges() public view {
        assertEq(token.totalSupply(), SUPPLY);
    }

    /// forge-config: default.invariant.runs = 256
    /// forge-config: default.invariant.depth = 64
    function invariant_balancesSumToSupply() public view {
        uint256 sum;
        for (uint256 i; i < actors.length; ++i) {
            sum += token.balanceOf(actors[i]);
        }
        assertEq(sum, token.totalSupply());
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.balanceOf(address(handler)), 0);
    }

    /// forge-config: default.invariant.runs = 256
    /// forge-config: default.invariant.depth = 64
    function invariant_balancesAndAllowancesMatchGhosts() public view {
        for (uint256 i; i < actors.length; ++i) {
            assertEq(token.balanceOf(actors[i]), handler.ghostBalance(actors[i]), "balance");
            for (uint256 j; j < actors.length; ++j) {
                assertEq(
                    token.allowance(actors[i], actors[j]), handler.ghostAllowance(actors[i], actors[j]), "allowance"
                );
            }
        }
    }

    /// forge-config: default.invariant.runs = 256
    /// forge-config: default.invariant.depth = 64
    function invariant_everyCallBehavedAsSpecified() public view {
        assertEq(handler.ghostUnexpectedOutcomes(), 0);
    }
}
