// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {WorldToken} from "../src/WorldToken.sol";

/// @notice Edge cases and failure paths beyond the base suite: zero amounts, self-transfers, the
/// whole supply in one move, allowance overwrites, failed calls leaving no trace, and a non-EOA deployer.
contract WorldTokenEdgesTest is Test {
    uint256 constant SUPPLY = 1_000_000_000 ether;
    address constant DEPLOYER = address(0xFAC7);
    address constant ALICE = address(0xA11CE);
    address constant BOB = address(0xB0B);

    WorldToken token;

    function setUp() public {
        vm.prank(DEPLOYER);
        token = new WorldToken();
    }

    function test_constantsMatchGetters() public view {
        assertEq(token.NAME(), token.name());
        assertEq(token.SYMBOL(), token.symbol());
        assertEq(token.TOTAL_SUPPLY(), 1_000_000_000 * 10 ** 18);
    }

    function test_zeroTransferFromEmptyAccountSucceeds() public {
        vm.prank(ALICE);
        assertTrue(token.transfer(BOB, 0));
        assertEq(token.balanceOf(ALICE), 0);
        assertEq(token.balanceOf(BOB), 0);
    }

    function test_zeroTransferToZeroAddressStillReverts() public {
        vm.prank(DEPLOYER);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        token.transfer(address(0), 0);
    }

    function test_selfTransferKeepsBalance() public {
        vm.prank(DEPLOYER);
        assertTrue(token.transfer(DEPLOYER, SUPPLY));
        assertEq(token.balanceOf(DEPLOYER), SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_selfTransferOverBalanceReverts() public {
        vm.prank(DEPLOYER);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, DEPLOYER, SUPPLY, SUPPLY + 1)
        );
        token.transfer(DEPLOYER, SUPPLY + 1);
    }

    function test_wholeSupplyMovesAndDeployerCannotSpendMore() public {
        vm.prank(DEPLOYER);
        token.transfer(ALICE, SUPPLY);
        assertEq(token.balanceOf(DEPLOYER), 0);
        assertEq(token.balanceOf(ALICE), SUPPLY);
        vm.prank(DEPLOYER);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, DEPLOYER, 0, 1));
        token.transfer(BOB, 1);
    }

    function test_maxAmountTransferReverts() public {
        vm.prank(DEPLOYER);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, DEPLOYER, SUPPLY, type(uint256).max)
        );
        token.transfer(ALICE, type(uint256).max);
    }

    function test_approveOverwritesRatherThanAdds() public {
        vm.startPrank(DEPLOYER);
        token.approve(ALICE, 10 ether);
        token.approve(ALICE, 3 ether);
        vm.stopPrank();
        assertEq(token.allowance(DEPLOYER, ALICE), 3 ether);
        vm.prank(ALICE);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, ALICE, 3 ether, 3 ether + 1)
        );
        token.transferFrom(DEPLOYER, BOB, 3 ether + 1);
    }

    function test_approveZeroRevokes() public {
        vm.startPrank(DEPLOYER);
        token.approve(ALICE, 10 ether);
        token.approve(ALICE, 0);
        vm.stopPrank();
        vm.prank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, ALICE, 0, 1));
        token.transferFrom(DEPLOYER, BOB, 1);
    }

    function test_allowanceIsPerSpender() public {
        vm.prank(DEPLOYER);
        token.approve(ALICE, 10 ether);
        vm.prank(BOB);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, BOB, 0, 1));
        token.transferFrom(DEPLOYER, BOB, 1);
    }

    /// @dev Allowance is checked before balance, and a failed transferFrom spends nothing.
    function test_transferFromOverBalanceRevertsAndKeepsAllowance() public {
        vm.prank(DEPLOYER);
        token.transfer(ALICE, 5 ether);
        vm.prank(ALICE);
        token.approve(BOB, 100 ether);
        vm.prank(BOB);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, ALICE, 5 ether, 6 ether));
        token.transferFrom(ALICE, BOB, 6 ether);
        assertEq(token.allowance(ALICE, BOB), 100 ether);
        assertEq(token.balanceOf(ALICE), 5 ether);
    }

    function test_transferFromToZeroAddressReverts() public {
        vm.prank(DEPLOYER);
        token.approve(ALICE, 1 ether);
        vm.prank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        token.transferFrom(DEPLOYER, address(0), 1 ether);
        assertEq(token.allowance(DEPLOYER, ALICE), 1 ether);
    }

    function test_zeroAddressCannotSpend() public {
        vm.prank(address(0));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSender.selector, address(0)));
        token.transfer(ALICE, 0);
        vm.prank(address(0));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidApprover.selector, address(0)));
        token.approve(ALICE, 1);
    }

    function test_transferFromSelfNeedsAllowance() public {
        vm.prank(DEPLOYER);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, DEPLOYER, 0, 1));
        token.transferFrom(DEPLOYER, ALICE, 1);
    }

    function test_rejectsEtherAndUnknownSelectors() public {
        vm.deal(ALICE, 1 ether);
        vm.prank(ALICE);
        (bool ok,) = address(token).call{value: 1 wei}("");
        assertFalse(ok);
        (ok,) = address(token).call(abi.encodeWithSignature("burn(uint256)", 1 ether));
        assertFalse(ok);
        assertEq(address(token).balance, 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    /// @dev The launch factory deploys from creation code with CREATE2; the supply goes to it, not tx.origin.
    function test_create2DeployerReceivesSupply() public {
        Create2Deployer factory = new Create2Deployer();
        address deployed = factory.deploy(type(WorldToken).creationCode, bytes32(uint256(7)));
        WorldToken t = WorldToken(deployed);
        assertEq(t.balanceOf(address(factory)), SUPPLY);
        assertEq(t.balanceOf(tx.origin), 0);
        assertEq(t.totalSupply(), SUPPLY);
    }

    /// forge-config: default.fuzz.runs = 1000
    function testFuzz_transferFromBetweenHolders(uint256 seedAmount, uint256 allowance, uint256 amount) public {
        seedAmount = bound(seedAmount, 0, SUPPLY);
        allowance = bound(allowance, 0, type(uint256).max);
        amount = bound(amount, 0, SUPPLY);
        vm.prank(DEPLOYER);
        token.transfer(ALICE, seedAmount);
        vm.prank(ALICE);
        token.approve(BOB, allowance);

        vm.prank(BOB);
        if (amount > allowance) {
            vm.expectRevert(
                abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, BOB, allowance, amount)
            );
            token.transferFrom(ALICE, DEPLOYER, amount);
        } else if (amount > seedAmount) {
            vm.expectRevert(
                abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, ALICE, seedAmount, amount)
            );
            token.transferFrom(ALICE, DEPLOYER, amount);
        } else {
            assertTrue(token.transferFrom(ALICE, DEPLOYER, amount));
            assertEq(token.balanceOf(ALICE), seedAmount - amount);
            assertEq(token.balanceOf(DEPLOYER), SUPPLY - seedAmount + amount);
            uint256 expected = allowance == type(uint256).max ? allowance : allowance - amount;
            assertEq(token.allowance(ALICE, BOB), expected);
        }
        assertEq(token.totalSupply(), SUPPLY);
    }
}

contract Create2Deployer {
    function deploy(bytes memory code, bytes32 salt) external returns (address deployed) {
        assembly ("memory-safe") {
            deployed := create2(0, add(code, 32), mload(code), salt)
        }
        require(deployed != address(0), "create2 failed");
    }
}
