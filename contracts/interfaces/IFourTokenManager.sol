// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IFourTokenManager {
    struct TokenInfo {
        address base;
        address quote;
        uint256 template;
        uint256 totalSupply;
        uint256 maxOffers;
        uint256 maxRaising;
        uint256 launchTime;
        uint256 offers;
        uint256 funds;
        uint256 lastPrice;
        uint256 K;
        uint256 T;
        uint256 statu;
    }

    function purchaseTokenAMAP(address token, uint256 funds, uint256 minAmount) external payable;

    function purchaseTokenAMAP(uint256 origin, address token, address to, uint256 funds, uint256 minAmount) external payable;

    function buyTokenAMAP(address token, address to, uint256 funds, uint256 minAmount) external payable;

    function buyToken(address token, uint256 amount, uint256 maxFunds) external payable;

    function buyToken(address token, address to, uint256 amount, uint256 maxFunds) external payable;

    function buyToken(bytes memory args, uint256 time, bytes memory signature) external payable;

    function sellToken(address token, uint256 amount) external;

    function sellToken(uint256 origin, address token, uint256 amount, uint256 minFunds, uint256 feeRate, address feeRecipient) external;

    function sellToken(uint256 origin, address token, address from, uint256 amount, uint256 minFunds, uint256 feeRate, address feeRecipient) external;

    function saleToken(address token, uint256 amount) external;

    function purchaseToken(address token, uint256 amount, uint256 maxFunds) external payable;

    function purchaseToken(uint256 origin, address token, address to, uint256 amount, uint256 maxFunds) external payable;

    function _tokenInfos(address token) external view returns (TokenInfo memory tokenInfo);
}
