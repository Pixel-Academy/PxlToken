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


contract LiquidityManagerTest is Test {
    LiquidityManager manager;
    MockUniswapV2Router router;
    MockERC20 pxl;
    MockERC20 usdt;
    MockERC20 weth;
    address owner = address(this);
    address alice = address(0x1);

    function setUp() public {
        router = new MockUniswapV2Router();
        pxl = new MockERC20("PXL", "PXL");
        usdt = new MockERC20("USDT", "USDT");
        weth = new MockERC20("WETH", "WETH");

        manager = new LiquidityManager(address(router), address(pxl), address(usdt), address(weth));

        pxl.transfer(address(manager), 100_000 ether);
        usdt.transfer(address(manager), 100_000 ether);
        weth.transfer(address(manager), 100_000 ether);
        usdt.transfer(owner, 100_000 ether);

        pxl.transfer(address(router), 100_000 ether);
        usdt.transfer(address(router), 100_000 ether);
        weth.transfer(address(router), 100_000 ether);

        pxl.approve(address(manager), 100_000 ether);
        usdt.approve(address(manager), 100_000 ether);
        weth.approve(address(manager), 100_000 ether);

        vm.startPrank(address(manager));
        pxl.approve(address(router), 100_000 ether);
        usdt.approve(address(router), 100_000 ether);
        weth.approve(address(router), 100_000 ether);
        vm.stopPrank();

        vm.prank(owner);
        usdt.approve(address(manager), 100_000 ether);
    }

    function test_Constructor() public {
        assertEq(manager.router(), address(router), "Router mismatch");
        assertEq(manager.PXL(), address(pxl), "PXL mismatch");
        assertEq(manager.USDT(), address(usdt), "USDT mismatch");
        assertEq(manager.WETH(), address(weth), "WETH mismatch");
        assertEq(manager.owner(), owner, "Owner mismatch");
    }

    function test_RevertWhen_ConstructorZeroRouter() public {
        vm.expectRevert("LiquidityManager: zero router");
        new LiquidityManager(address(0), address(pxl), address(usdt), address(weth));
    }

    function test_SetRouter() public {
        address newRouter = address(0x2);
        vm.expectEmit(true, true, false, false, address(manager));
        emit LiquidityManager.RouterUpdated(address(router), newRouter);
        manager.setRouter(newRouter);
        assertEq(manager.router(), newRouter, "Router not updated");
    }

    function test_RevertWhen_SetRouterNonOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        manager.setRouter(address(0x2));
    }

    function test_RevertWhen_SetRouterZero() public {
        vm.expectRevert("LiquidityManager: zero router");
        manager.setRouter(address(0));
    }

    function test_SetPXL() public {
        address newPXL = address(0x3);
        vm.expectEmit(true, true, true, false, address(manager));
        emit LiquidityManager.TokenUpdated("PXL", address(pxl), newPXL);
        manager.setPXL(newPXL);
        assertEq(manager.PXL(), newPXL, "PXL not updated");
    }

    function test_AddLiquidityUSDT() public {
        uint256 pxlAmount = 1000 ether;
        uint256 usdtAmount = 1000 ether;
        uint256 pxlMin = 900 ether;
        uint256 usdtMin = 900 ether;
        uint256 deadline = block.timestamp + 1 hours;

        vm.recordLogs();
        manager.addLiquidityUSDT(pxlAmount, usdtAmount, pxlMin, usdtMin, deadline);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 expectedTopic = keccak256("LiquidityAddedUSDT(uint256,uint256,uint256)");
        bool foundEvent = false;
        for (uint i = 0; i < logs.length; i++) {
            console.log("Event", i, "topic0:", uint256(logs[i].topics[0]));
            if (logs[i].topics[0] == expectedTopic) {
                foundEvent = true;
                (uint256 emittedPxl, uint256 emittedUsdt, uint256 emittedLiquidity) = abi.decode(logs[i].data, (uint256, uint256, uint256));
                console.log("Emitted LiquidityAddedUSDT:", emittedPxl, emittedUsdt, emittedLiquidity);
                assertEq(emittedPxl, pxlAmount, "PXL amount mismatch");
                assertEq(emittedUsdt, usdtAmount, "USDT amount mismatch");
                assertEq(emittedLiquidity, 1000 ether, "Liquidity amount mismatch");
                break;
            }
        }
        assertTrue(foundEvent, "LiquidityAddedUSDT event not found");
    }

    function test_RevertWhen_AddLiquidityUSDTNonOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        manager.addLiquidityUSDT(1000 ether, 1000 ether, 900 ether, 900 ether, block.timestamp + 1 hours);
    }

    function test_AddLiquidityETH() public {
        uint256 pxlAmount = 1000 ether;
        uint256 pxlMin = 900 ether;
        uint256 ethMin = 0.9 ether;
        uint256 deadline = block.timestamp + 1 hours;

        vm.deal(owner, 1 ether);
        vm.recordLogs();
        manager.addLiquidityETH{value: 1 ether}(pxlAmount, pxlMin, ethMin, deadline);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 expectedTopic = keccak256("LiquidityAddedETH(uint256,uint256,uint256)");
        bool foundEvent = false;
        for (uint i = 0; i < logs.length; i++) {
            console.log("Event", i, "topic0:", uint256(logs[i].topics[0]));
            if (logs[i].topics[0] == expectedTopic) {
                foundEvent = true;
                (uint256 emittedPxl, uint256 emittedEth, uint256 emittedLiquidity) = abi.decode(logs[i].data, (uint256, uint256, uint256));
                console.log("Emitted LiquidityAddedETH:", emittedPxl, emittedEth, emittedLiquidity);
                assertEq(emittedPxl, pxlAmount, "PXL amount mismatch");
                assertEq(emittedEth, 1 ether, "ETH amount mismatch");
                assertEq(emittedLiquidity, 1000 ether, "Liquidity amount mismatch");
                break;
            }
        }
        assertTrue(foundEvent, "LiquidityAddedETH event not found");
    }

    function test_RevertWhen_AddLiquidityETHZeroETH() public {
        vm.expectRevert("LiquidityManager: zero ETH");
        manager.addLiquidityETH{value: 0}(1000 ether, 900 ether, 0.9 ether, block.timestamp + 1 hours);
    }

    function test_SwapUSDTforPXL() public {
        uint256 amountIn = 1000 ether;
        uint256 amountOutMin = 500 ether;
        uint256 deadline = block.timestamp + 1 hours;
        address to = alice;

        vm.startPrank(owner);
        usdt.approve(address(manager), amountIn);
        vm.recordLogs();
        manager.swapUSDTforPXL(amountIn, amountOutMin, deadline, to);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 expectedTopic = keccak256("SwappedTokens(address,address,uint256,uint256,address)");
        bool foundEvent = false;
        for (uint i = 0; i < logs.length; i++) {
            console.log("Event", i, "topic0:", uint256(logs[i].topics[0]));
            if (logs[i].topics[0] == expectedTopic) {
                foundEvent = true;
                (address emittedFrom, address emittedTo, uint256 emittedIn, uint256 emittedOut, address emittedReceiver) = abi.decode(logs[i].data, (address, address, uint256, uint256, address));
                console.log("Emitted SwappedTokens:", emittedIn, emittedOut);
                assertEq(emittedFrom, address(usdt), "From token mismatch");
                assertEq(emittedTo, address(pxl), "To token mismatch");
                assertEq(emittedIn, amountIn, "Input amount mismatch");
                assertEq(emittedOut, 500 ether, "Output amount mismatch");
                assertEq(emittedReceiver, to, "Receiver mismatch");
                break;
            }
        }
        assertTrue(foundEvent, "SwappedTokens event not found");
        vm.stopPrank();
    }

    function test_RevertWhen_SwapUSDTforPXLNoApproval() public {
        uint256 amountIn = 1000 ether;
        uint256 amountOutMin = 500 ether;
        uint256 deadline = block.timestamp + 1 hours;
        address to = alice;

        vm.prank(owner);
        console.log("Owner USDT balance:", usdt.balanceOf(owner));
        console.log("Owner USDT allowance:", usdt.allowance(owner, address(manager)));
        usdt.approve(address(manager), 0);
        vm.expectRevert("ERC20: insufficient allowance");
        manager.swapUSDTforPXL(amountIn, amountOutMin, deadline, to);
    }
}