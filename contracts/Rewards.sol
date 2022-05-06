// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

abstract contract Rewards {

    uint256 public periodFinish;
    uint256 public rewardRate;
    uint256 public rewardsDuration;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 internal _totalRewards;
    
    mapping(address => uint256) internal _userRewardPerTokenPaid;
    mapping(address => uint256) internal _rewards;
}