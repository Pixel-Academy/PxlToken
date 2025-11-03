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
