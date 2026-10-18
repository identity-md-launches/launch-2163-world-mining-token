// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {WorldToken} from "../src/WorldToken.sol";
import {DeployWorldToken} from "../script/DeployWorldToken.s.sol";

contract WorldTokenTest is Test {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    uint256 constant SUPPLY = 1_000_000_000 ether;
    address constant DEPLOYER = address(0xFAC7);
    address constant ALICE = address(0xA11CE);
    address constant BOB = address(0xB0B);

    WorldToken token;

    function setUp() public {
        vm.prank(DEPLOYER);
        token = new WorldToken();
    }

    function test_metadata() public view {
        assertEq(token.name(), "World mining token");
        assertEq(token.symbol(), "WORLD");
        assertEq(token.decimals(), 18);
    }

    function test_wholeSupplyMintedToDeployer() public view {
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(token.TOTAL_SUPPLY(), SUPPLY);
        assertEq(token.balanceOf(DEPLOYER), SUPPLY);
    }

    function test_constructorEmitsMintEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), DEPLOYER, SUPPLY);
        vm.prank(DEPLOYER);
        new WorldToken();
    }

    function test_transferMovesExactAmount() public {
        vm.expectEmit(true, true, false, true, address(token));
        emit Transfer(DEPLOYER, ALICE, 100 ether);
        vm.prank(DEPLOYER);
        assertTrue(token.transfer(ALICE, 100 ether));
        assertEq(token.balanceOf(ALICE), 100 ether);
        assertEq(token.balanceOf(DEPLOYER), SUPPLY - 100 ether);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_transferRevertsOnInsufficientBalance() public {
        vm.prank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, ALICE, 0, 1));
        token.transfer(BOB, 1);
    }

    function test_transferRevertsToZeroAddress() public {
        vm.prank(DEPLOYER);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        token.transfer(address(0), 1);
    }

    function test_approveAndTransferFrom() public {
        vm.prank(DEPLOYER);
        vm.expectEmit(true, true, false, true, address(token));
        emit Approval(DEPLOYER, ALICE, 50 ether);
        assertTrue(token.approve(ALICE, 50 ether));
        assertEq(token.allowance(DEPLOYER, ALICE), 50 ether);

        vm.prank(ALICE);
        assertTrue(token.transferFrom(DEPLOYER, BOB, 20 ether));
        assertEq(token.balanceOf(BOB), 20 ether);
        assertEq(token.allowance(DEPLOYER, ALICE), 30 ether);
    }

    function test_infiniteAllowanceIsNotDecreased() public {
        vm.prank(DEPLOYER);
        token.approve(ALICE, type(uint256).max);
        vm.prank(ALICE);
        token.transferFrom(DEPLOYER, BOB, 1 ether);
        assertEq(token.allowance(DEPLOYER, ALICE), type(uint256).max);
    }

    function test_transferFromRevertsOverAllowance() public {
        vm.prank(DEPLOYER);
        token.approve(ALICE, 1 ether);
        vm.prank(ALICE);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, ALICE, 1 ether, 1 ether + 1)
        );
        token.transferFrom(DEPLOYER, BOB, 1 ether + 1);
    }

    function test_transferFromRevertsWithoutApproval() public {
        vm.prank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, ALICE, 0, 1));
        token.transferFrom(DEPLOYER, ALICE, 1);
    }

    function test_approveRevertsForZeroSpender() public {
        vm.prank(DEPLOYER);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        token.approve(address(0), 1);
    }

    function test_noMintOrAdminEntryPoints() public {
        string[6] memory sigs = [
            "mint(address,uint256)",
            "mint(uint256)",
            "transferOwnership(address)",
            "owner()",
            "pause()",
            "burnFrom(address,uint256)"
        ];
        for (uint256 i; i < sigs.length; ++i) {
            vm.prank(DEPLOYER);
            (bool ok,) = address(token).call(abi.encodeWithSignature(sigs[i], ALICE, 1 ether));
            assertFalse(ok, sigs[i]);
        }
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(token.balanceOf(ALICE), 0);
    }

    function test_deployScriptMintsToCaller() public {
        DeployWorldToken script = new DeployWorldToken();
        WorldToken deployed = script.deploy();
        assertEq(deployed.balanceOf(address(script)), SUPPLY);
        assertEq(deployed.totalSupply(), SUPPLY);
    }

    function testFuzz_transferConservesSupply(address to, uint256 amount) public {
        vm.assume(to != address(0) && to != DEPLOYER);
        amount = bound(amount, 0, SUPPLY);
        vm.prank(DEPLOYER);
        token.transfer(to, amount);
        assertEq(token.balanceOf(to), amount);
        assertEq(token.balanceOf(DEPLOYER), SUPPLY - amount);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_transferFromRespectsAllowance(uint256 allowance, uint256 amount) public {
        allowance = bound(allowance, 0, SUPPLY);
        amount = bound(amount, 0, SUPPLY);
        vm.prank(DEPLOYER);
        token.approve(ALICE, allowance);
        vm.prank(ALICE);
        if (amount > allowance) {
            vm.expectRevert(
                abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, ALICE, allowance, amount)
            );
            token.transferFrom(DEPLOYER, BOB, amount);
        } else {
            token.transferFrom(DEPLOYER, BOB, amount);
            assertEq(token.balanceOf(BOB), amount);
            assertEq(token.allowance(DEPLOYER, ALICE), allowance - amount);
        }
        assertEq(token.totalSupply(), SUPPLY);
    }
}
