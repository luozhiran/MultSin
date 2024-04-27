// SPDX-License-Identifier: MIT
pragma solidity >=0.7.5;
pragma abicoder v2;

import "https://github.com/Uniswap/uniswap-v3-periphery/blob/main/contracts/interfaces/ISwapRouter.sol";
import "https://github.com/Uniswap/uniswap-v3-periphery/blob/main/contracts/interfaces/IQuoter.sol";
import "https://github.com/Uniswap/uniswap-v3-periphery/blob/main/contracts/interfaces/IQuoterV2.sol";
import "https://github.com/Uniswap/swap-router-contracts/blob/main/contracts/interfaces/ISwapRouter02.sol";
import "https://github.com/Uniswap/swap-router-contracts/blob/main/contracts/interfaces/IV3SwapRouter.sol";
import "https://github.com/Uniswap/v3-periphery/blob/main/contracts/libraries/TransferHelper.sol";
import "https://github.com/Uniswap/v3-periphery/blob/main/contracts/interfaces/external/IWETH9.sol";
import "https://github.com/Uniswap/v3-periphery/blob/v1.0.0/contracts/interfaces/INonfungiblePositionManager.sol";
import "https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/TickMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721Receiver.sol";

interface IUniswapRouter is ISwapRouter02 {
    function refundETH() external payable;
}

contract Uniswap3 is IERC721Receiver {
    IUniswapRouter public constant uniswapRouter =
        IUniswapRouter(0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E);
    INonfungiblePositionManager public nonfungiblePositionManager =
        INonfungiblePositionManager(0x1238536071E1c677A632429e3655c799b22cDA52);
    address private constant UNI = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
    address private constant WETH9 = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    IWETH9 private constant wETH9Token = IWETH9(WETH9);
    uint24 public constant poolFee = 3000;

    // 存款
    mapping(uint256 => Deposit) public deposits;

    // 创建流动性后存放结构体，存款
    struct Deposit {
        address owner;
        uint128 liquidity;
        address token0;
        address token1;
    }

    constructor() {}

    /********************************************使用个体钱包账户swap**************************************************************************/

    // 把个人账户eth转化到个人UNI
    function toUNI() external payable {
        require(msg.value > 0, "Must pass non 0 ETH amount");

        address tokenIn = WETH9;
        address tokenOut = UNI;
        uint24 fee = 3000;
        address recipient = msg.sender;
        uint256 amountIn = msg.value;
        uint256 amountOutMinimum = 1;
        uint160 sqrtPriceLimitX96 = 0;

        IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter
            .ExactInputSingleParams(
                tokenIn,
                tokenOut,
                fee,
                recipient,
                amountIn,
                amountOutMinimum,
                sqrtPriceLimitX96
            );

        uniswapRouter.exactInputSingle{value: msg.value}(params);
        uniswapRouter.refundETH();

        // refund leftover ETH to user
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "refund failed");
    }

    // 把UNI转化成WETH9放入合约账户
    function swapToWeth(uint256 amountIn) external returns (uint256 amountOut) {
        // msg.sender must approve this contract

        // Transfer the specified amount of DAI to this contract.
        TransferHelper.safeTransferFrom(
            UNI,
            msg.sender,
            address(this),
            amountIn
        );

        // Approve the router to spend DAI.
        TransferHelper.safeApprove(UNI, address(uniswapRouter), amountIn);

        // Naively set amountOutMinimum to 0. In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
        // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.
        IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter
            .ExactInputSingleParams({
                tokenIn: UNI,
                tokenOut: WETH9,
                fee: 3000,
                recipient: address(this),
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        amountOut = uniswapRouter.exactInputSingle(params);
    }

    // 把WETH9转化成UNI放入合约账户
    function swapToUNI(uint256 amountIn) external returns (uint256 amountOut) {
        // msg.sender must approve this contract

        // Transfer the specified amount of DAI to this contract.
        TransferHelper.safeTransferFrom(
            WETH9,
            msg.sender,
            address(this),
            amountIn
        );

        // Approve the router to spend DAI.
        TransferHelper.safeApprove(WETH9, address(uniswapRouter), amountIn);

        // Naively set amountOutMinimum to 0. In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
        // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.
        IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter
            .ExactInputSingleParams({
                tokenIn: WETH9,
                tokenOut: UNI,
                fee: 3000,
                recipient: address(this),
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        amountOut = uniswapRouter.exactInputSingle(params);
    }

    /********************************************使用合约账户swap**************************************************************************/
    function swapContractWETH_to_UNI(uint256 amountIn) external returns (bool, uint256) {
        // Approve the router to spend DAI.
        TransferHelper.safeApprove(address(0), address(uniswapRouter), amountIn);
        // Naively set amountOutMinimum to 0. In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
        // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.
        IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter
            .ExactInputSingleParams({
                tokenIn: address(0),
                tokenOut: UNI,
                fee: 3000,
                recipient: address(this),
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });
        bytes memory exactInputSingleBytes = abi.encodeWithSignature("exactInputSingle((address,address,uint24,address,uint256,uint256,uint160))", params);
        (bool success, bytes memory returnDatas) = address(uniswapRouter).call(exactInputSingleBytes);
        (amountIn) = abi.decode(returnDatas, (uint256));
        require(success, unicode"lzr swapContractWETH_to_UNI");
        return (success, amountIn);
    }

    function swapCotractUNI_to_WETH(uint256 amountIn) external returns (bool, uint256) {
        TransferHelper.safeApprove(UNI, address(uniswapRouter), amountIn);
        IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter
            .ExactInputSingleParams({
                tokenIn: UNI,
                tokenOut: WETH9,
                fee: 3000,
                recipient: address(this),
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });
        bytes memory exactInputSingleBytes = abi.encodeWithSignature("exactInputSingle((address,address,uint24,address,uint256,uint256,uint160))",params);
        (bool success, bytes memory returnDatas) = address(uniswapRouter).call(exactInputSingleBytes);
         require(success, unicode"lzr swapCotractUNI_to_WETH");
        (amountIn) = abi.decode(returnDatas, (uint256));
        return (success, amountIn);
    }

    /********************************************余额**************************************************************************/
    //合约账户 weth 余额
    function WethBalance() external view returns (uint256) {
        return wETH9Token.balanceOf(address(this));
    }

    // 合约账户 UNI 余额
    function UNIBalance() external view returns (uint256) {
        return IWETH9(UNI).balanceOf(address(this));
    }

    // 合约账户eth余额
    function EthBalance() external view returns (uint256) {
        return address(this).balance;
    }
    /*******************************************eth to weth**************************************************************************/
    function deposit() public {
        require(address(this).balance > 0, "no money");
        wETH9Token.deposit{ value: address(this).balance }();
    }

    /********************************************取钱**************************************************************************/
    // 取出合约中的所有资金
    function withdraw() public {
        require(address(this).balance > 0, "no money");
        payable(msg.sender).transfer(address(this).balance);
    }

    // 把个人账户中的WETH9提现到个人账户的eth
    function swapWethToEth() external returns (bool) {
        (bool success, ) = msg.sender.call(
            abi.encodeWithSignature("withdraw(uint256)", 1000000000000000000)
        );
        return success;
    }

    // 把合约账户中的WETH9提现到合约账户eth
    function wethToContractEth() external {
        wETH9Token.withdraw(wETH9Token.balanceOf(address(this)));
    }

    // important to receive ETH
    receive() external payable {}


    /********************************************流动性功能**************************************************************************/

    /// @dev 实现' onERC721Received '，使该合约可以接收erc721代币的托管
    function onERC721Received( address operator, address, uint256 tokenId,bytes calldata) external override returns (bytes4) {
        // 获取职位信息
        _createDeposit(operator, tokenId);
        return this.onERC721Received.selector;
    }

    /// @notice 添加流动性
    function addLiquidity(uint256 amount0ToMint, uint256 amount1ToMint) external returns ( uint256 tokenId,uint128 liquidity,uint256 amount0,uint256 amount1) {
        // Approve the position manager
        TransferHelper.safeApprove(WETH9, address(nonfungiblePositionManager), amount0ToMint );
        TransferHelper.safeApprove( UNI, address(nonfungiblePositionManager), amount1ToMint );
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
                token0: WETH9,
                token1: UNI,
                fee: 3000,
                tickLower: TickMath.MIN_TICK,
                tickUpper: TickMath.MAX_TICK,
                amount0Desired: amount0ToMint,
                amount1Desired: amount1ToMint,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            });
        // 使用合约中的代币添加流动性，需要使用call()方法,否者转调用者账户的钱
        bytes memory minitParamsBytes = abi.encodeWithSignature("mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))", params);
        (bool success, bytes memory mintDataBytes) = address(nonfungiblePositionManager).call(minitParamsBytes);
        (tokenId, liquidity, amount0, amount1) = abi.decode(mintDataBytes, (uint256, uint128, uint256, uint256 ));
        // (tokenId, liquidity, amount0, amount1) = nonfungiblePositionManager.mint(params);
        require(success,"yyds:mint faile");
        _createDeposit(address(this), tokenId);

        // 添加流动性剩余的代币 退回合约代币账户
        if (amount0 < amount0ToMint) {
            TransferHelper.safeApprove( WETH9, address(nonfungiblePositionManager), 0 );
            uint256 refund0 = amount0ToMint - amount0;
            TransferHelper.safeTransfer(WETH9, address(this), refund0);
        }

       // 添加流动性剩余的代币 退回合约代币账户
        if (amount1 < amount1ToMint) {
            TransferHelper.safeApprove( UNI, address(nonfungiblePositionManager), 0);
            uint256 refund0 = amount1ToMint - amount1;
            TransferHelper.safeTransfer(UNI, address(this), refund0);
        }
    }

    /// @dev 创建存款
    function _createDeposit(address owner, uint256 tokenId) internal {
        ( , , address token0,address token1, , , , uint128 liquidity, , , , ) = nonfungiblePositionManager.positions(tokenId);
        deposits[tokenId] = Deposit({ owner: owner, liquidity: liquidity, token0: token0, token1: token1});
    }

    /// @notice 收取与提供的流动性相关的费用
    /// @dev 合约必须持有erc721代币才能收取费用
    /// @param tokenId The id of the erc721 token
    /// @return amount0 在token0中收取的费用金额
    /// @return amount1 在token1中收取的费用金额
    function collectAllFees(uint256 tokenId) external returns (uint256 amount0, uint256 amount1) {
        // 调用者必须拥有ERC721位置
        // 对safeTransfer的调用将触发' onERC721Received '，它必须返回选择器，否则传输将失败
        // nonfungiblePositionManager.safeTransferFrom( msg.sender, address(this), tokenId ); // tokenId已经在合约中了，不需要在转移tokenId到合约

        // set amount0Max and amount1Max to uint256.max to collect all fees
        // alternatively can set recipient to msg.sender and avoid another transaction in `sendToOwner`
        INonfungiblePositionManager.CollectParams memory params = INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });

        (amount0, amount1) = nonfungiblePositionManager.collect(params);

        // send collected feed back to owner
        // _sendToOwner(tokenId, amount0, amount1); // 不需要把收益转到其他地方，存在合约中
    }

    /// 将资金转移给NFT的所有者
    /// @param tokenId The id of the erc721
    /// @param amount0 The amount of token0
    /// @param amount1 The amount of token1
    function _sendToOwner( uint256 tokenId, uint256 amount0, uint256 amount1) internal {
        // get owner of contract
        address owner = deposits[tokenId].owner;

        address token0 = deposits[tokenId].token0;
        address token1 = deposits[tokenId].token1;
        // send collected fees to owner
        TransferHelper.safeTransfer(token0, owner, amount0);
        TransferHelper.safeTransfer(token1, owner, amount1);
    }

    /// @notice 减少流动性: 将当前流动性减少一半的函数。一个例子来显示如何调用'减少流动性'函数定义在外围。
    /// @param tokenId The id of the erc721 token
    /// @return amount0 The amount received back in token0
    /// @return amount1 The amount returned back in token1
    function decreaseLiquidityInHalf(uint256 tokenId) external returns (uint256 amount0, uint256 amount1) {
        // caller must be the owner of the NFT
        require(msg.sender == deposits[tokenId].owner, "Not the owner");
        // get liquidity data for tokenId
        uint128 liquidity = deposits[tokenId].liquidity;
        uint128 halfLiquidity = liquidity / 2;

        // amount0Min and amount1Min are price slippage checks
        // if the amount received after burning is not greater than these minimums, transaction will fail
        INonfungiblePositionManager.DecreaseLiquidityParams memory params = INonfungiblePositionManager.DecreaseLiquidityParams({
                    tokenId: tokenId,
                    liquidity: halfLiquidity,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });

        (amount0, amount1) = nonfungiblePositionManager.decreaseLiquidity(params);
        //send liquidity back to owner
        _sendToOwner(tokenId, amount0, amount1);
    }

    /// @notice 增加当前范围内的流动性
    /// @dev Pool must be initialized already to add liquidity
    /// @param tokenId The id of the erc721 token
    /// @param amount0 The amount to add of token0
    /// @param amount1 The amount to add of token1
    function increaseLiquidityCurrentRange(uint256 tokenId, uint256 amountAdd0, uint256 amountAdd1) external returns ( uint128 liquidity, uint256 amount0, uint256 amount1){
        INonfungiblePositionManager.IncreaseLiquidityParams memory params = INonfungiblePositionManager.IncreaseLiquidityParams({
                    tokenId: tokenId,
                    amount0Desired: amountAdd0,
                    amount1Desired: amountAdd1,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });

        (liquidity, amount0, amount1) = nonfungiblePositionManager
            .increaseLiquidity(params);
    }
}
