// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6;

import "./../interfaces/IOwner.sol";
import "./../interfaces/ITrader.sol";
import "./../interfaces/ITransaction.sol";

/// @dev 多签合约的判定器
abstract contract MulSigModify is IOwner,ITrader,ITransaction {
    /// @dev 创建合约实例条件
    modifier checkConstructor(
        address _traderPeople,
        uint _ownerCount,
        uint _approvalThresholdCount
    ) {
        require(address(0) != _traderPeople, "invalid trader people");
        require(_ownerCount > 0, "owner required");
        require(
            _approvalThresholdCount > 0 &&
                _approvalThresholdCount <= _ownerCount,
            "invalid number of confirmations"
        );
        _;
    }

    /// @dev 校验是否是合约所有者
    modifier onlyOwner() {
        require(this.isOwner(msg.sender), "only owner");
        _;
    }

    /// @dev 校验交易是否存在，交易不存在抛出异常
    modifier txExists(uint _txIndex) {
        require(this.transactionNotExit(_txIndex), "tx not exist");
        _;
    }

    /*
     * @dev 校验交易是否已经执行,如果已经执行抛出异常
     */
    modifier notExecuted(uint _txIndex) {
        require(this.transactionNotExec(_txIndex), "tx executed");
        _;
    }

    /// @dev 校验交易是否已经确认，交易已经确认抛出异常
    modifier notConfirmed(uint _txIndex) {
        require(
            this.transactionNotConfirmed(_txIndex),
            "already confirmed"
        );
        _;
    }

    /// @dev  校验是否是合约所有者认可的交易员
    modifier onlyTraderPeopleOrOwner() {
        require(
            this.isTrader(msg.sender) || this.isOwner(msg.sender),
            "not trader people or not owner"
        );
        _;
    }

    // function isOwner() external pure override returns (bool) {
    //     return false;
    // }

    // function isTrader() external pure override returns (bool) {
    //     return false;
    // }

    // function transactionNotExec(uint txIndex) external pure override returns (bool) {
    //     return false;
    // }

    // function transactionNotConfirmed(uint txIndex) external pure override returns (bool) {
    //     return false;
    // }
    // function transactionNotExit(uint txIndex) external pure override returns (bool) {
    //     return false;
    // }
}
