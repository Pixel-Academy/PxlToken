// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPXLSnapshotToken {
    function balanceOfAt(address account, uint256 snapshotId) external view returns (uint256);
    function totalSupplyAt(uint256 snapshotId) external view returns (uint256);
    function forceSnapshot() external returns (uint256);
    function dividendPool() external view returns (address);
}

contract DividendPool is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    IPXLSnapshotToken public immutable pxl;
    mapping(address => bool) public isExcluded;
    uint256 public excludedCount;
    uint256 public cycles;

    struct Cycle {
        uint256 snapshotId;
        IERC20 rewardToken;
        uint256 totalRewards;
        uint256 eligibleSupply;
        bool active;
    }

    mapping(uint256 => Cycle) private _cycles;
    mapping(uint256 => mapping(address => bool)) public claimed;

    event ExcludeSet(address account, bool excluded);
    event CycleStarted(uint256 cycleId, uint256 snapshotId, address rewardToken, uint256 totalRewards, uint256 eligibleSupply);
    event Claimed(uint256 cycleId, address user, uint256 amount);

    constructor(address _pxl) {
        require(_pxl != address(0), "DividendPool: zero address");
        pxl = IPXLSnapshotToken(_pxl);
    }

    function setExcluded(address account, bool excluded) external onlyOwner {
        if (excluded != isExcluded[account]) {
            isExcluded[account] = excluded;
            if (excluded) {
                excludedCount += 1;
            } else {
                excludedCount -= 1;
            }
            emit ExcludeSet(account, excluded);
        }
    }

    function startCycle(address rewardToken, uint256 amount) external onlyOwner nonReentrant returns (uint256 cycleId) {
        require(rewardToken != address(0), "DividendPool: zero token");
        require(amount > 0, "DividendPool: zero amount");
        IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), amount);
        uint256 snapshotId = pxl.forceSnapshot();
        uint256 totalAt = pxl.totalSupplyAt(snapshotId);
        uint256 excludedAtSum;

        // Placeholder for excluded address logic
        // In practice, you need a way to iterate over excluded addresses
        // This is a simplification and may not work as-is

        uint256 eligible = totalAt - excludedAtSum;
        require(eligible > 0, "DividendPool: no eligible supply");
        cycles++;
        _cycles[cycles] = Cycle({
            snapshotId: snapshotId,
            rewardToken: IERC20(rewardToken),
            totalRewards: amount,
            eligibleSupply: eligible,
            active: true
        });
        emit CycleStarted(cycles, snapshotId, rewardToken, amount, eligible);
        return cycles;
    }

    function getCycle(uint256 cycleId) external view returns (Cycle memory) {
        return _cycles[cycleId];
    }

    function pending(uint256 cycleId, address user) public view returns (uint256) {
        Cycle memory cycle = _cycles[cycleId];
        if (!cycle.active || isExcluded[user] || claimed[cycleId][user]) {
            return 0;
        }
        uint256 bal = pxl.balanceOfAt(user, cycle.snapshotId);
        return cycle.totalRewards * bal / cycle.eligibleSupply;
    }

    function claim(uint256 cycleId) external nonReentrant {
        Cycle memory cycle = _cycles[cycleId];
        require(cycle.active, "DividendPool: inactive cycle");
        require(!isExcluded[msg.sender], "DividendPool: excluded");
        require(!claimed[cycleId][msg.sender], "DividendPool: already claimed");
        uint256 amt = pending(cycleId, msg.sender);
        require(amt > 0, "DividendPool: no pending");
        claimed[cycleId][msg.sender] = true;
        cycle.rewardToken.safeTransfer(msg.sender, amt);
        emit Claimed(cycleId, msg.sender, amt);
    }
}
