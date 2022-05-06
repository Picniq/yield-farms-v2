// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IAlchemixStaking {
    // View functions
    function getStakeTotalDeposited(address account, uint256 poolId) external view returns (uint256);
    function getStakeTotalUnclaimed(address account, uint256 poolId) external view returns (uint256);

    // Mutative functions
    function deposit(uint256 poolId, uint256 depositAmount) external;
    function claim(uint256 poolId) external;
    function withdraw(uint256 poolId, uint256 withdrawAmount) external;
}