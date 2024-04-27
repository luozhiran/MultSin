// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6;

interface ITrader {
  function isTrader(address sender) external view returns(bool);
}