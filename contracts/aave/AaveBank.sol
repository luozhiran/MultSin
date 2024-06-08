// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.5;

import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import {IIERC20} from "./../interfaces/IIERC20.sol";
import "../modifys/MulSigModify.sol";

abstract contract AaveBank is MulSigModify {
    IPool public pool = IPool(0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951); //测试网地址

    /// @notice 把资产(代币)存储到aave中
    /// @dev 把资产(代币)存储到aave中
    /// @param asset 存储代币的token
    /// @param amount 存储代币的数量
    function supplyLiquidity(address asset, uint256 amount) external onlyTraderPeopleOrOwner {
        require(address(0) != asset, "invalid token");
        require(amount > 0, "input count must then 0");
        pool.supply(asset, amount, address(this), 0);
    }

    /// @notice 把资产(代币)从aave中取出来
    /// @dev 把资产(代币)从aave中取出来
    /// @param tokenAddress 存储在aave中的token，不是地址
    /// @param amount 取出代币的数量
    function withdrawlLiquidity(
        address tokenAddress,
        uint256 amount
    ) external onlyTraderPeopleOrOwner returns (uint256) {
        require(amount > 0, "input count must then 0");
        return pool.withdraw(tokenAddress, amount,  address(this));
    }
}