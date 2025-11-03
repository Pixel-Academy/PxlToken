
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/PXLToken.sol";

contract PXLTokenTest is Test {
    PXLToken token;
    address treasury = address(0x1);
    address owner = address(this);
    address alice = address(0x2);
    address bob = address(0x3);

    function setUp() public {
        token = new PXLToken(treasury);
    }

    function test_Constructor() public {
        assertEq(token.name(), "Pixel Token", "Name mismatch");
        assertEq(token.symbol(), "PXL", "Symbol mismatch");
        assertEq(token.totalSupply(), 438_000 ether, "Total supply mismatch");
        assertEq(token.balanceOf(treasury), 438_000 ether, "Treasury balance mismatch");
        assertEq(token.treasury(), treasury, "Treasury mismatch");
        assertEq(token.owner(), owner, "Owner mismatch");
    }

    function test_RevertWhen_ConstructorZeroTreasury() public {
        vm.expectRevert("PXL: zero address");
        new PXLToken(address(0));
    }

    function test_SetDividendPool() public {
        address newPool = address(0x4);
        vm.expectEmit(true, true, false, false, address(token));
        emit PXLToken.DividendPoolUpdated(address(0), newPool);
        token.setDividendPool(newPool);
        assertEq(token.dividendPool(), newPool, "Dividend pool not updated");
    }

    function test_RevertWhen_SetDividendPoolNonOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        token.setDividendPool(address(0x4));
    }

    function test_SetTreasury() public {
        address newTreasury = address(0x5);
        vm.expectEmit(true, true, false, false, address(token));
        emit PXLToken.TreasuryUpdated(treasury, newTreasury);
        token.setTreasury(newTreasury);
        assertEq(token.treasury(), newTreasury, "Treasury not updated");
    }

    function test_RevertWhen_SetTreasuryZero() public {
        vm.expectRevert("PXL: zero address");
        token.setTreasury(address(0));
    }

    function test_ForceSnapshot() public {
        token.setDividendPool(alice);
        vm.expectEmit(true, false, false, true, address(token));
        emit PXLToken.ForceSnapshot(1, owner);
        uint256 id1 = token.forceSnapshot();
        assertEq(id1, 1, "Snapshot ID mismatch");

        vm.prank(alice);
        uint256 id2 = token.forceSnapshot();
        assertEq(id2, 2, "Snapshot ID mismatch");
    }

    function test_RevertWhen_ForceSnapshotUnauthorized() public {
        vm.prank(bob);
        vm.expectRevert("PXL: unauthorized");
        token.forceSnapshot();
    }

    function test_RevertWhen_ForceSnapshotLimitReached() public {
        for (uint256 i = 0; i < 1001; i++) {
            token.forceSnapshot();
        }
        vm.expectRevert("PXL: snapshot limit reached");
        token.forceSnapshot();
    }

    function test_SnapshotBalances() public {
        vm.prank(treasury);
        token.transfer(alice, 100 ether);

        uint256 id1 = token.forceSnapshot();
        assertEq(token.getSnapshotBalance(alice, id1), 100 ether, "Alice balance at snapshot 1 mismatch");
        assertEq(token.getSnapshotTotalSupply(id1), 438_000 ether, "Total supply at snapshot 1 mismatch");

        vm.prank(treasury);
        token.transfer(bob, 200 ether);

        uint256 id2 = token.forceSnapshot();
        assertEq(token.getSnapshotBalance(alice, id2), 100 ether, "Alice balance at snapshot 2 mismatch");
        assertEq(token.getSnapshotBalance(bob, id2), 200 ether, "Bob balance at snapshot 2 mismatch");
    }

    function test_RevertWhen_InvalidSnapshotId() public {
        vm.expectRevert("PXL: invalid snapshot id");
        token.getSnapshotBalance(alice, 0);
    }

    function test_Transfer() public {
        vm.prank(treasury);
        token.transfer(alice, 100 ether);
        assertEq(token.balanceOf(alice), 100 ether, "Transfer failed");
    }
}
