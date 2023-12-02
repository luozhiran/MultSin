// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;
import {OwnerMultiSigWallet} from "./OwnerMultiSigWallet.sol";

contract MultiSigWallet is OwnerMultiSigWallet {

    // 交易员，可以发起[交易,执行交易]
    address[] public traderPeople;

    // 交易的所有者认可的交易员，所有者地址 => true
    mapping(address => bool) public isTraderPeople;

    // 记录需要合约所有者确认和执行的交易
    Transaction[] public needConfirmAndExecTranction;


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
         require(address(0) != _traderPeople, "invalid trader people");
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
        Transaction memory ctx = Transaction({ to: _to, value: _value, data: _data, executed: false, numConfirmations: 0, txIndex: txIndex});
        transactions.push(ctx);
        needConfirmAndExecTranction.push(ctx);
        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }



    /**
     * @dev 合约所有者中的一个或者交易员
     * @param _txIndex 交易的索引
     */
    function executeTransaction(uint _txIndex) public onlyTraderPeopleOrOwner txExists(_txIndex) notExecuted(_txIndex) {
        require(_txIndex < transactions.length, "index out of bound when get transaction");
        Transaction storage transaction = transactions[_txIndex];
        require(transaction.numConfirmations >= numConfirmationsRequired, "cannot execute tx");
        transaction.executed = true;
        (bool success,) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success,"tx failed");
        (uint position, bool res) = transactionIndexOf(transaction);
        removeNeedContirmTransactionIfExected(position, res);
        emit ExecuteTransaction(msg.sender, _txIndex);
    }
    
    /**
     * @dev 如果交易完成，删除需要确认的交易
     * @param _txIndex 交易实力
     */
    function removeNeedContirmTransactionIfExected(uint _txIndex, bool exec) private {
        require(exec, "not find need contirm transaction");
        require(_txIndex < needConfirmAndExecTranction.length, "index out of bound");
        for (uint i = _txIndex; i < needConfirmAndExecTranction.length - 1; i++) {
             needConfirmAndExecTranction[i] = needConfirmAndExecTranction[i + 1];
        }
        needConfirmAndExecTranction.pop();       
    }

    /**
     * @dev 如果交易完成，删除需要确认的交易。注意：快速删除会改变数组排序
     * @param _txIndex 交易索引
     */
    function fastRemoveNeedContirmTransactionIfExected(uint _txIndex, bool exec) private {
         require(exec, "not find need contirm transaction");
        if (needConfirmAndExecTranction.length == 1 && _txIndex == 0) {
            needConfirmAndExecTranction.pop();
        }else {
            require(_txIndex < needConfirmAndExecTranction.length, "index out of bound when remove transaction");
            needConfirmAndExecTranction[_txIndex] = needConfirmAndExecTranction[transactions.length - 1];
            needConfirmAndExecTranction.pop();
        }  
    }

    /**
     * @dev 通过实例查询实列在数组中的位置
     * @param _transaction 交易实列
     */
    function transactionIndexOf(Transaction memory _transaction) public view returns(uint, bool) {
        uint position = 0;
        bool loopSuccess = false;
        for (uint i = 0 ; i < needConfirmAndExecTranction.length; i++) {
            if (_transaction.txIndex == needConfirmAndExecTranction[i].txIndex) {
                position = i;
                loopSuccess = true;
                break; 
            }
        }
        return (position, true);
    }

    /**
     * @dev 返回所有需要合约所有者确认的交易,web端可以根据numConfirmationsRequired区分出需要所有者确认的交易和需要执行的交易
     * 
     */
    function getNeedContirmAndExecTransactions() public view returns(Transaction[] memory, uint) {
        return (needConfirmAndExecTranction, numConfirmationsRequired);
    }

}