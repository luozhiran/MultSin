// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6;

 struct Transaction {
        // 受益人地址
        address to;
        // 发起的交易金额
        uint value;
        // 传递的二进制数据
        bytes data;
        // 交易是否已经被执行
        bool executed;
        // 赞成数
        uint numConfirmations;
        // 交易的序列号
        uint txIndex;

        //代币地址，如果存在代币地址，则默认发起代币转移
        address token;
    }