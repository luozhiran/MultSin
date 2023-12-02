// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

contract MultiSigWallet {


/*************************************************************************************************/
/*                                  日志声明                                                      */
/*************************************************************************************************/   
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
    }

    // 交易索引 => (合约所有者=>是否赞成)
    mapping(uint => mapping(address=>bool)) public isConfirmed;

    Transaction[] public transactions;

    // 交易员，可以发起[交易,执行交易]
     address[] public traderPeople;

    // 交易的所有者认可的交易员，所有者地址 => true
    mapping(address => bool) public isTraderPeople;



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
    constructor(address[] memory _owners, uint _numConfirmationsRequired, address _traderPeople){
        require(_owners.length > 0, "owner required");
        require(_numConfirmationsRequired > 0 && _numConfirmationsRequired <= _owners.length, "invalid number of requred confirmations");
        require(address(0) == _traderPeople, "invalid trader people");
        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner existed");
            isOwner[owner] = true;
            owners.push(owner);
        }

        numConfirmationsRequired = _numConfirmationsRequired;
        isTraderPeople[_traderPeople] = true;
        traderPeople.push(_traderPeople);
    }


    // 合约账户接收外部转账
    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
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
     * @dev 合约所有者中的一个或者交易员发起执行交易
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