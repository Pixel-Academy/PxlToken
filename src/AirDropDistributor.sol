// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract PXLAirdropDistributor is Ownable {
    using SafeERC20 for IERC20;
    IERC20 public immutable pxl;
    mapping(address => uint256) public allocation;
    mapping(address => bool) public claimed;
    uint256 public constant PRIVATE_SALE_CAP = 219_000 ether;
    uint256 public totalAllocated;

    event OwnerChanged(address prev, address next);
    event AllocationSet(address user, uint256 amount);
    event Claimed(address user, uint256 amount);

    constructor(address _pxl) {
        require(_pxl != address(0), "Airdrop: zero address");
        pxl = IERC20(_pxl);
    }

    function setOwner(address _next) external onlyOwner {
        require(_next != address(0), "Airdrop: zero address");
        emit OwnerChanged(owner(), _next);
        _transferOwnership(_next);
    }

    function setAllocations(address[] calldata users, uint256[] calldata amounts) external onlyOwner {
        require(users.length == amounts.length, "Airdrop: length mismatch");
        uint256 newTotalAllocated = totalAllocated;
        for (uint256 i = 0; i < users.length; ++i) {
            address user = users[i];
            uint256 prevAmt = allocation[user];
            newTotalAllocated = newTotalAllocated - prevAmt + amounts[i];
            allocation[user] = amounts[i];
            emit AllocationSet(user, amounts[i]);
        }
        require(newTotalAllocated <= PRIVATE_SALE_CAP, "Airdrop: cap exceeded");
        totalAllocated = newTotalAllocated;
    }

    function claim() external {
        require(!claimed[msg.sender], "Airdrop: already claimed");
        uint256 amt = allocation[msg.sender];
        require(amt > 0, "Airdrop: no allocation");
        claimed[msg.sender] = true;
        pxl.safeTransfer(msg.sender, amt);
        emit Claimed(msg.sender, amt);
    }
}