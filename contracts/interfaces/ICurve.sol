// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// solhint-disable func-name-mixedcase, var-name-mixedcase
interface ICurve { 
    function add_liquidity(uint256[2] calldata amounts, uint256 min_mint_amount) external returns (uint256);
    function remove_liquidity(uint256 _amount, uint256[2] calldata min_amounts) external returns (uint256[2] memory);
    function remove_liquidity_one_coin(uint256 _token_amount, int128 i, uint256 min_amount) external returns (uint256);
    function remove_liquidity_imbalance(uint256[2] calldata amounts, uint256 max_burn_amount) external returns (uint256);
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external payable returns (uint256);
    function calc_withdraw_one_coin(uint256 _token_amount, int128 i) external view returns (uint256);
    function calc_token_amount(uint256[2] calldata amounts, bool deposit) external view returns (uint256);
    function base_pool() external view returns (address);
    function get_virtual_price() external view returns (uint);
    function coins(uint256 i) external view returns (address);
}