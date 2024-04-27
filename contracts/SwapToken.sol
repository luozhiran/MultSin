// SPDX-License-Identifier: MIT
pragma solidity >=0.7.5;
pragma abicoder v2;

import "https://github.com/Uniswap/uniswap-v3-periphery/blob/main/contracts/interfaces/ISwapRouter.sol";
import "https://github.com/Uniswap/uniswap-v3-periphery/blob/main/contracts/interfaces/IQuoter.sol";
import "https://github.com/Uniswap/uniswap-v3-periphery/blob/main/contracts/interfaces/IQuoterV2.sol";
import "https://github.com/Uniswap/swap-router-contracts/blob/main/contracts/interfaces/ISwapRouter02.sol";
import "https://github.com/Uniswap/swap-router-contracts/blob/main/contracts/interfaces/IV3SwapRouter.sol";
// import "@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol";
import "https://github.com/Uniswap/v3-periphery/blob/main/contracts/libraries/TransferHelper.sol";
import "https://github.com/Uniswap/v3-periphery/blob/v1.0.0/contracts/interfaces/INonfungiblePositionManager.sol";
import "./interfaces/IUniswapRouter.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IIERC20.sol";
import "./modifys/MulSigModify.sol";
import "./interfaces/IERC721Receiver.sol";

abstract contract SwapToken is MulSigModify, IERC721Receiver {
    IUniswapRouter public constant uniswapRouter = IUniswapRouter(0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E);
    INonfungiblePositionManager public nonfungiblePositionManager = INonfungiblePositionManager(0x1238536071E1c677A632429e3655c799b22cDA52);
    IIERC20 private constant uniToken = IIERC20(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
    IWETH private constant wethToken = IWETH(0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14);
    
    int24 private constant MIN_TICK = -887272;
    int24 private constant MAX_TICK = -MIN_TICK;
    int24 private constant TICK_SPACING = 60;
    

    /// @dev 实现' onERC721Received '，使该合约可以接收erc721代币的托管
    function onERC721Received( address operator, address, uint256 tokenId,bytes calldata) external pure override returns (bytes4) {
        // 获取职位信息
        return IERC721Receiver.onERC721Received.selector;
    }

    /// @notice 没有充足的代币，报错
    /// @dev 检查交换代币，输入代币数量
    modifier checkInputToken(address inputToken, uint256 amountIn) {
        require(address(0) != inputToken, "invalid token");
        require(amountIn > 0, "invalid token count");
        uint256 count = IIERC20(inputToken).balanceOf(address(this));
        require(count >= amountIn, "no enough tokens!");
        _;
    }
    

    /// @dev 交换代币
    /// @param inputToken 输入代币
    /// @param outputToken 输出代币
    /// @param amountIn 交换数量
    function swapTokens(address inputToken, address outputToken, uint256 amountIn) external returns (bool, uint256){
        // 授权uniswapRouter可以使用合约中的代币
        TransferHelper.safeApprove(inputToken, address(uniswapRouter), amountIn);
         IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter
            .ExactInputSingleParams({
                tokenIn: inputToken,
                tokenOut: outputToken,
                fee: 3000,
                recipient: address(this),
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });
        bytes memory exactInputSingleBytes = abi.encodeWithSignature("exactInputSingle((address,address,uint24,address,uint256,uint256,uint160))", params);
        (bool success, bytes memory returnDatas) = address(uniswapRouter).call(exactInputSingleBytes);
        (amountIn) = abi.decode(returnDatas, (uint256));
        return (success, amountIn);
    }

    /// @notice 添加流动性
    /// @dev 添加流动性
    /// @param inputToken1 代币地址
    /// @param inputToken1Count 代币数量
    /// @param inputToken2 代币地址
    /// @param inputToken2Count 代币数量
    function mintNewPosition(address inputToken1 , uint256 inputToken1Count,address inputToken2 , uint256 inputToken2Count, uint24 poolFee)
     external returns (uint256 tokenId, uint128 liquidity, uint256 amount0,uint256 amount1) {
        TransferHelper.safeApprove(inputToken1, address(nonfungiblePositionManager), inputToken1Count );
        TransferHelper.safeApprove( inputToken2, address(nonfungiblePositionManager), inputToken2Count );
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: inputToken1,
            token1: inputToken2,
            fee: poolFee,
            tickLower: (MIN_TICK / TICK_SPACING) * TICK_SPACING,
            tickUpper: (MAX_TICK / TICK_SPACING) * TICK_SPACING,
            amount0Desired: inputToken1Count,
            amount1Desired: inputToken2Count,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            deadline: block.timestamp
        });
        bytes memory minitParamsBytes = abi.encodeWithSignature("mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))", params);
        (bool success, bytes memory mintDataBytes) = address(nonfungiblePositionManager).call(minitParamsBytes);
        require(success, 'exec mintNewPosition faile');
        (tokenId, liquidity, amount0, amount1) = abi.decode(mintDataBytes, (uint256, uint128, uint256, uint256 ));
        
         if (amount0 < inputToken1Count) {
            TransferHelper.safeApprove( inputToken1, address(nonfungiblePositionManager), 0 );
            uint256 refund0 = inputToken1Count - amount0;
            TransferHelper.safeTransfer(inputToken1, address(this), refund0);
        }

        if (amount1 < inputToken2Count) {
             TransferHelper.safeApprove( inputToken2, address(nonfungiblePositionManager), 0 );
            uint256 refund1 = inputToken2Count - amount0;
            TransferHelper.safeTransfer(inputToken2, address(this), refund1);
        }
     }


    /// @notice 收取与提供的流动性相关的费用
    /// @dev 合约必须持有erc721代币才能收取费用
    /// @param tokenId The id of the erc721 token
    /// @return amount0 在token0中收取的费用金额
    /// @return amount1 在token1中收取的费用金额
    function collectAllFees(uint256 tokenId) external onlyOwner returns (uint256 amount0, uint256 amount1)  {
        INonfungiblePositionManager.CollectParams memory params = INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });

        bytes memory paramsBytes = abi.encodeWithSignature("collect((uint256 ,address,uint128 ,uint128))", params);
        (bool success, bytes memory returnDatas) = address(nonfungiblePositionManager).call(paramsBytes);
        require(success, 'exec collectAllFees faile');
        (amount0, amount1) = abi.decode(returnDatas, (uint256, uint256 ));
        // (amount0, amount1) = nonfungiblePositionManager.collect(params);
    }

    /// @notice 减少流动性: 将当前流动性减少一半的函数。一个例子来显示如何调用'减少流动性'函数定义在外围。
    /// @param tokenId The id of the erc721 token
    /// @return amount0 The amount received back in token0
    /// @return amount1 The amount returned back in token1
    function decreaseLiquidityInHalf(uint256 tokenId,uint128 halfLiquidity) external onlyOwner returns (uint256 amount0, uint256 amount1) {
    
        // amount0Min and amount1Min are price slippage checks
        // if the amount received after burning is not greater than these minimums, transaction will fail
        INonfungiblePositionManager.DecreaseLiquidityParams memory params = INonfungiblePositionManager.DecreaseLiquidityParams({
                    tokenId: tokenId,
                    liquidity: halfLiquidity,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });

        bytes memory paramsBytes = abi.encodeWithSignature("decreaseLiquidity((uint256, uint128, uint256, uint256, uint256))", params);
        (bool success, bytes memory returnDatas) = address(nonfungiblePositionManager).call(paramsBytes);
        require(success, 'exec decreaseLiquidityInHalf faile');
        (amount0, amount1) = abi.decode(returnDatas, (uint256, uint256 ));
        // (amount0, amount1) = nonfungiblePositionManager.decreaseLiquidity(params);
        //send liquidity back to owner
    }

    /// @notice 增加当前范围内的流动性
    /// @dev Pool must be initialized already to add liquidity
    /// @param tokenId The id of the erc721 token
    /// @param amount0 The amount to add of token0
    /// @param amount1 The amount to add of token1
    function increaseLiquidityCurrentRange(uint256 tokenId, uint256 amountAdd0, uint256 amountAdd1) external onlyOwner returns ( uint128 liquidity, uint256 amount0, uint256 amount1){
        INonfungiblePositionManager.IncreaseLiquidityParams memory params = INonfungiblePositionManager.IncreaseLiquidityParams({
                    tokenId: tokenId,
                    amount0Desired: amountAdd0,
                    amount1Desired: amountAdd1,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });

        bytes memory paramsBytes = abi.encodeWithSignature("increaseLiquidity((uint256, uint256 , uint256, uint256, uint256, uint256))", params);
        (bool success, bytes memory returnDatas) = address(nonfungiblePositionManager).call(paramsBytes);
        require(success, 'exec increaseLiquidityCurrentRange faile');
        (liquidity, amount0, amount1) = abi.decode(returnDatas, ( uint128, uint256, uint256));
        // (liquidity, amount0, amount1) = nonfungiblePositionManager.increaseLiquidity(params);
    }


    /// @notice 销毁流动性仓位
    /// @dev 烧掉一个令牌ID，并将其从NFT合约中删除。代币必须具有0流动性和所有代币
    function destoryLiquidity(uint256 tokenId) external onlyOwner {
         bytes memory paramsBytes = abi.encodeWithSignature("burn(uint256)", tokenId);
         (bool success, ) = address(nonfungiblePositionManager).call(paramsBytes);
         require(success, 'exec destoryLiquidity faile');
    }


     /// @notice 获取合约中代币个数
     function getTokenBalanceOf(address token) public view returns (uint256){
        return IWETH(token).balanceOf(address(this));
    }

    
    //888888888888888888888888888888888888 测试代码 888888888888888888888888888888888888

    
    function unwrapEther() public {
        wethToken.withdraw(wethToken.balanceOf(address(this)));
    }

    function wrapEther(uint256 count) external {
        require(address(this).balance > 0, "no money");
        if (count == 0) {
            wethToken.deposit{ value: address(this).balance }();
        } else {
            wethToken.deposit{ value: count }();
        }   
    }

    // 取出合约中的所有资金
    function withdraw() public {
        require(address(this).balance > 0, "no money");
        payable(msg.sender).transfer(address(this).balance);
    }

}