// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6;

import './IIERC20.sol';

interface IWETH is IIERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}