// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;
import {OwnerMultiSigWallet} from "./OwnerMultiSigWallet.sol";

contract MultiSigWallet is OwnerMultiSigWallet {

    // 交易员，可以发起[交易,执行交易]
    address[] public traderPeople;

    // 交易的所有者认可的交易员，所有者地址 => true
    mapping(address => bool) public isTraderPeople;

/*************************************************************************************************/
/*                                  函数修改器                                                    */
/*************************************************************************************************/
     /*
     * @dev  校验是否是合约所有者认可的交易员
     */
    modifier onlyTraderPeopleOrOwner() {
         require(isTraderPeople[msg.sender] || isOwner[msg.sender], "not trader people or not owner");
         _;
    }

/*************************************************************************************************/
/*                                  函数                                                         */
/*************************************************************************************************/

    /*
     * @dev 合约构造函数
     * @param _owners 合约所有者
     * @param _numConfirmationsRequired 执行交易时，需要满足的赞成票数
     * @param _traderPeople 交易员，可以发起交易，执行交易
     */
    constructor(address[] memory _owners, uint _numConfirmationsRequired, address _traderPeople) OwnerMultiSigWallet(_owners, _numConfirmationsRequired) {
         require(address(0) == _traderPeople, "invalid trader people");
        isTraderPeople[_traderPeople] = true;
        traderPeople.push(_traderPeople);
    }


    /*
     * @dev 合约的所有者发起的一次交易
     * @param _to 目的账户地址
     * @param _value 转出的金额
     * @param _data 传入的二进制数据
     */
    function submitTransaction(address _to, uint _value, bytes memory _data) public onlyTraderPeopleOrOwner {
        uint txIndex = transactions.length;
        transactions.push(Transaction(
            {
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                numConfirmations: 0
            }
        ));

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }



    /**
     * @dev 合约所有者中的一个或者交易员
     * @param _txIndex 交易的索引
     */
    function executeTransaction(uint _txIndex) public onlyTraderPeopleOrOwner txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        require(transaction.numConfirmations >= numConfirmationsRequired, "cannot execute tx");
        transaction.executed = true;
        (bool success,) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success,"tx failed");
        emit ExecuteTransaction(msg.sender, _txIndex);

    }

    /**
     * @dev 返回合约拥有者
     */
    function getOwners() public view returns(address[] memory) {
        return owners;
    }

    /**
     * @dev 返回交易数量
     */
   function getTransactionCount() public view returns (uint) {
        return transactions.length;
    }


    /**
     * @dev 返回某个交易信息
     * @param _txIndex 交易索引
     */
    function getTransaction(uint _txIndex) public view returns (
        address to,
        uint value,
        bytes memory data,
        bool executed,
        uint numConfirmations
    ) {
        Transaction storage transaction = transactions[_txIndex];
        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );

    } 
    

}