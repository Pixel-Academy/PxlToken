// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";


contract PXLToken is ERC20, ERC20Snapshot, Ownable {
    address public dividendPool;
    address public liquidityPool;
    address public treasury;

    event DividendPoolUpdated(address prev, address next);
    event LiquidityPoolUpdated(address prev, address next);
    event TreasuryUpdated(address prev, address next);
    event ForceSnapshot(uint256 id, address by);

    uint256 constant MAX_SNAPSHOTS = 1000; // Limit to prevent gas exhaustion

    constructor(address _treasury) ERC20("Pixel Token", "PXL") {
        require(_treasury != address(0), "PXL: zero address");
        treasury = _treasury;
        _mint(treasury, 438_000 * 1e18);
    }

    function setDividendPool(address _dividendPool) external onlyOwner {
        emit DividendPoolUpdated(dividendPool, _dividendPool);
        dividendPool = _dividendPool;
    }

    function setLiquidityPool(address _liquidityPool) external onlyOwner {
        emit LiquidityPoolUpdated(liquidityPool, _liquidityPool);
        liquidityPool = _liquidityPool;
    }

    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "PXL: zero address");
        emit TreasuryUpdated(treasury, _treasury);
        treasury = _treasury;
    }

    function forceSnapshot() external returns (uint256) {
        require(msg.sender == owner() || msg.sender == dividendPool, "PXL: unauthorized");
        require(_snapshotCount() <= MAX_SNAPSHOTS, "PXL: snapshot limit reached");
        uint256 id = _snapshot();
        emit ForceSnapshot(id, msg.sender);
        return id;
    }

    function getSnapshotBalance(address account, uint256 snapshotId) external view returns (uint256) {
        require(snapshotId > 0 && snapshotId <= _snapshotCount(), "PXL: invalid snapshot id");
        return balanceOfAt(account, snapshotId);
    }

    function getSnapshotTotalSupply(uint256 snapshotId) external view returns (uint256) {
        require(snapshotId > 0 && snapshotId <= _snapshotCount(), "PXL: invalid snapshot id");
        return totalSupplyAt(snapshotId);
    }

    function _snapshotCount() internal view returns (uint256) {
        return _getCurrentSnapshotId();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Snapshot)
    {
        super._beforeTokenTransfer(from, to, amount);
    }
}