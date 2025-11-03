// SPDX-License-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/DividendPool.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockPXLToken is ERC20 {
    uint256 public snapshotCount;
    mapping(address => mapping(uint256 => uint256)) public balancesAt;
    mapping(uint256 => uint256) public totalSupplyAtSnapshot;
    address public dividendPool;
    address[] public snapshotAccounts;

    constructor() ERC20("Pixel Token", "PXL") {
        _mint(msg.sender, 1_000_000 ether);
        dividendPool = msg.sender;
    }

    function setDividendPool(address _dividendPool) external {
        dividendPool = _dividendPool;
    }

    function addSnapshotAccount(address account) external {
        snapshotAccounts.push(account);
    }

    function forceSnapshot() external returns (uint256) {
        require(msg.sender == dividendPool, "Unauthorized");
        snapshotCount++;
        totalSupplyAtSnapshot[snapshotCount] = totalSupply();
        console.logString("Snapshot taken");
        console.logUint(snapshotCount);
        console.logString("Total supply at snapshot:");
        console.logUint(totalSupplyAtSnapshot[snapshotCount]);
        for (uint i = 0; i < snapshotAccounts.length; i++) {
            balancesAt[snapshotAccounts[i]][snapshotCount] = balanceOf(snapshotAccounts[i]);
            console.logString("Account:");
            console.logAddress(snapshotAccounts[i]);
            console.logString("Balance at snapshot:");
            console.logUint(balancesAt[snapshotAccounts[i]][snapshotCount]);
        }
        return snapshotCount;
    }

    function balanceOfAt(address account, uint256 snapshotId) external view returns (uint256) {
        return balancesAt[account][snapshotId];
    }

    function totalSupplyAt(uint256 snapshotId) external view returns (uint256) {
        return totalSupplyAtSnapshot[snapshotId];
    }
}
contract MockRewardToken is ERC20 {
    constructor() ERC20("Reward Token", "RWD") {
        _mint(msg.sender, 1_000_000 ether);
    }
}

contract MockMaliciousRewardToken is ERC20 {
    DividendPool public dividendPool;

    constructor(address _dividendPool) ERC20("Malicious Reward Token", "MRWD") {
        _mint(msg.sender, 1_000_000 ether);
        dividendPool = DividendPool(_dividendPool);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        console.logString("MockMaliciousRewardToken: transferring");
        console.logUint(amount);
        console.logString("to");
        console.logAddress(to);
        bool success = super.transfer(to, amount);
        if (to != address(dividendPool)) {
            console.logString("MockMaliciousRewardToken: attempting reentrant claim");
            dividendPool.claim(1);
        }
        return success;
    }
}

contract MaliciousClaimer {
    DividendPool public dividendPool;

    constructor(address _dividendPool) {
        dividendPool = DividendPool(_dividendPool);
    }

    function attack() public {
        console.logString("MaliciousClaimer: attack called");
        dividendPool.claim(1);
    }

    receive() external payable {
        console.logString("MaliciousClaimer: receive called");
        dividendPool.claim(1);
    }
}

contract DividendPoolTest is Test {
    DividendPool dividendPool;
    MockPXLToken pxl;
    MockRewardToken rewardToken;
    address owner = address(this);
    address alice = address(0x1);
    address bob = address(0x2);

    function setUp() public {
        pxl = new MockPXLToken();
        rewardToken = new MockRewardToken();
        dividendPool = new DividendPool(address(pxl));
        pxl.setDividendPool(address(dividendPool));
        pxl.addSnapshotAccount(owner);
        pxl.addSnapshotAccount(alice);
        pxl.addSnapshotAccount(bob);
        pxl.transfer(alice, 100_000 ether);
        pxl.transfer(bob, 200_000 ether);
        rewardToken.transfer(owner, 500_000 ether);
        rewardToken.approve(address(dividendPool), type(uint256).max);
    }

    function test_Constructor() public {
        assertEq(address(dividendPool.pxl()), address(pxl), "PXL token address mismatch");
        assertEq(dividendPool.owner(), owner, "Owner address mismatch");
        assertEq(dividendPool.cycles(), 0, "Initial cycles should be 0");
        assertEq(dividendPool.excludedCount(), 0, "Initial excluded count should be 0");
    }

    function test_RevertWhen_ConstructorZeroAddress() public {
        vm.expectRevert("DividendPool: zero address");
        new DividendPool(address(0));
    }

    function test_SetExcluded() public {
        vm.expectEmit(true, false, false, true, address(dividendPool));
        emit DividendPool.ExcludeSet(alice, true);
        dividendPool.setExcluded(alice, true);
        assertTrue(dividendPool.isExcluded(alice), "Alice should be excluded");
        assertEq(dividendPool.excludedCount(), 1, "Excluded count should be 1");

        vm.expectEmit(true, false, false, true, address(dividendPool));
        emit DividendPool.ExcludeSet(alice, false);
        dividendPool.setExcluded(alice, false);
        assertFalse(dividendPool.isExcluded(alice), "Alice should not be excluded");
        assertEq(dividendPool.excludedCount(), 0, "Excluded count should be 0");
    }

    function test_RevertWhen_SetExcludedNonOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        dividendPool.setExcluded(alice, true);
    }

    function test_StartCycle() public {
        uint256 rewardAmount = 10_000 ether;
        uint256 totalSupply = pxl.totalSupply();
        vm.expectEmit(true, true, true, true, address(dividendPool));
        emit DividendPool.CycleStarted(1, 1, address(rewardToken), rewardAmount, totalSupply);
        uint256 cycleId = dividendPool.startCycle(address(rewardToken), rewardAmount);

        assertEq(cycleId, 1, "Cycle ID should be 1");
        assertEq(dividendPool.cycles(), 1, "Cycles count should be 1");

        DividendPool.Cycle memory cycle = dividendPool.getCycle(cycleId);
        assertEq(cycle.snapshotId, 1, "Snapshot ID mismatch");
        assertEq(address(cycle.rewardToken), address(rewardToken), "Reward token mismatch");
        assertEq(cycle.totalRewards, rewardAmount, "Total rewards mismatch");
        assertEq(cycle.eligibleSupply, totalSupply, "Eligible supply mismatch");
        assertTrue(cycle.active, "Cycle should be active");
        assertEq(rewardToken.balanceOf(address(dividendPool)), rewardAmount, "Reward token balance mismatch");
    }

    function test_RevertWhen_StartCycleZeroToken() public {
        vm.expectRevert("DividendPool: zero token");
        dividendPool.startCycle(address(0), 10_000 ether);
    }

    function test_RevertWhen_StartCycleZeroAmount() public {
        vm.expectRevert("DividendPool: zero amount");
        dividendPool.startCycle(address(rewardToken), 0);
    }

    function test_RevertWhen_StartCycleNoEligibleSupply() public {
        vm.mockCall(
            address(pxl),
            abi.encodeWithSelector(IPXLSnapshotToken.totalSupplyAt.selector, 1),
            abi.encode(0)
        );
        vm.expectRevert("DividendPool: no eligible supply");
        dividendPool.startCycle(address(rewardToken), 10_000 ether);
    }

    function test_Pending() public {
        dividendPool.startCycle(address(rewardToken), 10_000 ether);

        uint256 aliceBalance = 100_000 ether;
        uint256 totalSupply = pxl.totalSupply();
        uint256 expectedPending = (10_000 ether * aliceBalance) / totalSupply;

        uint256 pendingAmount = dividendPool.pending(1, alice);
        assertEq(pendingAmount, expectedPending, "Pending amount mismatch");
    }

    function test_Claim() public {
        dividendPool.startCycle(address(rewardToken), 10_000 ether);

        uint256 aliceBalance = 100_000 ether;
        uint256 totalSupply = pxl.totalSupply();
        uint256 expectedAmount = (10_000 ether * aliceBalance) / totalSupply;

        vm.prank(alice);
        vm.expectEmit(true, true, false, true, address(dividendPool));
        emit DividendPool.Claimed(1, alice, expectedAmount);
        dividendPool.claim(1);

        assertTrue(dividendPool.claimed(1, alice), "Alice should be marked as claimed");
        assertEq(rewardToken.balanceOf(alice), expectedAmount, "Alice reward balance mismatch");
    }

    function test_RevertWhen_ClaimInactiveCycle() public {
        vm.prank(alice);
        vm.expectRevert("DividendPool: inactive cycle");
        dividendPool.claim(1);
    }

    function test_RevertWhen_ClaimExcludedUser() public {
        dividendPool.setExcluded(alice, true);
        dividendPool.startCycle(address(rewardToken), 10_000 ether);
        vm.prank(alice);
        vm.expectRevert("DividendPool: excluded");
        dividendPool.claim(1);
    }

    function test_RevertWhen_ClaimAlreadyClaimed() public {
        dividendPool.startCycle(address(rewardToken), 10_000 ether);
        vm.prank(alice);
        dividendPool.claim(1);
        vm.prank(alice);
        vm.expectRevert("DividendPool: already claimed");
        dividendPool.claim(1);
    }

    function test_RevertWhen_ClaimNoPending() public {
        dividendPool.startCycle(address(rewardToken), 10_000 ether);
        vm.mockCall(
            address(pxl),
            abi.encodeWithSelector(IPXLSnapshotToken.balanceOfAt.selector, alice, 1),
            abi.encode(0)
        );
        vm.prank(alice);
        vm.expectRevert("DividendPool: no pending");
        dividendPool.claim(1);
    }

    // function test_RevertWhen_Reentrancy() public {
    //     MockMaliciousRewardToken maliciousRewardToken = new MockMaliciousRewardToken(address(dividendPool));
    //     maliciousRewardToken.transfer(owner, 500_000 ether);
    //     vm.prank(owner);
    //     maliciousRewardToken.approve(address(dividendPool), type(uint256).max);

    //     MaliciousClaimer malicious = new MaliciousClaimer(address(dividendPool));
    //     pxl.transfer(address(malicious), 100_000 ether);
    //     pxl.addSnapshotAccount(address(malicious));
    //     vm.mockCall(
    //         address(pxl),
    //         abi.encodeWithSelector(IPXLSnapshotToken.totalSupplyAt.selector, 1),
    //         abi.encode(1_000_000 ether)
    //     );
    //     vm.prank(address(dividendPool));
    //     uint256 snapshotId = pxl.forceSnapshot();
    //     vm.prank(owner);
    //     vm.expectEmit(true, true, true, true, address(dividendPool));
    //     emit DividendPool.CycleStarted(1, snapshotId, address(maliciousRewardToken), 10_000 ether, 1_000_000 ether);
    //     uint256 cycleId = dividendPool.startCycle(address(maliciousRewardToken), 10_000 ether);

    //     DividendPool.Cycle memory cycle = dividendPool.getCycle(cycleId);
    //     assertEq(cycleId, 1, "Cycle ID should be 1");
    //     assertEq(cycle.snapshotId, snapshotId, "Snapshot ID mismatch");
    //     assertTrue(cycle.active, "Cycle should be active");
    //     assertGt(cycle.eligibleSupply, 0, "Eligible supply should be non-zero");
    //     console.logString("Starting reentrancy test");
    //     console.logString("MaliciousClaimer PXL balance:");
    //     console.logUint(pxl.balanceOf(address(malicious)));
    //     console.logString("MaliciousClaimer pending rewards:");
    //     console.logUint(dividendPool.pending(cycleId, address(malicious)));
    //     console.logString("MaliciousClaimer claimed status:");
    //     console.logBool(dividendPool.claimed(cycleId, address(malicious)));
    //     console.logString("Cycle ID:");
    //     console.logUint(cycleId);
    //     console.logString("Snapshot ID:");
    //     console.logUint(snapshotId);
    //     console.logString("Cycle active:");
    //     console.logBool(cycle.active);
    //     console.logString("Cycle total rewards:");
    //     console.logUint(cycle.totalRewards);
    //     console.logString("Cycle eligible supply:");
    //     console.logUint(cycle.eligibleSupply);
    //     console.logString("Total supply at snapshot:");
    //     console.logUint(pxl.totalSupplyAt(snapshotId));
    //     console.logString("MaliciousClaimer balance at snapshot:");
    //     console.logUint(pxl.balanceOfAt(address(malicious), snapshotId));
    //     vm.prank(address(malicious));
    //     vm.expectRevert("ReentrancyGuard: reentrant call");
    //     malicious.attack();
    // }
}