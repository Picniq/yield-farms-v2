// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../interfaces/ISDLClaim.sol";
import "../interfaces/ISaddlePool.sol";
import "../interfaces/IFraxStaking.sol";
import "../interfaces/IAlchemixStaking.sol";
import "../interfaces/IUniswapRouter.sol";
import "../interfaces/IUniswapV3.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IUniswapV3.sol";
import "../interfaces/IUniswapRouter.sol";
import "../interfaces/ICurve.sol";
import "../interfaces/IERC20.sol";
import "./Addresses.sol";

library Swaps {
    IUniswapV3 internal constant UNISWAP_ROUTER = IUniswapV3(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IUniswapRouter internal constant SUSHI_ROUTER = IUniswapRouter(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
    IUniswapRouter internal constant UNISWAP_ROUTER_V2 = IUniswapRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    ISDLClaim internal constant SDLClaim = ISDLClaim(0x691ef79e40d909C715BE5e9e93738B3fF7D58534);

    function swapUsingSushi(address tokenIn, address tokenOut, uint256 amount, uint256 expected, bool ethHop) internal returns (uint256) {
        address[] memory path = new address[](ethHop ? 3 : 2);
        path[0] = tokenIn;
        if (ethHop) {
            path[1] = address(Addresses.WETH);
            path[2] = tokenOut;
        } else {
            path[1] = tokenOut;
        }
        uint256[] memory outputs = SUSHI_ROUTER.swapExactTokensForTokens(amount, expected, path, address(this), block.timestamp);
        return outputs[ethHop ? 2 : 1];
    }

    function swapUsingUni(address tokenIn, address tokenOut, uint256 amount, uint256 expected, bool ethHop) internal returns (uint256) {
        address[] memory path = new address[](ethHop ? 3 : 2);
        path[0] = tokenIn;
        if (ethHop) {
            path[1] = address(Addresses.WETH);
            path[2] = tokenOut;
        } else {
            path[1] = tokenOut;
        }
        uint256[] memory outputs = UNISWAP_ROUTER_V2.swapExactTokensForTokens(amount, expected, path, address(this), block.timestamp);
        return outputs[ethHop ? 2 : 1];
    }

    function swapETHForTokens(address token, uint256 expected, uint24 fee) internal returns (uint256) {
        require(msg.value > 0, "Value is zero");

        IUniswapV3.ExactInputSingleParams memory params = IUniswapV3.ExactInputSingleParams({
            deadline: block.timestamp,
            tokenIn: address(Addresses.WETH),
            tokenOut: token,
            fee: fee,
            recipient: msg.sender,
            amountIn: msg.value,
            amountOutMinimum: expected,
            sqrtPriceLimitX96: 0
        });

        uint output = UNISWAP_ROUTER.exactInputSingle{value: msg.value}(params);
        
        return output;
    }

    function swapTokensForETH(address token, uint256 amount, uint256 expected, uint24 fee) internal returns (uint256) {
        IUniswapV3.ExactInputSingleParams memory params = IUniswapV3.ExactInputSingleParams({
            deadline: block.timestamp,
            tokenIn: token,
            tokenOut: address(Addresses.WETH),
            fee: fee,
            recipient: msg.sender,
            amountIn: amount,
            amountOutMinimum: expected,
            sqrtPriceLimitX96: 0
        });

        uint output = UNISWAP_ROUTER.exactInputSingle(params);

        return output;
    }

    function swapETHForTokensV2(address token, uint256 expected) internal returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = address(Addresses.WETH);
        path[1] = token;
        uint256[] memory outputs = UNISWAP_ROUTER_V2.swapExactETHForTokens{value: msg.value}(expected, path, msg.sender, block.timestamp);
        return outputs[1];
    }

    function claimSDL(uint256 poolId, address receiver) internal {
        SDLClaim.harvest(poolId, receiver);
    }
}