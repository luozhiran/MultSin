// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

// 创建流动性后存放结构体，存款
struct Deposit {
    address owner;
    uint128 liquidity;
    address token0;
    address token1;
}