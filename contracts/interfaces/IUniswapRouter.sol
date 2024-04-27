// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6;
pragma abicoder v2;

import "https://github.com/Uniswap/swap-router-contracts/blob/main/contracts/interfaces/ISwapRouter02.sol";

interface IUniswapRouter is ISwapRouter02 {
    function refundETH() external payable;
}