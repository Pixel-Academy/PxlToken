
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/AirDropDistributor.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockPXL is ERC20 {
    constructor() ERC20("Pixel Token", "PXL") {
        _mint(msg.sender, 1_000_000 ether);
    }
}

contract PXLAirdropDistributorTest is Test {
    PXLAirdropDistributor distributor;
    MockPXL pxl;
    address owner = address(this);
    address alice = address(0x1);
    address bob = address(0x2);

    function setUp() public {
        pxl = new MockPXL();
        distributor = new PXLAirdropDistributor(address(pxl));
        pxl.transfer(address(distributor), 500_000 ether);
    }

    function test_Constructor() public {
        assertEq(address(distributor.pxl()), address(pxl), "PXL token address mismatch");
        assertEq(distributor.owner(), owner, "Owner address mismatch");
        assertEq(distributor.totalAllocated(), 0, "Initial totalAllocated should be 0");
    }

    function test_RevertWhen_ConstructorZeroAddress() public {
        vm.expectRevert("Airdrop: zero address");
        new PXLAirdropDistributor(address(0));
    }

    function test_SetOwner() public {
        address newOwner = address(0x4);
        vm.expectEmit(true, true, false, false, address(distributor));
        emit PXLAirdropDistributor.OwnerChanged(owner, newOwner);
        distributor.setOwner(newOwner);
        assertEq(distributor.owner(), newOwner, "Owner not updated");
    }

    function test_RevertWhen_SetOwnerNonOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        distributor.setOwner(alice);
    }

    function test_RevertWhen_SetOwnerZeroAddress() public {
        vm.expectRevert("Airdrop: zero address");
        distributor.setOwner(address(0));
    }

    function test_SetAllocations() public {
        address[] memory users = new address[](2);
        users[0] = alice;
        users[1] = bob;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100 ether;
        amounts[1] = 200 ether;

        vm.expectEmit(true, false, false, true, address(distributor));
        emit PXLAirdropDistributor.AllocationSet(alice, 100 ether);
        vm.expectEmit(true, false, false, true, address(distributor));
        emit PXLAirdropDistributor.AllocationSet(bob, 200 ether);

        distributor.setAllocations(users, amounts);

        assertEq(distributor.allocation(alice), 100 ether, "Alice allocation mismatch");
        assertEq(distributor.allocation(bob), 200 ether, "Bob allocation mismatch");
        assertEq(distributor.totalAllocated(), 300 ether, "Total allocated mismatch");
    }

    function test_RevertWhen_SetAllocationsLengthMismatch() public {
        address[] memory users = new address[](2);
        users[0] = alice;
        users[1] = bob;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100 ether;
        vm.expectRevert("Airdrop: length mismatch");
        distributor.setAllocations(users, amounts);
    }

    function test_RevertWhen_SetAllocationsExceedCap() public {
        address[] memory users = new address[](1);
        users[0] = alice;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 220_000 ether;
        vm.expectRevert("Airdrop: cap exceeded");
        distributor.setAllocations(users, amounts);
    }

    function test_RevertWhen_SetAllocationsNonOwner() public {
        vm.prank(alice);
        address[] memory users = new address[](1);
        users[0] = alice;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100 ether;
        vm.expectRevert("Ownable: caller is not the owner");
        distributor.setAllocations(users, amounts);
    }

    function test_Claim() public {
        address[] memory users = new address[](1);
        users[0] = alice;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100 ether;
        distributor.setAllocations(users, amounts);

        vm.prank(alice);
        vm.expectEmit(true, false, false, true, address(distributor));
        emit PXLAirdropDistributor.Claimed(alice, 100 ether);
        distributor.claim();

        assertTrue(distributor.claimed(alice), "Alice should be marked as claimed");
        assertEq(pxl.balanceOf(alice), 100 ether, "Alice balance mismatch");
    }

    function test_RevertWhen_ClaimNoAllocation() public {
        vm.prank(alice);
        vm.expectRevert("Airdrop: no allocation");
        distributor.claim();
    }

    function test_RevertWhen_ClaimAlreadyClaimed() public {
        address[] memory users = new address[](1);
        users[0] = alice;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100 ether;
        distributor.setAllocations(users, amounts);

        vm.prank(alice);
        distributor.claim();

        vm.prank(alice);
        vm.expectRevert("Airdrop: already claimed");
        distributor.claim();
    }

    function test_RevertWhen_ClaimInsufficientBalance() public {
        address[] memory users = new address[](1);
        users[0] = alice;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100 ether;
        distributor.setAllocations(users, amounts);

        vm.prank(address(distributor));
        pxl.transfer(owner, 500_000 ether);

        vm.prank(alice);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        distributor.claim();
    }

    function test_UpdateAllocations() public {
        address[] memory users = new address[](1);
        users[0] = alice;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100 ether;
        distributor.setAllocations(users, amounts);

        amounts[0] = 150 ether;
        vm.expectEmit(true, false, false, true, address(distributor));
        emit PXLAirdropDistributor.AllocationSet(alice, 150 ether);
        distributor.setAllocations(users, amounts);

        assertEq(distributor.allocation(alice), 150 ether, "Alice allocation not updated");
        assertEq(distributor.totalAllocated(), 150 ether, "Total allocated not updated");
    }
}