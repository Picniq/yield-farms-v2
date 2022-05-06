// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// solhint-disable var-name-mixedcase
interface IFraxStaking {
    struct LockedStake {
        bytes32 kek_id;
        uint256 start_timestamp;
        uint256 liquidity;
        uint256 ending_timestamp;
        uint256 lock_multiplier;
    }

    /* ===== View functions ===== */

    // Get unclaimed rewards
    function earned(address account) external view returns (uint256[] memory);

    // Get list of locked stakes
    function lockedStakesOf(address account)
        external
        view
        returns (LockedStake[] calldata);

    // Get total staked for account
    function lockedLiquidityOf(address account)
        external
        view
        returns (uint256);

    // Get token reward rates
    function rewardRates(uint256 index) external view returns (uint256);

    // Get reward token by index
    function rewardTokens(uint256 index) external view returns (uint256);

    // Get total contract rewards for each reward token
    function rewardsPerToken() external view returns (uint256[] memory);

    // Get total liquidity locked in contract
    function totalLiquidityLocked() external view returns (uint256);

    /* ===== Mutative functions ===== */

    // Claim reward
    function getReward() external;

    // Lock more Saddle LP tokens
    function stakeLocked(uint256 liquidity, uint256 secs) external;
    
    // Exit pool entirely. Claims rewards and withdraws all locked stakes
    function exit() external;

    // Withdraw from a particular lock by bytes32 hash id
    function withdrawLocked(bytes32 kek_id) external;
}
