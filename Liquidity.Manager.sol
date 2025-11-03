// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";


contract LiquidityManager is Ownable { 

   using SafeERC20 for IERC20;
    address public router;
    address public PXL;
    address public USDT;
    address public WETH;

     event RouterUpdated(address prev, address next);
    event TokenUpdated(string which, address prev, address next);
    event LiquidityAddedUSDT(uint256 amountPXL, uint256 amountUSDT, uint256 lp);
    event LiquidityAddedETH(uint256 amountPXL, uint256 amountETH, uint256 lp);
    event SwappedTokens(address fromToken, address toToken, uint256 inAmount, uint256 outAmount, address to);


    constructor(address _router, address _pxl, address _usdt, address _weth) {
        require(_router != address(0), "LiquidityManager: zero router");
        require(_pxl != address(0), "LiquidityManager: zero PXL");
        require(_usdt != address(0), "LiquidityManager: zero USDT");
        require(_weth != address(0), "LiquidityManager: zero WETH");
        router = _router;
        PXL = _pxl;
        USDT = _usdt;
        WETH = _weth;
    }

        function setRouter(address _router) external onlyOwner {
        require(_router != address(0), "LiquidityManager: zero router");
        emit RouterUpdated(router, _router);
        router = _router;
    }

        function setPXL(address _pxl) external onlyOwner {
        require(_pxl != address(0), "LiquidityManager: zero PXL");
        emit TokenUpdated("PXL", PXL, _pxl);
        PXL = _pxl;
    }

        function setUSDT(address _usdt) external onlyOwner {
        require(_usdt != address(0), "LiquidityManager: zero USDT");
        emit TokenUpdated("USDT", USDT, _usdt);
        USDT = _usdt;
    }

    function setWETH(address _weth) external onlyOwner {
        require(_weth != address(0), "LiquidityManager: zero WETH");
        emit TokenUpdated("WETH", WETH, _weth);
        WETH = _weth;
    }
        function addLiquidityUSDT(
        uint256 pxlAmount,
        uint256 usdtAmount,
        uint256 pxlMin,
        uint256 usdtMin,
        uint256 deadline
    ) external onlyOwner {
        IERC20(PXL).safeIncreaseAllowance(router, pxlAmount);
        IERC20(USDT).safeIncreaseAllowance(router, usdtAmount);
        IUniswapV2Router02 _router = IUniswapV2Router02(router);
        address[] memory path = new address[](2);
        path[0] = PXL;
        path[1] = USDT;
        (uint256 amountA, uint256 amountB, uint256 liquidity) = _router.addLiquidity(
            PXL, USDT, pxlAmount, usdtAmount, pxlMin, usdtMin, address(this), deadline
        );
        emit LiquidityAddedUSDT(pxlAmount, usdtAmount, liquidity);
    }

    function addLiquidityETH(
        uint256 pxlAmountDesired,
        uint256 pxlAmountMin,
        uint256 ethAmountMin,
        uint256 deadline
    ) external payable onlyOwner {
        require(msg.value > 0, "LiquidityManager: zero ETH");
        IERC20(PXL).safeIncreaseAllowance(router, pxlAmountDesired);
        IUniswapV2Router02 _router = IUniswapV2Router02(router);
        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = _router.addLiquidityETH{value: msg.value}(
            PXL, pxlAmountDesired, pxlAmountMin, ethAmountMin, address(this), deadline
        );
        emit LiquidityAddedETH(pxlAmountDesired, msg.value, liquidity);
    }

    function swapUSDTforPXL(
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline,
        address to
    ) external onlyOwner {
        IUniswapV2Router02 _router = IUniswapV2Router02(router);
        address[] memory path = new address[](2);
        path[0] = USDT;
        path[1] = PXL;
        IERC20(USDT).safeIncreaseAllowance(router, amountIn);
        uint256[] memory amounts = _router.getAmountsOut(amountIn, path);
        IERC20(USDT).safeTransferFrom(msg.sender, address(this), amountIn);
        _router.swapTokensForExactTokens(amounts[1], amountOutMin, path, to, deadline);
        emit SwappedTokens(USDT, PXL, amountIn, amounts[1], to);
    }

    function swapPXLforUSDT(
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline,
        address to
    ) external onlyOwner {
        IUniswapV2Router02 _router = IUniswapV2Router02(router);
        address[] memory path = new address[](2);
        path[0] = PXL;
        path[1] = USDT;
        IERC20(PXL).safeIncreaseAllowance(router, amountIn);
        uint256[] memory amounts = _router.getAmountsOut(amountIn, path);
        IERC20(PXL).safeTransferFrom(msg.sender, address(this), amountIn);
        _router.swapTokensForExactTokens(amounts[1], amountOutMin, path, to, deadline);
        emit SwappedTokens(PXL, USDT, amountIn, amounts[1], to);
    }

    function swapETHforPXL(
        uint256 amountOutMin,
        uint256 deadline,
        address to
    ) external payable onlyOwner {
        require(msg.value > 0, "LiquidityManager: zero ETH");
        IUniswapV2Router02 _router = IUniswapV2Router02(router);
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = PXL;
        uint256[] memory amounts = _router.getAmountsOut(msg.value, path);
        _router.swapETHForExactTokens{value: msg.value}(amountOutMin, path, to, deadline);
        emit SwappedTokens(address(0), PXL, msg.value, amounts[1], to);
    }

    function swapPXLforETH(
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline,
        address to
    ) external onlyOwner {
        IUniswapV2Router02 _router = IUniswapV2Router02(router);
        address[] memory path = new address[](2);
        path[0] = PXL;
        path[1] = WETH;
        IERC20(PXL).safeIncreaseAllowance(router, amountIn);
        uint256[] memory amounts = _router.getAmountsOut(amountIn, path);
        IERC20(PXL).safeTransferFrom(msg.sender, address(this), amountIn);
        _router.swapTokensForExactETH(amountIn, amountOutMin, path, to, deadline);
        emit SwappedTokens(PXL, address(0), amountIn, amounts[1], to);
    }

    receive() external payable {}


}