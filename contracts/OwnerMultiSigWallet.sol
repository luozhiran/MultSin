// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import {EventDefine} from "./EventDefine.sol";

contract OwnerMultiSigWallet is EventDefine {

/*************************************************************************************************/
/*                                  链上数据定义                                                  */
/*************************************************************************************************/
    // 合约的所有者，可以授权交易的控制人
    address[] public owners;

    // 交易的所有者，交易的所有者们，所有者地址 => true
    mapping(address => bool) public isOwner;

    // 合约的所有者赞成的票数，>= numConfirmationsRequired 才能发起交易
    uint public numConfirmationsRequired;

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
    }

    // 交易索引 => (合约所有者=>是否赞成)
    mapping(uint => mapping(address=>bool)) public isConfirmed;

    Transaction[] public transactions;

    // 候选所有者，即将替换 ownner 数组中的拥有者
    address public candidateOwner;
    // 即将被替换掉的合约拥有者
    address public replaceeOwner;
    
    //记录替换合约所有者投票结果
    mapping(address => bool) public aggressReplaceMap;
    uint8 public agreeTicketNum = 0;

/*************************************************************************************************/
/*                                  函数修改器                                                    */
/*************************************************************************************************/

    /*
     * @dev 校验是否是合约所有者
     */
    modifier onlyOwner(){
        require(isOwner[msg.sender], "not owner");
        _;
    }

    /*
     * @dev 校验交易是否存在，交易不存在抛出异常
     */
    modifier txExists(uint _txIndex){
        require(_txIndex < transactions.length, "tx does not exist");
        _;
    }

     /*
     * @dev 校验交易是否已经执行,如果已经执行抛出异常
     */
    modifier notExecuted(uint _txIndex){
        require(!transactions[_txIndex].executed, "tx already executed");
        _;
    }

     /*
     * @dev 校验交易是否已经确认，交易已经确认抛出异常
     */
    modifier notConfirmed(uint _txIndex){
        require(!isConfirmed[_txIndex][msg.sender], "tx already confirmed");
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
    constructor(address[] memory _owners, uint _numConfirmationsRequired){
        require(_owners.length > 0, "owner required");
        require(_numConfirmationsRequired > 0 && _numConfirmationsRequired <= _owners.length, "invalid number of requred confirmations");
        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner existed");
            isOwner[owner] = true;
            owners.push(owner);
        }
        numConfirmationsRequired = _numConfirmationsRequired;
    }


     // 合约账户接收外部转账
    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }


    /**
     * @dev 合约所有者中的一个，对其他合约所有者发起的交易投赞成
     * @param _txIndex 交易的索引
     */
    function confirmTransaction(uint _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) notConfirmed(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;
        emit ConfirmTransaction(msg.sender, _txIndex);
    }


      /**
     * @dev 合约所有者中的一个，撤销交易
     * @param _txIndex 交易的索引
     */
    function revokeConfirmation(uint _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        require(isConfirmed[_txIndex][msg.sender], "tx not confirmed");
        transaction.numConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;
        emit RevokeConfirmation(msg.sender, _txIndex);
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


    /**
     * @dev 输入候选owneer， 等待所有合约拥有者同意，则可以替换掉_replaceeOwner
     * @param _newOwner 新的合约拥有者
     * @param _replaceeOwner 即将被替换的合约拥有者
     */
    function inputCandidateOwner(address _newOwner, address _replaceeOwner) public onlyOwner {
         require(_newOwner != address(0) || _replaceeOwner != address(0), "invalid newOwner or replaceeOwner");
         require(isOwner[msg.sender], "replaceeOwner is not ownner");
         candidateOwner = _newOwner;
         replaceeOwner = _replaceeOwner;
    }

    /**
     * @dev 所有合约拥有者进行投票，全票投过生效
     * 
     */
    function agreeReplaceNewOwner() public onlyOwner {
        require(!aggressReplaceMap[msg.sender], "do not agree again!");
        aggressReplaceMap[msg.sender] = true;
        agreeTicketNum++;
    }

    /**
     * @dev 重置替换选举
     * 
     */
    function resetReplaceVote() public onlyOwner {
       agreeTicketNum = 0;
        for (uint i = 0; i < owners.length; i++) {
            aggressReplaceMap[owners[i]] = false;
        }
    }

    /**
     * @dev 启用新owner替换老owner
     * 
     */
    function invokeCandidateOwner() public onlyOwner {
        require(candidateOwner != address(0) && replaceeOwner != address(0), "please input candidateOwner and replaceeOwner");
        uint oldOwnerPosition = 0;
        bool findIt = false;
        for (uint i = 0; i < owners.length; i++) {
            if (owners[i] == replaceeOwner) {
                oldOwnerPosition = i;
                findIt = true;
                break;
            }
        }
       require(findIt, "don't match owner");
       owners[oldOwnerPosition] = candidateOwner;
       isOwner[replaceeOwner] = false;
       isOwner[candidateOwner] = true;
       // 重置替换选举
       this.resetReplaceVote();
    }

}