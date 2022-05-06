// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IUniswapV3.sol";
import "./interfaces/IUniswapRouter.sol";
import "./interfaces/IERC20.sol";
import "./Addresses.sol";

// solhint-disable not-rely-on-time
abstract contract Swaps is Addresses {

    function swapUsingSushi(address tokenIn, address tokenOut, uint256 amount, uint256 expected, bool ethHop) public returns (uint256) {
        address[] memory path = new address[](ethHop ? 3 : 2);
        path[0] = tokenIn;
        if (ethHop) {
            path[1] = address(WETH);
            path[2] = tokenOut;
        } else {
            path[1] = tokenOut;
        }
        uint256[] memory outputs = sushiRouter.swapExactTokensForTokens(amount, expected, path, address(this), block.timestamp);
        return outputs[ethHop ? 2 : 1];
    }

    function swapUsingUni(address tokenIn, address tokenOut, uint256 amount, uint256 expected, bool ethHop) public returns (uint256) {
        address[] memory path = new address[](ethHop ? 3 : 2);
        path[0] = tokenIn;
        if (ethHop) {
            path[1] = address(WETH);
            path[2] = tokenOut;
        } else {
            path[1] = tokenOut;
        }
        uint256[] memory outputs = uniswapRouterV2.swapExactTokensForTokens(amount, expected, path, address(this), block.timestamp);
        return outputs[ethHop ? 2 : 1];
    }

    function swapETHForTokens(address token, uint256 expected, uint24 fee) external payable returns (uint256) {
        require(msg.value > 0, "Value is zero");

        IUniswapV3.ExactInputSingleParams memory params = IUniswapV3.ExactInputSingleParams({
            deadline: block.timestamp,
            tokenIn: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            tokenOut: token,
            fee: fee,
            recipient: msg.sender,
            amountIn: msg.value,
            amountOutMinimum: expected,
            sqrtPriceLimitX96: 0
        });

        uint output = uniswapRouter.exactInputSingle{value: msg.value}(params);
        
        return output;
    }

    function swapTokensForETH(address token, uint256 amount, uint256 expected, uint24 fee) external payable returns (uint256) {
        IUniswapV3.ExactInputSingleParams memory params = IUniswapV3.ExactInputSingleParams({
            deadline: block.timestamp,
            tokenIn: token,
            tokenOut: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            fee: fee,
            recipient: msg.sender,
            amountIn: amount,
            amountOutMinimum: expected,
            sqrtPriceLimitX96: 0
        });

        uint output = uniswapRouter.exactInputSingle(params);

        return output;
    }

    function swapETHForTokensV2(address token, uint256 expected) public payable returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = token;
        uint256[] memory outputs = uniswapRouterV2.swapExactETHForTokens{value: msg.value}(expected, path, msg.sender, block.timestamp);
        return outputs[1];
    }
}