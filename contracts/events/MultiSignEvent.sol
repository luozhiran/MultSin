// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.6;


contract MultiSignEvent {

    /**
     * @dev 接收外部账户转账记录
     * @param sender 转账的外部账户地址
     * @param amount  交易金额
     * @param balance 转账后合约账户的金额
     */
    event Deposit(address indexed sender, uint amount, uint balance);

    /**
      * @dev 记录提交的交易日志
      * @param owner 交易的提交者
      * @param txIndex 交易的序号
      * @param to 交易的目的地址
      * @param value 交易的金额
      * @param data 交易传递的二进制数据
      */
    event SubmitTransaction(address indexed owner, uint indexed txIndex, address indexed to, uint value, bytes data);


    /**
     * @dev 记录确认交易日志
     * @param owner 合约所有者提出的确认票
     * @param txIndex  交易序号
     */
    event ConfirmTransaction(address indexed owner, uint indexed txIndex);

    /**
     * @dev 记录撤销交易日志
     * @param owner 合约所有者反悔撤销投票
     * @param txIndex 交易序号
     */
    event RevokeConfirmation(address indexed owner, uint indexed  txIndex);


    /**
     * @dev 记录执行交易日志
     * @param owner 发起交易执行的合约所有者地址
     * @param txIndex  合约的索引
     */
    event ExecuteTransaction(address indexed owner, uint indexed  txIndex);
}