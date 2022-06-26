// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ISaddleFarm {
    function deposit(uint256 amount) external;
    function claim_rewards(address receiver) external;
    function withdraw(uint256 value, bool claimRewards) external;
    function balanceOf(address account) external view returns (uint256);
}