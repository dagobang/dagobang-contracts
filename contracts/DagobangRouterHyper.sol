// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {IWNative} from "./interfaces/IWNative.sol";
import {IHyperBonding} from "./interfaces/IHyperBonding.sol";
import {IUniswapV3Factory} from "./interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "./interfaces/IUniswapV3Pool.sol";
import {IUniswapV3SwapCallback} from "./interfaces/IUniswapV3SwapCallback.sol";

import {V3SwapLib} from "./swaplib/V3SwapLib.sol";
import {V2SwapLib} from "./swaplib/V2SwapLib.sol";
import {HyperZapSwapLib} from "./swaplib/HyperZapSwapLib.sol";

contract DagobangRouterHyper is Initializable, OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable, IUniswapV3SwapCallback {
  using SafeERC20 for IERC20;

  uint16 public constant FEE_DENOMINATOR = 10_000;

  address public wNative;
  address public hyperZap;
  address public hyperBonding;
  address public hyperUsdc;
  address public feeCollector;
  uint16 public feeBps;
  mapping(address => bool) public feeExempt;
  uint256 public feeThreshold;
  address public v3Factory;

  event FeeCollectorUpdated(address indexed feeCollector);
  event FeeBpsUpdated(uint16 feeBps);
  event FeeExemptUpdated(address indexed account, bool isExempt);
  event WNativeUpdated(address indexed wNative);
  event V3FactoryUpdated(address indexed v3Factory);
  event HyperZapUpdated(address indexed hyperZap);
  event HyperBondingUpdated(address indexed hyperBonding);
  event HyperUsdcUpdated(address indexed hyperUsdc);
  event FeeCollected(address indexed payer, address indexed token, uint256 amount);

  enum SwapType {
    V2_EXACT_IN,
    V3_EXACT_IN,
    V4_EXACT_IN,
    HYPER_ZAP_BUY,
    HYPER_ZAP_SELL
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

  function initialize(address owner_, address wNative_, address hyperZap_, address hyperBonding_, address hyperUsdc_)
    external
    initializer
  {
    __Ownable_init(owner_);
    __Pausable_init();
    __ReentrancyGuard_init();

    wNative = wNative_;
    hyperZap = hyperZap_;
    hyperBonding = hyperBonding_;
    hyperUsdc = hyperUsdc_;
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

  function setHyperZap(address hyperZap_) external onlyOwner {
    hyperZap = hyperZap_;
    emit HyperZapUpdated(hyperZap_);
  }

  function setHyperBonding(address hyperBonding_) external onlyOwner {
    hyperBonding = hyperBonding_;
    emit HyperBondingUpdated(hyperBonding_);
  }

  function setHyperUsdc(address hyperUsdc_) external onlyOwner {
    hyperUsdc = hyperUsdc_;
    emit HyperUsdcUpdated(hyperUsdc_);
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

  function setFeeThreshold(uint256 feeThreshold_) external onlyOwner {
    feeThreshold = feeThreshold_;
  }

  function swap(SwapDesc[] calldata descs, address feeToken, uint256 amountIn, uint256 minReturn, uint256 deadline)
    external
    payable
    nonReentrant
    whenNotPaused
    checkDeadline(deadline)
  {
    require(descs.length > 0, "ED");
    require(feeToken == address(0), "IFT");
    require(amountIn > 0, "ZI");

    address payerOrigin = msg.sender;
    address tokenIn = descs[0].tokenIn;
    address tokenOut = descs[descs.length - 1].tokenOut;

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

  function swapPercent(SwapDesc[] calldata descs, address feeToken, uint16 percentBps, uint256 minReturn, uint256 deadline)
    external
    payable
    nonReentrant
    whenNotPaused
    checkDeadline(deadline)
  {
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

    if (desc.swapType == SwapType.V2_EXACT_IN) {
      address tokenIn = _wrapToken(desc.tokenIn);
      address tokenOut = _wrapToken(desc.tokenOut);
      if (_isNative(desc.tokenIn)) {
        IWNative(wNative).deposit{value: amountIn}();
      }
      return V2SwapLib.exactIn(desc.poolAddress, tokenIn, tokenOut, desc.fee, amountIn, address(this));
    }

    if (desc.swapType == SwapType.V3_EXACT_IN) {
      address vf = v3Factory;
      require(vf != address(0), "V3_NC");
      address tokenIn2 = _wrapToken(desc.tokenIn);
      address tokenOut2 = _wrapToken(desc.tokenOut);
      if (_isNative(desc.tokenIn)) {
        IWNative(wNative).deposit{value: amountIn}();
      }
      return V3SwapLib.exactIn(vf, tokenIn2, tokenOut2, desc.fee, desc.poolAddress, amountIn, address(this));
    }

    if (desc.swapType == SwapType.V4_EXACT_IN) {
      revert("V4_NS");
    }

    if (desc.swapType == SwapType.HYPER_ZAP_BUY) {
      address zap = hyperZap;
      address usdc = hyperUsdc;
      require(zap != address(0) && usdc != address(0), "HZ_NC");
      require(desc.tokenIn == usdc, "HZ_BUY_IN");
      require(!_isNative(desc.tokenOut), "HZ_BUY_OUT");
      _requireHyperTradableToken(desc.tokenOut);
      return HyperZapSwapLib.buy(zap, usdc, desc.tokenOut, amountIn, desc.data);
    }

    if (desc.swapType == SwapType.HYPER_ZAP_SELL) {
      address zap = hyperZap;
      address usdc = hyperUsdc;
      require(zap != address(0) && usdc != address(0), "HZ_NC");
      require(!_isNative(desc.tokenIn), "HZ_SELL_IN");
      require(desc.tokenOut == usdc, "HZ_SELL_OUT");
      _requireHyperTradableToken(desc.tokenIn);
      return HyperZapSwapLib.sell(zap, desc.tokenIn, amountIn, desc.data);
    }

    revert("IST");
  }

  function _requireHyperTradableToken(address token) internal view {
    address bonding = hyperBonding;
    require(bonding != address(0), "HB_NC");
    require(IHyperBonding(bonding).creatorOf(token) != address(0), "HZ_IT");
    require(!IHyperBonding(bonding).isGraduating(token), "HZ_GRD");
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
    _v3SwapCallback(amount0Delta, amount1Delta, data);
  }

  function pancakeV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
    _v3SwapCallback(amount0Delta, amount1Delta, data);
  }

  function hyperswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
    _v3SwapCallback(amount0Delta, amount1Delta, data);
  }

  function _v3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) internal {
    require(amount0Delta > 0 || amount1Delta > 0, "ND");
    address vf = v3Factory;
    require(vf != address(0), "V3_NC");
    (address tokenIn, address tokenOut, uint24 fee, address payer, address factory) = abi.decode(data, (address, address, uint24, address, address));
    require(factory == vf, "UF");
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
