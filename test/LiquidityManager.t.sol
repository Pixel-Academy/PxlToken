pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/LiquidityManager.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1_000_000 ether);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        uint256 currentAllowance = allowance(sender, _msgSender());
        require(currentAllowance >= amount, "ERC20: insufficient allowance");
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), currentAllowance - amount);
        return true;
    }
}

contract MockUniswapV2Router is IUniswapV2Router02 {
    function sortTokens(address tokenA, address tokenB, uint amountADesired, uint amountBDesired)
        internal pure returns (address token0, uint amount0) {
        token0 = tokenA < tokenB ? tokenA : tokenB;
        amount0 = tokenA < tokenB ? amountADesired : amountBDesired;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external override returns (uint amountA, uint amountB, uint liquidity) {
        require(amountADesired > 0 && amountBDesired > 0, "Invalid amounts");
        (address token0, uint amount0) = sortTokens(tokenA, tokenB, amountADesired, amountBDesired);
        IERC20(tokenA).transferFrom(msg.sender, address(this), amountADesired);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountBDesired);
        amountA = tokenA == token0 ? amount0 : amountBDesired;
        amountB = tokenA == token0 ? amountBDesired : amount0;
        liquidity = 1000 ether;
    }

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable override returns (uint amountToken, uint amountETH, uint liquidity) {
        require(amountTokenDesired > 0 && msg.value > 0, "Invalid amounts");
        IERC20(token).transferFrom(msg.sender, address(this), amountTokenDesired);
        amountToken = amountTokenDesired;
        amountETH = msg.value;
        liquidity = 1000 ether;
    }

    function getAmountsOut(uint amountIn, address[] memory path) external view override returns (uint[] memory amounts) {
        require(amountIn > 0, "Invalid amountIn");
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        amounts[1] = amountIn / 2;
    }

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external override returns (uint[] memory amounts) {
        require(amountOut > 0 && amountInMax > 0, "Invalid amounts");
        require(IERC20(path[0]).allowance(msg.sender, address(this)) >= amountInMax, "ERC20: insufficient allowance");
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountInMax);
        IERC20(path[1]).transfer(to, amountOut);
        amounts = new uint[](path.length);
        amounts[0] = amountInMax;
        amounts[1] = amountOut;
    }

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external override returns (uint[] memory amounts) {
        require(amountIn > 0, "Invalid amountIn");
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        amounts[1] = amountIn / 2;
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        IERC20(path[1]).transfer(to, amounts[1]);
    }

    function swapTokensForExactETH(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external override returns (uint[] memory amounts) {
        require(amountOut > 0 && amountInMax > 0, "Invalid amounts");
        amounts = new uint[](path.length);
        amounts[0] = amountInMax;
        amounts[1] = amountOut;
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountInMax);
        payable(to).transfer(amountOut);
    }

    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external override returns (uint[] memory amounts) {
        require(amountIn > 0, "Invalid amountIn");
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        amounts[1] = amountIn / 2;
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        payable(to).transfer(amounts[1]);
    }

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable override returns (uint[] memory amounts) {
        require(msg.value > 0, "Invalid msg.value");
        amounts = new uint[](path.length);
        amounts[0] = msg.value;
        amounts[1] = msg.value / 2;
        IERC20(path[1]).transfer(to, amounts[1]);
    }

    function swapETHForExactTokens(
        uint amountOut,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable override returns (uint[] memory amounts) {
        require(amountOut > 0 && msg.value > 0, "Invalid amounts");
        amounts = new uint[](path.length);
        amounts[0] = msg.value;
        amounts[1] = amountOut;
        IERC20(path[1]).transfer(to, amountOut);
    }

    function factory() external pure override returns (address) { return address(0); }
    function WETH() external pure override returns (address) { return address(0); }
    function removeLiquidity(address tokenA, address tokenB, uint liquidity, uint amountAMin, uint amountBMin, address to, uint deadline) external override returns (uint amountA, uint amountB) { return (0, 0); }
    function removeLiquidityETH(address token, uint liquidity, uint amountTokenMin, uint amountETHMin, address to, uint deadline) external override returns (uint amountToken, uint amountETH) { return (0, 0); }
    function removeLiquidityWithPermit(address tokenA, address tokenB, uint liquidity, uint amountAMin, uint amountBMin, address to, uint deadline, bool approveMax, uint8 v, bytes32 r, bytes32 s) external override returns (uint amountA, uint amountB) { return (0, 0); }
    function removeLiquidityETHWithPermit(address token, uint liquidity, uint amountTokenMin, uint amountETHMin, address to, uint deadline, bool approveMax, uint8 v, bytes32 r, bytes32 s) external override returns (uint amountToken, uint amountETH) { return (0, 0); }
    function quote(uint amountA, uint reserveA, uint reserveB) external pure override returns (uint amountB) { return 0; }
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure override returns (uint amountOut) { return 0; }
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure override returns (uint amountIn) { return 0; }
    function getAmountsIn(uint amountOut, address[] memory path) external view override returns (uint[] memory amounts) { amounts = new uint[](path.length); amounts[0] = amountOut * 2; amounts[1] = amountOut; }
    function removeLiquidityETHSupportingFeeOnTransferTokens(address token, uint liquidity, uint amountTokenMin, uint amountETHMin, address to, uint deadline) external override returns (uint amountETH) { return 0; }
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(address token, uint liquidity, uint amountTokenMin, uint amountETHMin, address to, uint deadline, bool approveMax, uint8 v, bytes32 r, bytes32 s) external override returns (uint amountETH) { return 0; }
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external override {}
    function swapExactETHForTokensSupportingFeeOnTransferTokens(uint amountOutMin, address[] calldata path, address to, uint deadline) external payable override {}
    function swapExactTokensForETHSupportingFeeOnTransferTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external override {}
}
