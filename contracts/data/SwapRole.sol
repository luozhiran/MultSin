// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6;

 struct SwapRole {
        // 交换类型 1:交易员替换 2：合约onwer交换
        uint8 roleType;
        //同意数
        uint8 agressNum;
        // 地址
        address newAddress;
        // 老地址
        address oldAddress;
        //记录替换交易员投票结果
        mapping(address => bool) eachOwnerApprovalRoleResultMap;
    }