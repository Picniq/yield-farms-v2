// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/ISDLClaim.sol";
import "./interfaces/ISaddlePool.sol";
import "./interfaces/IFraxStaking.sol";
import "./interfaces/IAlchemixStaking.sol";
import "./interfaces/IUniswapRouter.sol";
import "./interfaces/IUniswapV3.sol";
import "./interfaces/IERC20.sol";

// solhint-disable max-states-count, var-name-mixedcase
abstract contract Addresses {
    IFraxStaking internal fraxPool = IFraxStaking(0x0639076265e9f88542C91DCdEda65127974A5CA5);
    IAlchemixStaking internal alPool = IAlchemixStaking(0xAB8e74017a8Cc7c15FFcCd726603790d26d7DeCa);
    IUniswapV3 internal immutable uniswapRouter = IUniswapV3(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IUniswapRouter internal sushiRouter = IUniswapRouter(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
    IUniswapRouter internal uniswapRouterV2 = IUniswapRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    ISaddlePool internal saddleUSDPool = ISaddlePool(0xC69DDcd4DFeF25D8a793241834d4cc4b3668EAD6);
    ISDLClaim internal SDLClaim = ISDLClaim(0x691ef79e40d909C715BE5e9e93738B3fF7D58534);
    IERC20 internal saddleUSDToken = IERC20(0xd48cF4D7FB0824CC8bAe055dF3092584d0a1726A);
    IERC20 internal stakingToken = IERC20(0xc9da65931ABf0Ed1b74Ce5ad8c041C4220940368);
    IERC20 internal WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 internal FEI = IERC20(0x956F47F50A910163D8BF957Cf5846D573E7f87CA);
    IERC20 internal ALUSD = IERC20(0xBC6DA0FE9aD5f3b0d58160288917AA56653660E9);
    IERC20 internal FRAX = IERC20(0x853d955aCEf822Db058eb8505911ED77F175b99e);
    IERC20 internal LUSD = IERC20(0x5f98805A4E8be255a32880FDeC7F6728C6568bA0);
    IERC20 internal FXS = IERC20(0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0);
    IERC20 internal LQTY = IERC20(0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D);
    IERC20 internal TRIBE = IERC20(0xc7283b66Eb1EB5FB86327f08e1B5816b0720212B);
    IERC20 internal ALCX = IERC20(0xdBdb4d16EdA451D0503b854CF79D55697F90c8DF);
}