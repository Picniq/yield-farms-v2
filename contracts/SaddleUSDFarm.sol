// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./Swaps.sol";
import "./Rewards.sol";
import "./interfaces/ISaddlePool.sol";
import "./interfaces/IFraxStaking.sol";
import "./interfaces/IAlchemixStaking.sol";
import "./interfaces/IERC20.sol";

/**
 * @author Picniq Finance
 * @title Saddle USD Stablecoin Farm
 * @notice Accepts user deposits in various stablecoins,
 * deposits as LP into Saddle, deposits Saddle LP into Frax,
 * and harvests rewards.
 */

/// TODO:
// Need to properly calculate rewards

// solhint-disable not-rely-on-time
contract StableUSDFarm is Swaps, Rewards {

    // Standard pool info
    address private _treasury;
    uint256 private _tokenFee;
    uint256 private _lowFeeDepositsPending;

    // Keep record of Frax deposit hashes
    mapping (bytes32 => uint256) private _lockedStakes;

    // Keep track of user deposits
    uint256 private _totalDeposits;
    mapping (address => UserDeposit) private _deposits;

    struct UserDeposit {
        uint256 deposits;
        uint256 depositTime;
    }

    constructor() {
        _treasury = msg.sender;
        _tokenFee = 20; // Add extra 0 for granularity... 20 = 2.0%

        // Give max approval to avoid user gas cost in future
        // ===== IS THIS DANGEROUS??? =====
        ALUSD.approve(address(saddleUSDPool), type(uint256).max);
        FEI.approve(address(saddleUSDPool), type(uint256).max);
        FRAX.approve(address(saddleUSDPool), type(uint256).max);
        LUSD.approve(address(saddleUSDPool), type(uint256).max);
        saddleUSDToken.approve(address(fraxPool), type(uint256).max);
        saddleUSDToken.approve(address(saddleUSDPool), type(uint256).max);
    }

    /* === VIEW FUNCTIONS === */

    /**
     * @dev External function to get treasury wallet address
     * @return treasury wallet address
     */
    function getTreasury() external view returns (address) {
        return _treasury;
    }

    /**
     * @dev Checks LP token return for deposit amount
     * @param amounts the array of stablecoin amounts to deposit
     * @return expected LP tokens from Saddle with 1% slippage
     */
    function getDepositAmount(uint256[] memory amounts) public view returns (uint256) {
        return saddleUSDPool.calculateTokenAmount(amounts, true) * 99 / 100;
    }

    /**
     * @dev Check value amount for user
     * @param account the address of the user to lookup
     * @return value the value of the user's deposit
     */
    function balanceOf(address account) external view returns (uint256) {
        // We take the user deposit total and multiply by the virtual price of the LP token
        return _deposits[account].deposits + _rewards[account] * saddleUSDPool.getVirtualPrice();
    }

    /**
     * @dev Checks if user can withdraw
     * @param account the address of the user to lookup
     * @return canRemove boolean value whether user can withdraw or not
     */
    function userCanWithdraw(address account) public view returns (bool) {
        return block.timestamp > _deposits[account].depositTime + 1 days;
    }

    /**
     * @dev Takes fee from token balances
     * @param balance amount to take fee from
     * @return output after-fee amount
     */
    function _takeFee(uint256 balance) private view returns (uint256) {
        // Check if token fee is 0 to protect against failure
        if (_tokenFee > 0) {
            // Balance - fee amount
            return balance - balance * _tokenFee / 1000;
        } else {
            return balance;
        }
    }

    /* === MUTATIVE FUNCTIONS === */

    /**
     * @dev For a 4% fee, sends tokens to the contract which others can deposit for part of fee
     * @param amounts the array of stablecoin amounts to deposit
     */
    function depositLowFee(uint256[] memory amounts) external {
        // Transfer tokens from user to contract as required
        if (amounts[0] > 0) {
            ALUSD.transferFrom(msg.sender, address(this), amounts[0]);
        }
        if (amounts[1] > 0) {
            FEI.transferFrom(msg.sender, address(this), amounts[1]);
        }
        if (amounts[2] > 0) {
            FRAX.transferFrom(msg.sender, address(this), amounts[2]);
        }
        if (amounts[3] > 0) {
            LUSD.transferFrom(msg.sender, address(this), amounts[3]);
        }

        // Do we need to track the virtual price to avoid sandwich attacks?
        uint256 expectedOutput = saddleUSDPool.calculateTokenAmount(amounts, true);
        _lowFeeDepositsPending = _lowFeeDepositsPending + expectedOutput;
        _deposits[msg.sender].deposits = _deposits[msg.sender].deposits + (expectedOutput * 5 / 100);
        // Additional 2 day lock to ensure it gets fully deposited
        _deposits[msg.sender].depositTime = block.timestamp + 2 days;
    }

    /**
     * @dev Performs main deposit action
     * @param amounts the array of stablecoin amounts to deposit
     * @param minToMint minimum expected LP output from Saddle
     */
    function deposit(uint256[] memory amounts, uint256 minToMint) external {
        // Transfer tokens from user to contract as required
        if (amounts[0] > 0) {
            ALUSD.transferFrom(msg.sender, address(this), amounts[0]);
        }
        if (amounts[1] > 0) {
            FEI.transferFrom(msg.sender, address(this), amounts[1]);
        }
        if (amounts[2] > 0) {
            FRAX.transferFrom(msg.sender, address(this), amounts[2]);
        }
        if (amounts[3] > 0) {
            LUSD.transferFrom(msg.sender, address(this), amounts[3]);
        }

        // Add liquidity and add Saddle output to user's total deposit amount
        uint256 output = saddleUSDPool.addLiquidity(amounts, minToMint, block.timestamp);
        _totalDeposits = _totalDeposits + output;
        _deposits[msg.sender].deposits += output;
        _deposits[msg.sender].depositTime = block.timestamp;
        // Lock for 1 day (Frax minimum)
        fraxPool.stakeLocked(output, 86400);
    }

    /**
     * @dev Allows users to withdraw their tokens
     * @param tokenIndex the token index in Saddle to remove. User can choose.
     * @param amount amount to withdraw. Must be less than or equal to deposit amount
     * @param expected amount expected to be returned from withdrawal
     * @param kekId we find the best kek_id to withdraw separately and pass it to this function
     */
    function withdraw(uint8 tokenIndex, uint256 amount, uint256 expected, bytes32 kekId) external {
        // Safety checks - funds not locked + funds within user deposit amount
        require(userCanWithdraw(msg.sender), "Funds still locked");
        require(amount <= _deposits[msg.sender].deposits, "Withdraw amount too high");

        uint256 priorBalance = saddleUSDToken.balanceOf(address(this));
        fraxPool.withdrawLocked(kekId);
        uint256 newBalance = saddleUSDToken.balanceOf(address(this));
        
        // Ensure the unlocked amount is greater than the amount to withdraw
        require(newBalance - priorBalance >= amount, "Did not withdraw enough");
        
        saddleUSDPool.removeLiquidityOneToken(amount, tokenIndex, expected, block.timestamp);
    }

    /**
     * @dev Harvests all outstanding rewards and reinvests
     */
    function harvest(uint256[] calldata expected) external {
        // Claim all rewards
        fraxPool.getReward();
        
        // Swap the reward tokens out for optimal stablecoins.
        // TO DO: Need to either transfer tokens to treasury or save balances to subtract from swap amount.
        uint lqtyBalance = LQTY.balanceOf(address(this));
        uint lqtyFee = _takeFee(lqtyBalance);
        LQTY.approve(address(uniswapRouterV2), lqtyBalance - lqtyFee);
        uint lqtyOutput = swapUsingUni(address(LQTY), address(FRAX), lqtyBalance - lqtyFee, expected[1], true);

        uint fxsBalance = FXS.balanceOf(address(this));
        uint fxsFee = _takeFee(fxsBalance);
        FXS.approve(address(uniswapRouterV2), fxsBalance - fxsFee);
        uint fxsOutput = swapUsingUni(address(FXS), address(FRAX), fxsBalance - fxsFee, expected[2], false);

        uint tribeBalance = TRIBE.balanceOf(address(this));
        uint tribeFee = _takeFee(tribeBalance);
        TRIBE.approve(address(uniswapRouterV2), tribeBalance - tribeFee);
        uint tribeOutput = swapUsingUni(address(TRIBE), address(FEI), tribeBalance - tribeFee, expected[3], false);

        uint256[] memory amounts = new uint256[](4);
        amounts[0] = 0;
        amounts[1] = lqtyOutput + fxsOutput;
        amounts[2] = tribeOutput;
        amounts[3] = 0;

        uint256 output = saddleUSDPool.addLiquidity(amounts, 0, block.timestamp);
        _totalDeposits += output;
    }

    /**
     * @dev Treasury-only function to adjust amount of ALCX that is staked
     * @param percent Percent of staked ALCX to sell and redeploy
     */
    function adjustAlchemixStake(uint256 percent) external onlyTreasury {
        uint256 staked = alPool.getStakeTotalDeposited(address(this), 1);
        alPool.withdraw(1, staked * percent / 100);
        uint256 balance = ALCX.balanceOf(address(this));
        ALCX.approve(address(sushiRouter), balance);
        uint256 output = swapUsingSushi(address(ALCX), address(ALUSD), balance, 0, true);
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = output;
        amounts[1] = 0;
        amounts[2] = 0;
        amounts[3] = 0;
        _deposit(amounts, 0, address(0));
    }

    function _deposit(uint256[] memory amounts, uint256 minToMint, address depositor) internal {
        // Add liquidity and add Saddle output to user's total deposit amount
        uint256 output = saddleUSDPool.addLiquidity(amounts, minToMint, block.timestamp);
        _totalDeposits = _totalDeposits + output;
        if (depositor != address(0)) {
            _deposits[msg.sender].deposits += output;
            _deposits[msg.sender].depositTime = block.timestamp;            
        }
        // Lock for 1 day (Frax minimum)
        fraxPool.stakeLocked(output, 86400);
        _saveLatestDeposit();
    }

    /**
     * @dev Perform Alchemix staking strategy for max rewards on our deposits.
     */
    function _performAlchemixStrategy() internal {
        uint alcxBalance = ALCX.balanceOf(address(this));
        uint treasuryFee = _takeFee(alcxBalance);
        ALCX.transfer(_treasury, treasuryFee);
        ALCX.approve(address(alPool), alcxBalance - treasuryFee);
        alPool.deposit(1, alcxBalance - treasuryFee);
    }

    /**
     * @dev Save latest Frax deposit hash (kek_id) to our own storage
     */
    function _saveLatestDeposit() internal {
        IFraxStaking.LockedStake[] memory lockedStakes = fraxPool.lockedStakesOf(address(this));
        _lockedStakes[lockedStakes[lockedStakes.length - 1].kek_id] = lockedStakes[lockedStakes.length - 1].liquidity;
    }

    /**
     * @dev Treasury-only function to claim SDL tokens from Saddle
     * @param poolId The Saddle pool id to claim tokens for
     */
    function claimSDL(uint poolId) external onlyTreasury {
        SDLClaim.harvest(poolId, _treasury);
    }

    /* === MODIFIER FUNCTIONS === */

    /**
     * @dev Enforce treasury-only requirement
     */
    modifier onlyTreasury {
        require(msg.sender == _treasury, "Not treasury account");
        _;
    }
}