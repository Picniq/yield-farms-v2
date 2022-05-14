// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "hardhat/console.sol";
import "./Swaps.sol";
import "./Rewards.sol";
import "./Addresses.sol";
import "./Context.sol";
import "./libraries/FixedPointMath.sol";
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
 *
 * TODO: Fix redeem vs withdraw issues
 */

contract StableFarm is Swaps, Rewards, Context {
    using FixedPointMath for uint256;

    // Standard pool info
    uint256 private _totalSupply;
    uint256 private _fee;
    address private _treasurer;

    // Keep track of user deposits
    mapping (address => UserDeposit) private _deposits;
    mapping (address => mapping (address => uint256 )) private _allowances;

    struct UserDeposit {
        uint256 deposits;
        uint256 depositTime;
    }

    struct Kek {
        bytes32 kekId;
    }

    constructor() {
        _treasurer = _msgSender();
        // Give max approval to avoid user gas cost in future
        // ===== IS THIS DANGEROUS??? =====
        ALUSD.approve(address(saddleUSDPool), type(uint256).max);
        FEI.approve(address(saddleUSDPool), type(uint256).max);
        FRAX.approve(address(saddleUSDPool), type(uint256).max);
        LUSD.approve(address(saddleUSDPool), type(uint256).max);
        saddleUSDToken.approve(address(fraxPool), type(uint256).max);
        saddleUSDToken.approve(address(saddleUSDPool), type(uint256).max);
    }

    modifier onlyTreasury()
    {
        require(_msgSender() == _treasurer, "Not treasurer");
        _;
    }

    /* === VIEW FUNCTIONS === */

    /* ################################
    ########## ERC20 Support ##########
    ################################ */

    /**
     * @dev Name
     * @return name return vault name
     */
    function name() external pure returns (string memory)
    {
        return "Picniq Saddle/Frax USD Farm";
    }

    /**
     * @dev Symbol
     * @return symbol return vault symbol   
     */
    function symbol() external pure returns (string memory)
    {
        return "picniqSaddleFraxUSDFarm";
    }

    /**
     * @dev Decimals
     * @return decimals return vault token decimals
     */
    function decimals() external pure returns (uint256)
    {
        return 18;
    }

    /**
     * @dev User account balance
     * @param account the account to look up
     * @return balance account balance
     */
    function balanceOf(address account) external view returns (uint256)
    {
        return _deposits[account].deposits;
    }

    /**
     * @dev Check token spending allowance
     * @param owner the owner of the tokens
     * @param spender the spender of the tokens
     * @return allowance amount spender is approved to spend
     */
    function allowance(address owner, address spender) external view returns (uint256)
    {
        return _allowances[owner][spender];
    }

    /* ################################
    ######### ERC4626 Support #########
    ################################ */

    /**
     * @dev Underlying asset
     * @return assetTokenAddress return underlying asset
     */
    function asset() external view returns (address)
    {
        return address(saddleUSDToken);
    }

    /**
     * @dev Total assets managed
     * @return totalManagedAssets total amount of underlying assets
     */
    function totalAssets() external view returns (uint256)
    {
        return _totalAssets();
    }

    function _totalAssets() private view returns (uint256)
    {
        return fraxPool.lockedLiquidityOf(address(this)) + saddleUSDToken.balanceOf(address(this));
    }

    /**
     * @dev Convert assets to vault shares
     * @param assets the amount to convert
     * @return shares the shares converted from input
     */
    function convertToShares(uint256 assets) public view returns (uint256)
    {
        uint256 supply = _totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? assets : assets.mulDivDown(supply, _totalAssets());
    }

    /**
     * @dev Convert vault shares to assets
     * @param shares the amount to convert
     * @return assets the assets converted from shares
     */
    function convertToAssets(uint256 shares) public view returns (uint256)
    {
        uint256 supply = _totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? shares : shares.mulDivDown(_totalAssets(), supply);
    }

    /**
     * @dev Preview deposit amount
     * @param assets the amount of assets to deposit
     * @return shares the amount of shares to return
     */
    function previewDeposit(uint256 assets) public view returns (uint256)
    {
        return convertToShares(assets);
    }

    /**
     * @dev Preview mint amount
     * @param shares the amount of shares
     * @return mintAmount the amount to mint
     */
    function previewMint(uint256 shares) public view returns (uint256)
    {
        uint256 supply = _totalSupply;

        return supply == 0 ? shares : shares.mulDivUp(_totalAssets(), supply);
    }

    /**
     * @dev Preview withdraw and return expected shares to burn
     * @param assets the amount of assets
     * @return amountToWithdraw the amount of shares from the asset
     */
    function previewWithdraw(uint256 assets) public view returns (uint256)
    {
        uint256 supply = _totalSupply;

        return supply == 0 ? assets : assets.mulDivUp(supply, _totalAssets());
    }

    /**
     * @dev Preview redemption and return expected amount of assets
     * @return assets returns amount of assets in return for shares
     */
    function previewRedeem(uint256 shares) public view returns (uint256)
    {
        return convertToAssets(shares);
    }

    /**
     * @dev Maximum deposit allowed
     * @return maxDeposit maximum deposit amount
     */
    function maxDeposit(address) external pure returns (uint256)
    {
        return type(uint256).max;
    }

    /**
     * @dev Maximum mint allowed
     * @return maxMint maximum mint amount
     */
    function maxMint(address) external pure returns (uint256)
    {
        return type(uint256).max;
    }

    /**
     * @dev Maximum withdrawal allowed
     * @return maxWithdraw maximum withdraw amount
     */
    function maxWithdrawal(address owner) external view returns (uint256)
    {
        return convertToAssets(_deposits[owner].deposits);
    }

    /**
     * @dev Maximum redemption allowed
     * @return maxRedemption maximum share redemption amount
     */
    function maxRedemption(address owner) external view returns (uint256)
    {
        return _deposits[owner].deposits;
    }

    /* ################################
    ############# UNIQUE ##############
    ################################ */

    function getBestWithdrawal(uint256 assets) public view returns (bytes32[] memory)
    {
        IFraxStaking.LockedStake[] memory stakes = fraxPool.lockedStakesOf(address(this));
        uint256 combinedAssets;
        uint256 totalKeks;
        bytes32[] memory keks = new bytes32[](4);

        require(stakes.length > 0, "No stakes");

        for (uint256 i = 0; i < stakes.length;) {
            if (stakes[i].ending_timestamp <= block.timestamp) {
                combinedAssets += stakes[i].liquidity;
                keks[totalKeks] = stakes[i].kek_id;
                totalKeks += 1;
                if (combinedAssets >= assets) {
                    bytes32[] memory returnKeks = new bytes32[](totalKeks);
                    for (uint256 index = 0; index < totalKeks;) {
                        returnKeks[index] = keks[index];
                        unchecked { ++index; }
                    }
                    return returnKeks;
                }
            }
            unchecked { ++i; }
        }

        return keks;
    }

    function userCanWithdraw(address account) public view returns (bool)
    {
        return block.timestamp > _deposits[account].depositTime + 1 days;
    }

    function getTreasury() external view returns (address)
    {
        return _treasurer;
    }

    /* === MUTATIVE FUNCTIONS === */

    /* ################################
    ########## ERC20 Support ##########
    ################################ */

    /**
     * @dev Transfer tokens between accounts
     * @param to the destination address
     * @param amount the amount to send
     */
    function transfer(address to, uint256 amount) external returns (bool)
    {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev Transfers tokens on behalf of address
     * @param from the spending address
     * @param to the receiving address
     * @param amount the amount to spend
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool)
    {
        address spender = _msgSender();

        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        
        return true;
    }

    /**
     * @dev Approves an address to spend tokens
     * @param spender the spending address
     * @param amount the amount to approve
     *
     * @notice sending max uint256 will negate allowance checks in future (i.e. infinite)
     */
    function approve(address spender, uint256 amount) external returns (bool)
    {
        address owner = _msgSender();

        _approve(owner, spender, amount);

        return true;
    }

    /**
     * @dev Increases allowances by amount
     * @param spender the spending address
     * @param addedValue the amount to increase
     */
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        address owner = _msgSender();

        _approve(owner, spender, _allowances[owner][spender] + addedValue);

        return true;
    }

    /**
     * @dev Decreases allowances by amount
     * @param spender the spending address
     * @param subtractedValue the amount to decrease
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool)
    {
        address owner = _msgSender();
        uint256 currentAllowance = _allowances[owner][spender];

        require(currentAllowance >= subtractedValue, "ERC20: decrease below zero");

        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Transfers tokens
     * @param from account to send from
     * @param to account to send to
     * @param amount amount to send
     *
     * @notice This contract requires a 1 day token lock... this function
     * current disallows transfers until lock is up. Is there a better way?
     */
    function _transfer(address from, address to, uint256 amount) private
    {
        require(from != address(0), "ERC20: transfer from zero addr");
        require(to != address(0), "ERC20: transfer to zero addr");

        // _beforeTokenTransfer(from, to, amount);
        
        uint256 fromBalance = _deposits[from].deposits;
        uint256 fromLock = _deposits[from].depositTime;

        require(fromBalance >= amount, "ERC20: Amount exceeds balance");
        require(block.timestamp > fromLock + 86400, "Deposit still locked");

        unchecked {
            _deposits[from].deposits = fromBalance - amount;
        }

        _deposits[to].deposits += amount;

        // emit Transfer(from, to, amount);

        // _afterTokenTransfer(from, to, amount);
    }

    /**
     * @dev Approves a spender
     * @param owner the owner of the tokens
     * @param spender the spending address
     * @param amount the amount to approve spender for
     */
    function _approve(address owner, address spender, uint256 amount) private
    {
        require(owner != address(0), "ERC20: approve from zero addr");
        require(spender != address(0), "ERC20: approve to zero addr");

        _allowances[owner][spender] = amount;

        // emit Approval(owner, spender, amount);
    }

    /**
     * @dev Spends allowance
     * @param owner the owner of the tokens
     * @param spender the spending address
     * @param amount the amount to deduct from allowance
     */
    function _spendAllowance(address owner, address spender, uint256 amount) private
    {
        uint256 currentAllowance = _allowances[owner][spender];

        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: Insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }
    
    /* ################################
    ######### ERC4626 Support #########
    ################################ */

    /**
     * @dev Allow user to send any supported stablecoin
     * @param amounts an array of amounts to deposit to Saddle
     * @param minToMint off-chain check to minimize slippage
     * @param receiver the receiving address to pass shares to
     */
    function depositStable(uint256[] calldata amounts, uint256 minToMint, address receiver) external
    {
        address sender = _msgSender();

        // Transfer tokens from user to contract as required
        if (amounts[0] > 0) {
            ALUSD.transferFrom(sender, address(this), amounts[0]);
        }
        if (amounts[1] > 0) {
            FEI.transferFrom(sender, address(this), amounts[1]);
        }
        if (amounts[2] > 0) {
            FRAX.transferFrom(sender, address(this), amounts[2]);
        }
        if (amounts[3] > 0) {
            LUSD.transferFrom(sender, address(this), amounts[3]);
        }

        uint256 output = saddleUSDPool.addLiquidity(amounts, minToMint, block.timestamp);

        _deposit(output, sender, receiver);
        
    }

    /**
     * @dev Allow user to deposit Saddle USD LP tokens directly
     * @param assets amount of LP tokens to deposit
     * @param receiver the receiving address
     */
    function deposit(uint256 assets, address receiver) public returns (uint256)
    {
        address sender = _msgSender();

        saddleUSDToken.transferFrom(sender, address(this), assets);
        return _deposit(assets, sender, receiver);
    }

    /**
     * @dev Allow user to withdraw their LP tokens directly
     * @param assets amount of assets to withdraw
     * @param receiver account to send LP tokens to
     * @param owner the owner of the assets
     *
     * @notice It is potentially far more gas efficient to lookup the ideal
     * kekId manually and provide it to the withdrawId function.
     * This function is to provide ERC4626 compatibility.
     */
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256)
    {
        bytes32[] memory kekIds = getBestWithdrawal(assets);
        return _withdraw(assets, receiver, owner, kekIds, 0);
    }

    /**
     * @dev Perform withdrawal logic
     *
     * @param assets amount of assets to withdraw
     * @param receiver account to send LP tokens to
     * @param owner the owner of the assets
     * @param kekIds the kekIds to withdraw from Frax
     * @param tokenIndex the stablecoin id to withdraw from Saddle
     */
    function _withdraw(uint256 assets, address receiver, address owner, bytes32[] memory kekIds, uint8 tokenIndex) private returns (uint256)
    {
        require(tokenIndex < 4, "Token id must be 0-3");

        for (uint256 i = 0; i < kekIds.length;) {
            fraxPool.withdrawLocked(kekIds[i]);
            unchecked { ++i; }
        }

        uint256 shares = previewWithdraw(assets);

        if (_msgSender() != owner) {
            uint256 allowed = _allowances[owner][_msgSender()];

            if (allowed != type(uint256).max) {
                _allowances[owner][_msgSender()] = allowed - shares;
            }
        }

        uint256 vaultBalance = saddleUSDToken.balanceOf(address(this));

        require(vaultBalance >= assets, "Not enough assets");

        // beforeWithdraw(assets, shares);

        _burn(owner, shares);

        // emit Withdraw(_msgSender(), receiver, owner, assets, shares);

        saddleUSDPool.removeLiquidityOneToken(assets, tokenIndex, 0, block.timestamp);

        uint256 stableBalance;
        if (tokenIndex == 0) {
            stableBalance = ALUSD.balanceOf(address(this));
            ALUSD.transfer(receiver, stableBalance);
        }
        if (tokenIndex == 1) {
            stableBalance = FEI.balanceOf(address(this));
            FEI.transfer(receiver, stableBalance);
        }
        if (tokenIndex == 2) {
            stableBalance = FRAX.balanceOf(address(this));
            FRAX.transfer(receiver, stableBalance);
        }
        if (tokenIndex == 3) {
            stableBalance = LUSD.balanceOf(address(this));
            LUSD.transfer(receiver, stableBalance);
        }

        // fraxPool.stakeLocked(vaultBalance - assets, 86400);

        return shares;
    }

    /**
     * @dev Performs main deposit logic
     * @param assets the LP tokens to deposit
     * @param sender the sending address
     * @param receiver the address receiving shares
     */
    function _deposit(uint256 assets, address sender, address receiver) private returns (uint256)
    {
        uint256 shares = previewDeposit(assets);

        require(shares != 0, "Zero shares");
        
        fraxPool.stakeLocked(assets, 86400);

        // Mint shares and send to receiver address
        _mint(receiver, shares);

        // emit Deposit(sender, receiver, assets, shares);

        // afterDeposit(assets, shares);

        return shares;
    }

    /**
     * @dev Peforms minting logic
     * @param account the account to mint shares for
     * @param shares the amount of shares to mint
     */
    function _mint(address account, uint256 shares) private returns (uint256)
    {
        require(account != address(0), "ERC20: Mint to zero addr");

        uint256 assets = previewMint(shares);

        // _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += shares;
        _deposits[account].deposits += shares;
        _deposits[account].depositTime = block.timestamp;

        // emit Transfer(address(0), account, shares);

        // _afterTokenTransfer(address(0), account, amount);

        return assets;
    }

    /**
     * @dev Performs burning logic
     * @param account the account to burn shares from
     * @param shares the amount of shares to burn
     */
    function _burn(address account, uint256 shares) private
    {
        require(account != address(0), "ERC20: burn from zero address");
        require(block.timestamp >= _deposits[account].depositTime, "Deposit still locked");

        // _beforeTokenTransfer(account, address(0), shares);

        uint256 balance = _deposits[account].deposits;

        require(balance >= shares, "ERC20: burn exceeds balance");

        unchecked {
            _deposits[account].deposits = balance - shares;
        }

        // If account no longer has shares, do we need to reset deposit time?
        if (_deposits[account].deposits == 0) {
            _deposits[account].depositTime = 0;
        }

         _totalSupply -= shares;

        // emit Transfer(account, address(0), shares);

        // _afterTokenTransfer(account, address(0), shares);
    }

    /* ################################
    ############# UNIQUE ##############
    ################################ */

    function harvest(uint256[] calldata expected) external onlyTreasury
    {
        fraxPool.getReward();

        uint256 alcxBalance = ALCX.balanceOf(address(this));
        ALCX.approve(address(sushiRouter), alcxBalance);
        uint256 alcxOutput = swapUsingSushi(address(ALCX), address(ALUSD), alcxBalance, expected[0], true);
        
        uint256 lqtyBalance = LQTY.balanceOf(address(this));
        LQTY.approve(address(uniswapRouterV2), lqtyBalance);
        uint256 lqtyOutput = swapUsingUni(address(LQTY), address(FRAX), lqtyBalance, expected[1], true);

        uint256 fxsBalance = FXS.balanceOf(address(this));
        FXS.approve(address(uniswapRouterV2), fxsBalance);
        uint256 fxsOutput = swapUsingUni(address(FXS), address(FRAX), fxsBalance, expected[2], false);

        uint256 tribeBalance = TRIBE.balanceOf(address(this));
        TRIBE.approve(address(uniswapRouterV2), tribeBalance);
        uint256 tribeOutput = swapUsingUni(address(TRIBE), address(FEI), tribeBalance, expected[3], false);

        uint256[] memory amounts = new uint256[](4);
        amounts[0] = alcxOutput;
        amounts[1] = tribeOutput;
        amounts[2] = lqtyOutput + fxsOutput;
        amounts[3] = 0;
        
        uint256 output = saddleUSDPool.addLiquidity(amounts, 0, block.timestamp);
        fraxPool.stakeLocked(output, 86400);
    }

    function claimSDL(uint256 poolId) external onlyTreasury
    {
        SDLClaim.harvest(poolId, _treasurer);
    }
}