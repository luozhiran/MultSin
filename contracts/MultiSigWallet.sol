// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.5;

pragma abicoder v2;

import "./data/Transaction.sol";
import "./data/SwapRole.sol";
import "./data/CurrentInfo.sol";
import "./modifys/MulSigModify.sol";
import "./events/MultiSignEvent.sol";
import "./SwapToken.sol";

/// 多签合约的逻辑代码
contract MultiSigWallet is MultiSignEvent,MulSigModify, SwapToken {

   /// @dev 交易的所有者，交易的所有者们，所有者地址 => true
    mapping(address => bool) public ownerMap;

    /// @dev 保存所有交易信息
    Transaction[] public transactions;

    /// @dev 合约的所有者，可以授权交易的控制人
    address[] public owners;

    /// @dev 封装信息
    CurrentInfo public currentInfo;

    /// @dev 交换信息保存类
    SwapRole public swapRole;
  
    /// @dev 合约构造函数
    /// @param _owners 合约所有者
    /// @param _approvalThresholdCount 执行交易时，需要满足的赞成票数
    /// @param _traderPeople 交易员，可以发起交易，执行交易
     
    constructor(
        address[] memory _owners,
        uint8 _approvalThresholdCount,
        address _traderPeople
    )  checkConstructor(_traderPeople,_owners.length,_approvalThresholdCount) {
        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "invalid owner");
            require(!ownerMap[owner], "owner existed");
            ownerMap[owner] = true;
            owners.push(owner);
        }
        currentInfo.approvalThresholdCount = _approvalThresholdCount;
        currentInfo.traderPeople = _traderPeople;
    }

    
    /// @dev 合约的所有者发起的一次交易
    /// @param _to 目的账户地址
    /// @param _value 转出的金额
    /// @param token 代币地址
    /// @param _data 传入的二进制数据
    function submitTransaction(
        address _to,
        uint _value,
        address token,
        bytes memory _data
    ) public onlyTraderPeopleOrOwner {
        uint txIndex = transactions.length;
        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                numConfirmations: 0,
                txIndex: txIndex,
                token:token
            })
        );
        insertActiveTransaction(txIndex);
        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    
    /// @dev 合约所有者中的一个或者交易员
    /// @param _txIndex 交易的索引
    function executeTransaction(
        uint _txIndex
    ) public onlyTraderPeopleOrOwner txExists(_txIndex) notExecuted(_txIndex) {
        require(_txIndex < transactions.length, "index out of bound when get transaction");
        Transaction storage transaction = transactions[_txIndex];
        require(transaction.numConfirmations >= currentInfo.approvalThresholdCount,"cannot execute tx");
        if(transaction.token != address(0)) { // 把合约中的代币转移到某个账户
            TransferHelper.safeTransfer(transaction.token, transaction.to, transaction.value);
        } else {
            (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
            require(success, "tx failed");
        }
        transaction.executed = true;
        removeActiveTransaction(_txIndex);
        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    /// @dev 返回所有需要合约所有者确认的交易,web端可以根据numConfirmationsRequired区分出需要所有者确认的交易和需要执行的交易
    function getActiveTransactions() public view returns (Transaction[] memory, uint)
    {
        Transaction[] memory out = new Transaction[](currentInfo.activeTransactionCount);
        uint count = 0;
        for (uint i = 0; i < currentInfo.activeTransactionArray.length; i++) {
            if (currentInfo.activeTransactionArray[i] != 0xffffffffffffffff) {
                out[count++] = transactions[currentInfo.activeTransactionArray[i]];
            }
        }
        return (out, currentInfo.approvalThresholdCount);
    }


     /// @dev 返回所有需要合约所有者确认的交易,web端可以根据numConfirmationsRequired区分出需要所有者确认的交易和需要执行的交易
     /// @param _newOwner 新的交易员账户地址
    function submitReplaceTrader(address _newOwner) public onlyTraderPeopleOrOwner {
        require(swapRole.roleType != 2, "exit not compile owner repleace");
        require(_newOwner != address(0), "invalid new trader");
        require(swapRole.newAddress == address(0), "newTrader already exist");
        swapRole.newAddress = _newOwner;
        swapRole.roleType = 1;
    }

    /// @dev 输入候选owneer， 等待所有合约拥有者同意，则可以替换掉_replaceeOwner
    /// @param _newOwner 新的合约拥有者
    /// @param _oldOwner 即将被替换的合约拥有者
    function submitReplaceOwner(address _newOwner,address _oldOwner) public onlyOwner {
        require(swapRole.roleType != 1, "exit not compile trader repleace");
        require(_newOwner != address(0), "invalid newOwner");
        require(swapRole.newAddress == address(0), "newTrader already exist");
        require(ownerMap[_oldOwner], "invalid oldOwner");
        swapRole.newAddress = _newOwner;
        swapRole.oldAddress = _oldOwner;
        swapRole.roleType = 2;
    }

    /// @dev 审批：通过替换owner或交易员操作
    /// @param roleType 1：同意替换trader ,2：同意替换ower
    function approvePassReplaceAction(uint8 roleType) public onlyOwner{
         require(roleType == swapRole.roleType, "params is wrong");
         require(!swapRole.eachOwnerApprovalRoleResultMap[msg.sender], "insufficient confirmation");
         swapRole.eachOwnerApprovalRoleResultMap[msg.sender] = true;
         swapRole.agressNum ++;
    }

  
    /// @dev 执行替换操作
    function executeReplaceAction() public onlyOwner {
        if (swapRole.roleType == 1) { // 执行替换trader操作
          require( swapRole.agressNum >= currentInfo.approvalThresholdCount,"insufficient confirmation");
          // 启用新的交易员
          currentInfo.traderPeople = swapRole.newAddress;
          clearSwapRoleAction();
        } else if (swapRole.roleType == 2) { //执行替换owner操作
            require( swapRole.agressNum >= owners.length,"insufficient confirmation");
            uint i = 0;
            for (; i < owners.length; i++) {
                if (owners[i] == swapRole.oldAddress) {
                    break;
                 }
            }
            require(i < owners.length, "don't match owner");
            owners[i] = swapRole.newAddress;
            ownerMap[swapRole.oldAddress] = false;
            ownerMap[swapRole.newAddress] = true;
            delete swapRole.eachOwnerApprovalRoleResultMap[swapRole.oldAddress];
            clearSwapRoleAction();
        } else {
           require(false,"pleace,submit replace action");
        }
    }

    function clearSwapRoleAction() public {
        delete swapRole.agressNum;
        delete swapRole.newAddress;
        delete swapRole.oldAddress;
        delete swapRole.roleType;
        for(uint i=0; i<owners.length;i++) {
            delete swapRole.eachOwnerApprovalRoleResultMap[owners[i]];
        }
        
    }

    
    /// @dev 合约账户接收外部转账
    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function insertActiveTransaction(uint _txIndex) internal {
        if (currentInfo.activeTransactionCount == currentInfo.activeTransactionArray.length) {
            currentInfo.activeTransactionArray.push(_txIndex);
        } else {
            for (uint i = 0; i < currentInfo.activeTransactionArray.length; i++) {
                if (currentInfo.activeTransactionArray[i] == 0xffffffffffffffff) {
                    currentInfo.activeTransactionArray[i] = _txIndex;
                    break;
                }
            }
        }
        currentInfo.activeTransactionCount++;
    }

    function removeActiveTransaction(uint _txIndex) internal {
        for (uint i = 0; i < currentInfo.activeTransactionArray.length; i++) {
            if (currentInfo.activeTransactionArray[i] == _txIndex) {
                if (i > 0 && currentInfo.activeTransactionArray[0] != 0xffffffffffffffff) {
                    currentInfo.activeTransactionArray[i] =currentInfo. activeTransactionArray[0];
                    currentInfo.activeTransactionArray[0] = 0xffffffffffffffff;
                } else {
                    currentInfo.activeTransactionArray[i] = 0xffffffffffffffff;
                }
                currentInfo.activeTransactionCount--;
                return;
            }
        }
    }


    /// @dev 合约所有者中的一个，对其他合约所有者发起的交易投赞成
    /// @param _txIndex 交易的索引
    function confirmTransaction(uint _txIndex) public onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations += 1;
        currentInfo.eachOwnerApprovalResultMap[_txIndex][msg.sender] = true;
        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    /// @dev 合约所有者中的一个，撤销交易授权
    /// @param _txIndex 交易的索引
    function revokeConfirmation(uint _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        require(currentInfo.eachOwnerApprovalResultMap[_txIndex][msg.sender], "tx not confirmed");
        transaction.numConfirmations -= 1;
        currentInfo.eachOwnerApprovalResultMap[_txIndex][msg.sender] = false;
        removeActiveTransaction(_txIndex);
        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    
    /// @dev 返回合约拥有者
    function getOwners() public view returns (address[] memory) {
        return owners;
    }

 
    /// @dev 返回交易数量
    function getTransactionCount() public view returns (uint) {
        return transactions.length;
    }

    /// @dev 返回某个交易信息
    /// @param _txIndex 交易索引
    function getTransaction(uint _txIndex) public view returns (address to,uint value,bytes memory data,bool executed,uint numConfirmations){
        require(_txIndex < transactions.length, "index out of bound");
        Transaction storage transaction = transactions[_txIndex];
        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );
    }

   
    function resetReplaceOwner() public onlyOwner {
        delete swapRole;
    }

    /// @dev 校验合约所有者是否同意交易
    function getTransactionApproveResult(uint txIndex,address owner) public view txExists(txIndex) returns (bool) {
        return currentInfo.eachOwnerApprovalResultMap[txIndex][owner];
    }

    /// @dev 返回交易员地址
    function getTraderAddress() public view returns(address){
        return currentInfo.traderPeople;
    }

    /// @dev 校验角色替换审批是否通过
    function getSwapRoleApproveResult(address owner) public view returns(bool){
        return swapRole.eachOwnerApprovalRoleResultMap[owner];
    }

    
    function isOwner(address sender) external view override returns (bool) {
        return ownerMap[sender];
    }

   function isTrader(address sender) external view override returns(bool) {
        return sender == currentInfo.traderPeople;
    }

    function transactionNotExec(uint txIndex) external view override returns(bool) {
        return !transactions[txIndex].executed;
    }

    function transactionNotConfirmed(uint txIndex) external view override returns(bool) {
        return !currentInfo.eachOwnerApprovalResultMap[txIndex][msg.sender];
    }

     function transactionNotExit(uint txIndex) external view override returns(bool) {
        return txIndex < transactions.length;
    }
 
}