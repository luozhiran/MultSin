// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6;

interface ITransaction {
  function transactionNotExec(uint txIndex) external view returns(bool);
  function transactionNotConfirmed(uint txIndex) external view returns(bool);
  function transactionNotExit(uint txIndex) external view returns(bool);
}