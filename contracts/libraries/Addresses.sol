// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../interfaces/IERC20.sol";
import "../interfaces/ISaddlePool.sol";
import "../interfaces/IAlchemixStaking.sol";
import "../interfaces/IAave.sol";
import "../interfaces/ICurve.sol";

library Addresses {
    IERC20 internal constant SADDLE_USD_TOKEN = IERC20(0xd48cF4D7FB0824CC8bAe055dF3092584d0a1726A);
    IERC20 internal constant SADDLE_ETH_TOKEN = IERC20(0xc9da65931ABf0Ed1b74Ce5ad8c041C4220940368);
    IERC20 internal constant STAKING_TOKEN = IERC20(0xc9da65931ABf0Ed1b74Ce5ad8c041C4220940368);
    IERC20 internal constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 internal constant FEI = IERC20(0x956F47F50A910163D8BF957Cf5846D573E7f87CA);
    IERC20 internal constant ALUSD = IERC20(0xBC6DA0FE9aD5f3b0d58160288917AA56653660E9);
    IERC20 internal constant FRAX = IERC20(0x853d955aCEf822Db058eb8505911ED77F175b99e);
    IERC20 internal constant LUSD = IERC20(0x5f98805A4E8be255a32880FDeC7F6728C6568bA0);
    IERC20 internal constant FXS = IERC20(0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0);
    IERC20 internal constant LQTY = IERC20(0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D);
    IERC20 internal constant TRIBE = IERC20(0xc7283b66Eb1EB5FB86327f08e1B5816b0720212B);
    IERC20 internal constant ALCX = IERC20(0xdBdb4d16EdA451D0503b854CF79D55697F90c8DF);
    IERC20 internal constant STETH = IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    IERC20 internal constant AAVE_STETH = IERC20(0x1982b2F5814301d4e9a8b0201555376e62F82428);
    ISaddlePool internal constant SADDLE_USD_POOL = ISaddlePool(0xC69DDcd4DFeF25D8a793241834d4cc4b3668EAD6);
    ISaddlePool internal constant SADDLE_ETH_POOL = ISaddlePool(0xa6018520EAACC06C30fF2e1B3ee2c7c22e64196a);
    IAlchemixStaking internal constant ALCHEMIX = IAlchemixStaking(0xAB8e74017a8Cc7c15FFcCd726603790d26d7DeCa);
    IAave internal constant AAVE = IAave(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
    ICurve internal constant CURVE_STETH_POOL = ICurve(0xDC24316b9AE028F1497c275EB9192a3Ea0f67022);
}