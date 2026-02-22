// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {IWNative} from "./interfaces/IWNative.sol";
import {IUniswapV3Factory} from "./interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "./interfaces/IUniswapV3Pool.sol";
import {IUniswapV3SwapCallback} from "./interfaces/IUniswapV3SwapCallback.sol";
import {IPancakeV3SwapCallback} from "./interfaces/IPancakeV3SwapCallback.sol";
import {IV4PoolManager} from "./interfaces/IV4PoolManager.sol";
import {IPancakeInfinityVault} from "./interfaces/IPancakeInfinityVault.sol";

import {V3SwapLib} from "./swaplib/V3SwapLib.sol";
import {V2SwapLib} from "./swaplib/V2SwapLib.sol";
import {V4SwapLib} from "./swaplib/V4SwapLib.sol";
import {PancakeInfinitySwapLib} from "./swaplib/PancakeInfinitySwapLib.sol";
import {IFourTokenManager} from "./interfaces/IFourTokenManager.sol";
import {FourMemeSwapLib} from "./swaplib/FourMemeSwapLib.sol";
import {FlapSwapLib} from "./swaplib/FlapSwapLib.sol";
import {LunaSwapLib} from "./swaplib/LunaSwapLib.sol";

contract DagobangRouter is Initializable, OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable, IUniswapV3SwapCallback, IPancakeV3SwapCallback {
    using SafeERC20 for IERC20;

    uint16 public constant FEE_DENOMINATOR = 10_000;

    address public wNative;
    address public v3Factory;
    address public lunaLaunchpad;
    address public lunaRouter;
    address public feeCollector;
    uint16 public feeBps;
    mapping(address => bool) public feeExempt;
    address public v4PoolManager;
    address public pancakeInfinityVault;
    address public pancakeInfinityClPoolManager;
    address public pancakeInfinityBinPoolManager;

    event FeeCollectorUpdated(address indexed feeCollector);
    event FeeBpsUpdated(uint16 feeBps);
    event FeeExemptUpdated(address indexed account, bool isExempt);
    event V3FactoryUpdated(address indexed v3Factory);
    event WNativeUpdated(address indexed wNative);
    event LunaLaunchpadUpdated(address indexed lunaLaunchpad);
    event LunaRouterUpdated(address indexed lunaRouter);
    event V4PoolManagerUpdated(address indexed v4PoolManager);
    event PancakeInfinityVaultUpdated(address indexed pancakeInfinityVault);
    event PancakeInfinityClPoolManagerUpdated(address indexed pancakeInfinityClPoolManager);
    event PancakeInfinityBinPoolManagerUpdated(address indexed pancakeInfinityBinPoolManager);

    event FeeCollected(address indexed payer, address indexed token, uint256 amount);

    enum SwapType {
        V2_EXACT_IN,
        V3_EXACT_IN,
        V4_EXACT_IN,
        PANCAKE_INFINITY_EXACT_IN,
        LUNA_LAUNCHPAD_V2,
        FOUR_MEME_BUY_AMAP,
        FOUR_MEME_SELL,
        FLAP_EXACT_INPUT
    }

    struct SwapDesc {
        SwapType swapType;
        address tokenIn;
        address tokenOut;
        address poolAddress;
        uint24 fee;
        int24 tickSpacing;
        address hooks;
        bytes hookData;
        address poolManager;
        bytes32 parameters;
        bytes data;
    }

    event Swap(address indexed payer, address indexed receiver, address indexed feeToken, uint256 amountIn, uint256 amountOut, SwapDesc[] descs);

    modifier checkDeadline(uint256 deadline) {
        require(block.timestamp <= deadline, "DEADLINE_EXPIRED");
        _;
    }

    receive() external payable {}

    function initialize(address owner_, address wNative_, address v3Factory_) external initializer {
        __Ownable_init(owner_);
        __Pausable_init();
        __ReentrancyGuard_init();

        wNative = wNative_;
        v3Factory = v3Factory_;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setWNative(address wNative_) external onlyOwner {
        wNative = wNative_;
        emit WNativeUpdated(wNative_);
    }

    function setV3Factory(address v3Factory_) external onlyOwner {
        v3Factory = v3Factory_;
        emit V3FactoryUpdated(v3Factory_);
    }

    function setLunaLaunchpad(address lunaLaunchpad_) external onlyOwner {
        lunaLaunchpad = lunaLaunchpad_;
        emit LunaLaunchpadUpdated(lunaLaunchpad_);
    }

    function setLunaRouter(address lunaRouter_) external onlyOwner {
        lunaRouter = lunaRouter_;
        emit LunaRouterUpdated(lunaRouter_);
    }

    function setV4PoolManager(address v4PoolManager_) external onlyOwner {
        v4PoolManager = v4PoolManager_;
        emit V4PoolManagerUpdated(v4PoolManager_);
    }

    function setPancakeInfinityVault(address pancakeInfinityVault_) external onlyOwner {
        pancakeInfinityVault = pancakeInfinityVault_;
        emit PancakeInfinityVaultUpdated(pancakeInfinityVault_);
    }

    function setPancakeInfinityClPoolManager(address pancakeInfinityClPoolManager_) external onlyOwner {
        pancakeInfinityClPoolManager = pancakeInfinityClPoolManager_;
        emit PancakeInfinityClPoolManagerUpdated(pancakeInfinityClPoolManager_);
    }

    function setPancakeInfinityBinPoolManager(address pancakeInfinityBinPoolManager_) external onlyOwner {
        pancakeInfinityBinPoolManager = pancakeInfinityBinPoolManager_;
        emit PancakeInfinityBinPoolManagerUpdated(pancakeInfinityBinPoolManager_);
    }

    function setFeeCollector(address feeCollector_) external onlyOwner {
        feeCollector = feeCollector_;
        emit FeeCollectorUpdated(feeCollector_);
    }

    function setFeeBps(uint16 feeBps_) external onlyOwner {
        require(feeBps_ <= FEE_DENOMINATOR, "FEE_TOO_HIGH");
        feeBps = feeBps_;
        emit FeeBpsUpdated(feeBps_);
    }

    function setFeeExempt(address account, bool isExempt) external onlyOwner {
        feeExempt[account] = isExempt;
        emit FeeExemptUpdated(account, isExempt);
    }

    function swap(
        SwapDesc[] calldata descs,
        address feeToken,
        uint256 amountIn,
        uint256 minReturn,
        uint256 deadline
    ) external payable nonReentrant whenNotPaused checkDeadline(deadline) {
        require(descs.length > 0, "EMPTY_DESCS");
        require(feeToken == address(0), "INVALID_FEE_TOKEN");
        require(amountIn > 0, "ZERO_INPUT");

        address payerOrigin = msg.sender;
        address tokenIn = descs[0].tokenIn;
        SwapDesc calldata lastDesc = descs[descs.length - 1];
        address tokenOut = lastDesc.tokenOut;

        uint256 fee = 0;
        if (_isNative(tokenIn)) {
            require(msg.value >= amountIn, "VALUE_MISMATCH");
            fee = _takeNativeFee(payerOrigin, amountIn);
            amountIn -= fee;
        } else {
            require(msg.value == 0, "UNEXPECTED_VALUE");
            if (descs[0].swapType == SwapType.FOUR_MEME_SELL) {
                bool isV2 = _fourMemeIsV2(descs[0].poolAddress, tokenIn);
                if (!isV2) {
                    IERC20(tokenIn).safeTransferFrom(payerOrigin, address(this), amountIn);
                }
            } else {
                IERC20(tokenIn).safeTransferFrom(payerOrigin, address(this), amountIn);
            }
        }

        uint256 currentAmountIn = amountIn;
        for (uint256 i = 0; i < descs.length; i++) {
            currentAmountIn = _executeSwap(descs, i, currentAmountIn, payerOrigin);
        }

        if (lastDesc.swapType == SwapType.FOUR_MEME_BUY_AMAP) {
            require(!_isNative(tokenOut), "FOUR_MEME_NATIVE_OUT");
            require(currentAmountIn >= minReturn, "MIN_RETURN");
        } else {
            if (_isNative(tokenOut)) {
                IWNative(wNative).withdraw(currentAmountIn);
                fee = _takeNativeFee(payerOrigin, currentAmountIn);
                uint256 netOut = currentAmountIn - fee;
                require(netOut >= minReturn, "MIN_RETURN");
                (bool ok, ) = payerOrigin.call{value: netOut}("");
                require(ok, "NATIVE_TRANSFER_FAILED");
            } else {
                require(currentAmountIn >= minReturn, "MIN_RETURN");
                IERC20(tokenOut).safeTransfer(payerOrigin, currentAmountIn);
            }
        }
        emit Swap(payerOrigin, payerOrigin, feeToken, amountIn, currentAmountIn, _toMemory(descs));
    }

    // Swaps a percentage of the caller's ERC20 tokenIn balance using the given route.
    // Native token as input is not supported; amountIn is derived from current balance.
    function swapPercent(
        SwapDesc[] calldata descs,
        address feeToken,
        uint16 percentBps,
        uint256 minReturn,
        uint256 deadline
    ) external payable nonReentrant whenNotPaused checkDeadline(deadline) {
        require(descs.length > 0, "EMPTY_DESCS");
        require(feeToken == address(0), "INVALID_FEE_TOKEN");
        require(percentBps > 0 && percentBps <= FEE_DENOMINATOR, "INVALID_PERCENT");

        address payerOrigin = msg.sender;
        address tokenIn = descs[0].tokenIn;
        require(!_isNative(tokenIn), "NATIVE_NOT_SUPPORTED");
        require(msg.value == 0, "UNEXPECTED_VALUE");

        uint256 balance = IERC20(tokenIn).balanceOf(payerOrigin);
        uint256 amountIn = (balance * percentBps) / FEE_DENOMINATOR;
        if (percentBps != FEE_DENOMINATOR && amountIn > 0 && descs[0].swapType == SwapType.FOUR_MEME_SELL) {
            bool isV2 = _fourMemeIsV2(descs[0].poolAddress, tokenIn);
            if (isV2) {
                amountIn = (amountIn / 1e9) * 1e9;
            }
        }
        require(amountIn > 0, "ZERO_INPUT");

        SwapDesc calldata lastDesc = descs[descs.length - 1];
        address tokenOut = lastDesc.tokenOut;

        uint256 currentAmountIn = amountIn;
        if (descs[0].swapType == SwapType.FOUR_MEME_SELL) {
            bool isV2 = _fourMemeIsV2(descs[0].poolAddress, tokenIn);
            if (!isV2) {
                uint256 beforeBal = IERC20(tokenIn).balanceOf(address(this));
                IERC20(tokenIn).safeTransferFrom(payerOrigin, address(this), amountIn);
                uint256 afterBal = IERC20(tokenIn).balanceOf(address(this));
                currentAmountIn = afterBal - beforeBal;
            }
        } else {
            uint256 beforeBal = IERC20(tokenIn).balanceOf(address(this));
            IERC20(tokenIn).safeTransferFrom(payerOrigin, address(this), amountIn);
            uint256 afterBal = IERC20(tokenIn).balanceOf(address(this));
            currentAmountIn = afterBal - beforeBal;
        }

        for (uint256 i = 0; i < descs.length; i++) {
            currentAmountIn = _executeSwap(descs, i, currentAmountIn, payerOrigin);
        }

        if (lastDesc.swapType == SwapType.FOUR_MEME_BUY_AMAP) {
            require(!_isNative(tokenOut), "FOUR_MEME_NATIVE_OUT");
            require(currentAmountIn >= minReturn, "MIN_RETURN");
        } else {
            if (_isNative(tokenOut)) {
                IWNative(wNative).withdraw(currentAmountIn);
                uint256 fee = _takeNativeFee(payerOrigin, currentAmountIn);
                uint256 netOut = currentAmountIn - fee;
                require(netOut >= minReturn, "MIN_RETURN");
                (bool ok, ) = payerOrigin.call{value: netOut}("");
                require(ok, "NATIVE_TRANSFER_FAILED");
            } else {
                require(currentAmountIn >= minReturn, "MIN_RETURN");
                IERC20(tokenOut).safeTransfer(payerOrigin, currentAmountIn);
            }
        }

        emit Swap(payerOrigin, payerOrigin, feeToken, amountIn, currentAmountIn, _toMemory(descs));
    }

    function _executeSwap(SwapDesc[] calldata descs, uint256 i, uint256 amountIn, address payerOrigin) internal returns (uint256 amountOut) {
        SwapDesc calldata desc = descs[i];

        if (desc.swapType == SwapType.V3_EXACT_IN) {
            require(amountIn > 0, "ZERO_INPUT");
            address tokenIn = _wrapToken(desc.tokenIn);
            address tokenOut = _wrapToken(desc.tokenOut);
            if (desc.tokenIn == address(0)) {
                IWNative(wNative).deposit{value: amountIn}();
            }
            amountOut = V3SwapLib.exactIn(v3Factory, tokenIn, tokenOut, desc.fee, desc.poolAddress, amountIn, address(this));
            return amountOut;
        }

        if (desc.swapType == SwapType.V2_EXACT_IN) {
            require(amountIn > 0, "ZERO_INPUT");
            address tokenIn = _wrapToken(desc.tokenIn);
            address tokenOut = _wrapToken(desc.tokenOut);
            if (desc.tokenIn == address(0)) {
                IWNative(wNative).deposit{value: amountIn}();
            }
            amountOut = V2SwapLib.exactIn(desc.poolAddress, tokenIn, tokenOut, desc.fee, amountIn, address(this));
            return amountOut;
        }

        if (desc.swapType == SwapType.V4_EXACT_IN) {
            address pm = v4PoolManager;
            require(pm != address(0), "V4_NOT_CONFIGURED");
            amountOut = V4SwapLib.swapExactIn(
                pm,
                wNative,
                address(this),
                payerOrigin,
                amountIn,
                desc.tokenIn,
                desc.tokenOut,
                desc.fee,
                desc.tickSpacing,
                desc.hooks,
                desc.hookData,
                address(this)
            );
            return amountOut;
        }

        if (desc.swapType == SwapType.FOUR_MEME_BUY_AMAP) {
            amountOut = FourMemeSwapLib.buy(desc.poolAddress, desc.tokenIn, desc.tokenOut, amountIn, desc.data, payerOrigin);
            return amountOut;
        }

        if (desc.swapType == SwapType.FOUR_MEME_SELL) {
            uint256 minFunds = desc.data.length > 0 ? abi.decode(desc.data, (uint256)) : 0;
            require(i == 0, "FOUR_SELL_POSITION");
            bool isV2 = _fourMemeIsV2(desc.poolAddress, desc.tokenIn);
            if (_isNative(desc.tokenOut)) {
                amountOut = FourMemeSwapLib.sellToNativeWrapped(desc.poolAddress, wNative, desc.tokenIn, amountIn, minFunds, payerOrigin, isV2);
            } else {
                amountOut = FourMemeSwapLib.sellToToken(desc.poolAddress, desc.tokenIn, desc.tokenOut, amountIn, minFunds, payerOrigin, isV2);
                if (i + 1 < descs.length) {
                    IERC20(desc.tokenOut).safeTransferFrom(payerOrigin, address(this), amountOut);
                }
            }
            return amountOut;
        }

        if (desc.swapType == SwapType.LUNA_LAUNCHPAD_V2) {
            address launchpad = lunaLaunchpad;
            address router = lunaRouter;
            require(launchpad != address(0) && router != address(0), "LUNA_NOT_CONFIGURED");
            require(desc.tokenIn == address(0) || desc.tokenOut == address(0), "LUNA_TOKEN");
            if (desc.tokenIn == address(0)) {
                amountOut = LunaSwapLib.buy(launchpad, router, wNative, desc.tokenOut, amountIn);
            } else {
                amountOut = LunaSwapLib.sell(launchpad, router, wNative, desc.tokenIn, amountIn);
            }
            return amountOut;
        }

        if (desc.swapType == SwapType.FLAP_EXACT_INPUT) {
            uint256 minOut = desc.data.length > 0 ? abi.decode(desc.data, (uint256)) : 0;
            amountOut = FlapSwapLib.exactInput(desc.poolAddress, wNative, desc.tokenIn, desc.tokenOut, amountIn, minOut);
            return amountOut;
        }

        if (desc.swapType == SwapType.PANCAKE_INFINITY_EXACT_IN) {
            address vault = pancakeInfinityVault;
            address clPm = pancakeInfinityClPoolManager;
            address binPm = pancakeInfinityBinPoolManager;
            require(vault != address(0) && clPm != address(0) && binPm != address(0), "INFINITY_NOT_CONFIGURED");
            amountOut = PancakeInfinitySwapLib.swapExactIn(
                vault,
                clPm,
                binPm,
                address(this),
                payerOrigin,
                amountIn,
                desc.tokenIn,
                desc.tokenOut,
                desc.hooks,
                desc.poolManager,
                desc.fee,
                desc.parameters,
                desc.hookData,
                address(this)
            );
            return amountOut;
        }

        revert("INVALID_SWAP_TYPE");
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        address pm = v4PoolManager;
        require(msg.sender == pm && pm != address(0), "V4_INVALID_CALLER");
        return V4SwapLib.unlockCallback(pm, wNative, data);
    }

    function lockAcquired(bytes calldata data) external returns (bytes memory) {
        address vault = pancakeInfinityVault;
        require(msg.sender == vault && vault != address(0), "INFINITY_INVALID_CALLER");
        return PancakeInfinitySwapLib.lockAcquired(vault, wNative, pancakeInfinityClPoolManager, pancakeInfinityBinPoolManager, data);
    }

    function _wrapToken(address token) internal view returns (address) {
        return token == address(0) ? wNative : token;
    }

    function _isNative(address token) internal pure returns (bool) {
        return token == address(0);
    }

    function _fourMemeIsV2(address tokenManager, address token) internal view returns (bool) {
        (bool ok, bytes memory ret) = tokenManager.staticcall(abi.encodeWithSelector(IFourTokenManager._tokenInfos.selector, token));
        return ok && ret.length > 0;
    }

    function _toMemory(SwapDesc[] calldata descs) internal pure returns (SwapDesc[] memory out) {
        out = new SwapDesc[](descs.length);
        for (uint256 i = 0; i < descs.length; i++) {
            out[i] = descs[i];
        }
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external override {
        _v3SwapCallback(amount0Delta, amount1Delta, data);
    }

    function pancakeV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external override {
        _v3SwapCallback(amount0Delta, amount1Delta, data);
    }

    function _v3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) internal {
        require(amount0Delta > 0 || amount1Delta > 0, "NO_DELTA");

        (address tokenIn, address tokenOut, uint24 fee, address payer) = abi.decode(data, (address, address, uint24, address));

        address pool = IUniswapV3Factory(v3Factory).getPool(tokenIn, tokenOut, fee);
        require(msg.sender == pool, "INVALID_POOL");

        address token0 = IUniswapV3Pool(pool).token0();
        address token1 = IUniswapV3Pool(pool).token1();

        (address payToken, uint256 payAmount) = amount0Delta > 0 ? (token0, uint256(amount0Delta)) : (token1, uint256(amount1Delta));
        require(payToken == tokenIn, "PAY_TOKEN_MISMATCH");

        if (payer == address(this)) {
            IERC20(payToken).safeTransfer(msg.sender, payAmount);
        } else {
            IERC20(payToken).safeTransferFrom(payer, msg.sender, payAmount);
        }
    }

    function _takeNativeFee(address payer, uint256 amount) internal returns (uint256 fee) {
        if (feeBps == 0 || feeExempt[payer]) {
            return 0;
        }

        fee = (amount * feeBps) / FEE_DENOMINATOR;
        if (fee == 0) {
            return 0;
        }

        address collector = feeCollector;
        require(collector != address(0), "FEE_COLLECTOR_NOT_SET");
        (bool ok, ) = collector.call{value: fee}("");
        require(ok, "FEE_TRANSFER_FAILED");
        emit FeeCollected(payer, address(0), fee);
    }
}
