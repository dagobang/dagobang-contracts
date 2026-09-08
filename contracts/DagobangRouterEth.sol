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
import {IV4PoolManager} from "./interfaces/IV4PoolManager.sol";

import {V3SwapLib} from "./swaplib/V3SwapLib.sol";
import {V2SwapLib} from "./swaplib/V2SwapLib.sol";
import {V4SwapLib} from "./swaplib/V4SwapLib.sol";
import {OkxSwapLib} from "./swaplib/OkxSwapLib.sol";
import {TrenchSwapLib} from "./swaplib/TrenchSwapLib.sol";
import {LivoSwapLib} from "./swaplib/LivoSwapLib.sol";
import {PrintrSwapLib} from "./swaplib/PrintrSwapLib.sol";

contract DagobangRouterEth is Initializable, OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable, IUniswapV3SwapCallback {
  using SafeERC20 for IERC20;

  uint16 public constant FEE_DENOMINATOR = 10_000;

  address public wNative;
  address public v3Factory;
  address public feeCollector;
  uint16 public feeBps;
  mapping(address => bool) public feeExempt;
  uint256 public feeThreshold;
  address public v4PoolManager;

  event FeeCollectorUpdated(address indexed feeCollector);
  event FeeBpsUpdated(uint16 feeBps);
  event FeeExemptUpdated(address indexed account, bool isExempt);
  event V3FactoryUpdated(address indexed v3Factory);
  event V4PoolManagerUpdated(address indexed v4PoolManager);
  event WNativeUpdated(address indexed wNative);
  event FeeCollected(address indexed payer, address indexed token, uint256 amount);

  enum SwapType {
    V2_EXACT_IN,
    V3_EXACT_IN,
    V4_EXACT_IN,
    OKX_EXACT_IN,
    TRENCH_EXACT_IN,
    LIVO_EXACT_IN,
    PRINTR_EXACT_IN
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
    require(deadline == 0 || block.timestamp <= deadline, "DL");
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

  function setV4PoolManager(address v4PoolManager_) external onlyOwner {
    v4PoolManager = v4PoolManager_;
    emit V4PoolManagerUpdated(v4PoolManager_);
  }

  function setFeeCollector(address feeCollector_) external onlyOwner {
    feeCollector = feeCollector_;
    emit FeeCollectorUpdated(feeCollector_);
  }

  function setFeeBps(uint16 feeBps_) external onlyOwner {
    require(feeBps_ <= FEE_DENOMINATOR, "FTH");
    feeBps = feeBps_;
    emit FeeBpsUpdated(feeBps_);
  }

  function setFeeExempt(address account, bool isExempt) external onlyOwner {
    feeExempt[account] = isExempt;
    emit FeeExemptUpdated(account, isExempt);
  }

  function setFeeThreshold(uint256 fee_) external onlyOwner {
    feeThreshold = fee_;
  }

  function swap(
    SwapDesc[] calldata descs,
    address feeToken,
    uint256 amountIn,
    uint256 minReturn,
    uint256 deadline
  ) external payable nonReentrant whenNotPaused checkDeadline(deadline) {
    require(descs.length > 0, "ED");
    require(feeToken == address(0), "IFT");
    require(amountIn > 0, "ZI");

    address payerOrigin = msg.sender;
    address tokenIn = descs[0].tokenIn;
    SwapDesc calldata lastDesc = descs[descs.length - 1];
    address tokenOut = lastDesc.tokenOut;

    uint256 currentAmountIn = amountIn;
    uint256 fee = 0;
    if (_isNative(tokenIn)) {
      require(msg.value >= amountIn, "VM");
      fee = _takeNativeFee(payerOrigin, amountIn);
      amountIn -= fee;
      currentAmountIn = amountIn;
    } else {
      require(msg.value == 0, "UV");
      currentAmountIn = _pullFromAndGetDelta(tokenIn, payerOrigin, amountIn);
    }

    for (uint256 i = 0; i < descs.length; i++) {
      currentAmountIn = _executeSwap(descs[i], currentAmountIn);
    }

    if (_isNative(tokenOut)) {
      IWNative(wNative).withdraw(currentAmountIn);
      fee = _takeNativeFee(payerOrigin, currentAmountIn);
      uint256 netOut = currentAmountIn - fee;
      require(netOut >= minReturn, "MR");
      (bool ok,) = payerOrigin.call{value: netOut}("");
      require(ok, "NAT_TF");
    } else {
      require(currentAmountIn >= minReturn, "MR");
      IERC20(tokenOut).safeTransfer(payerOrigin, currentAmountIn);
    }

    emit Swap(payerOrigin, payerOrigin, feeToken, amountIn, currentAmountIn, _toMemory(descs));
  }

  function swapPercent(
    SwapDesc[] calldata descs,
    address feeToken,
    uint16 percentBps,
    uint256 minReturn,
    uint256 deadline
  ) external payable nonReentrant whenNotPaused checkDeadline(deadline) {
    require(descs.length > 0, "ED");
    require(feeToken == address(0), "IFT");
    require(percentBps > 0 && percentBps <= FEE_DENOMINATOR, "IP");
    require(msg.value == 0, "UV");

    address payerOrigin = msg.sender;
    address tokenIn = descs[0].tokenIn;
    require(!_isNative(tokenIn), "NNS");

    uint256 balance = IERC20(tokenIn).balanceOf(payerOrigin);
    uint256 amountIn = (balance * percentBps) / FEE_DENOMINATOR;
    require(amountIn > 0, "ZI");

    uint256 currentAmountIn = _pullFromAndGetDelta(tokenIn, payerOrigin, amountIn);
    for (uint256 i = 0; i < descs.length; i++) {
      currentAmountIn = _executeSwap(descs[i], currentAmountIn);
    }

    address tokenOut = descs[descs.length - 1].tokenOut;
    if (_isNative(tokenOut)) {
      IWNative(wNative).withdraw(currentAmountIn);
      uint256 fee = _takeNativeFee(payerOrigin, currentAmountIn);
      uint256 netOut = currentAmountIn - fee;
      require(netOut >= minReturn, "MR");
      (bool ok,) = payerOrigin.call{value: netOut}("");
      require(ok, "NAT_TF");
    } else {
      require(currentAmountIn >= minReturn, "MR");
      IERC20(tokenOut).safeTransfer(payerOrigin, currentAmountIn);
    }

    emit Swap(payerOrigin, payerOrigin, feeToken, amountIn, currentAmountIn, _toMemory(descs));
  }

  function _pullFromAndGetDelta(address token, address from, uint256 amountIn) internal returns (uint256 delta) {
    uint256 beforeBal = IERC20(token).balanceOf(address(this));
    IERC20(token).safeTransferFrom(from, address(this), amountIn);
    uint256 afterBal = IERC20(token).balanceOf(address(this));
    delta = afterBal - beforeBal;
  }

  function _executeSwap(SwapDesc calldata desc, uint256 amountIn) internal returns (uint256 amountOut) {
    require(amountIn > 0, "ZI");

    if (desc.swapType == SwapType.V3_EXACT_IN) {
      address tokenIn = _wrapToken(desc.tokenIn);
      address tokenOut = _wrapToken(desc.tokenOut);
      if (_isNative(desc.tokenIn)) {
        IWNative(wNative).deposit{value: amountIn}();
      }
      return V3SwapLib.exactIn(v3Factory, tokenIn, tokenOut, desc.fee, desc.poolAddress, amountIn, address(this));
    }

    if (desc.swapType == SwapType.V2_EXACT_IN) {
      address tokenIn2 = _wrapToken(desc.tokenIn);
      address tokenOut2 = _wrapToken(desc.tokenOut);
      if (_isNative(desc.tokenIn)) {
        IWNative(wNative).deposit{value: amountIn}();
      }
      return V2SwapLib.exactIn(desc.poolAddress, tokenIn2, tokenOut2, desc.fee, amountIn, address(this));
    }

    if (desc.swapType == SwapType.V4_EXACT_IN) {
      address pm = v4PoolManager;
      require(pm != address(0), "V4_NC");
      return V4SwapLib.swapExactIn(
        pm,
        wNative,
        address(this),
        msg.sender,
        amountIn,
        desc.tokenIn,
        desc.tokenOut,
        desc.fee,
        desc.tickSpacing,
        desc.hooks,
        desc.hookData,
        address(this)
      );
    }

    if (desc.swapType == SwapType.OKX_EXACT_IN) {
      return OkxSwapLib.swap(wNative, desc.poolAddress, desc.tokenIn, desc.tokenOut, amountIn, desc.hookData, address(this));
    }

    if (desc.swapType == SwapType.TRENCH_EXACT_IN) {
      return TrenchSwapLib.swap(wNative, desc.poolAddress, desc.tokenIn, desc.tokenOut, amountIn, address(this));
    }

    if (desc.swapType == SwapType.LIVO_EXACT_IN) {
      return LivoSwapLib.swap(wNative, desc.poolAddress, desc.tokenIn, desc.tokenOut, amountIn, address(this));
    }

    if (desc.swapType == SwapType.PRINTR_EXACT_IN) {
      return PrintrSwapLib.swap(wNative, desc.poolAddress, desc.tokenIn, desc.tokenOut, amountIn, address(this));
    }

    revert("IST");
  }

  function _wrapToken(address token) internal view returns (address) {
    return token == address(0) ? wNative : token;
  }

  function _isNative(address token) internal pure returns (bool) {
    return token == address(0);
  }

  function _toMemory(SwapDesc[] calldata descs) internal pure returns (SwapDesc[] memory out) {
    out = new SwapDesc[](descs.length);
    for (uint256 i = 0; i < descs.length; i++) {
      out[i] = descs[i];
    }
  }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external override {
      require(amount0Delta > 0 || amount1Delta > 0, "ND");
      (address tokenIn, address tokenOut, uint24 fee, address payer, address factory) = abi.decode(data, (address, address, uint24, address, address));
      require(factory == v3Factory, "UF");
      address pool = IUniswapV3Factory(factory).getPool(tokenIn, tokenOut, fee);
      require(msg.sender == pool, "IP");

    address token0 = IUniswapV3Pool(pool).token0();
    address token1 = IUniswapV3Pool(pool).token1();
    (address payToken, uint256 payAmount) = amount0Delta > 0 ? (token0, uint256(amount0Delta)) : (token1, uint256(amount1Delta));
    require(payToken == tokenIn, "PTM");

    if (payer == address(this)) {
      IERC20(payToken).safeTransfer(msg.sender, payAmount);
    } else {
      IERC20(payToken).safeTransferFrom(payer, msg.sender, payAmount);
    }
  }

  function unlockCallback(bytes calldata data) external returns (bytes memory) {
    address pm = v4PoolManager;
    require(msg.sender == pm && pm != address(0), "V4_IC");
    return V4SwapLib.unlockCallback(pm, wNative, data);
  }

  function _takeNativeFee(address payer, uint256 amount) internal returns (uint256 fee) {
    if (feeBps == 0 || feeExempt[payer]) return 0;
    if (amount < feeThreshold) return 0;

    fee = (amount * feeBps) / FEE_DENOMINATOR;
    if (fee == 0) return 0;

    address collector = feeCollector;
    require(collector != address(0), "FEE_NC");
    (bool ok,) = collector.call{value: fee}("");
    require(ok, "FEE_TF");
    emit FeeCollected(payer, address(0), fee);
  }
}
