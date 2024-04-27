// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6;

interface IOwner {
  function isOwner(address sender) external  view returns(bool);
}