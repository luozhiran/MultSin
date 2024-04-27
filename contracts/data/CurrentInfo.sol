// SPDX-License-Identifier: MIT
pragma solidity >=0.7.5;

  struct CurrentInfo {
        address traderPeople;
        uint8 approvalThresholdCount;
        mapping(uint => mapping(address => bool)) eachOwnerApprovalResultMap;
        uint[] activeTransactionArray;
        uint activeTransactionCount;
    }