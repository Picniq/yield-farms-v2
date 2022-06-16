// SPDX-License-Identifier: MIT

pragma solidity 0.8.14;

import "./Swaps.sol";
import "./Addresses.sol";
import "./VERC20.sol";
import "./Context.sol";
import "./libraries/FixedPointMath.sol";
import "./interfaces/ISaddlePool.sol";
import "./interfaces/IAlchemixStaking.sol";
import "./interfaces/IERC20.sol";

/**
 * @author Picniq Finance
 * @title Saddle USD Stablecoin Farm
 * @notice Accepts user deposits in various stablecoins,
 * deposits as LP into Saddle, deposits Saddle LP into Frax,
 * and harvests rewards.
 *
 * TODO: Add treasury fees.
 */

// solhint-disable not-rely-on-time
contract StableFarm is VERC20, Swaps {
    using FixedPointMath for uint256;

    uint256 private _fee;
    address private _treasurer;

    constructor() VERC20 ("Saddle USD Farm", "pUSDFarm") {
        _treasurer = msg.sender;
        // Give max approval to avoid user gas cost in future
        // ===== IS THIS DANGEROUS??? =====
        ALCX.approve(address(saddleUSDPool), type(uint256).max);
        FEI.approve(address(saddleUSDPool), type(uint256).max);
        FRAX.approve(address(saddleUSDPool), type(uint256).max);
        LUSD.approve(address(saddleUSDPool), type(uint256).max);
        saddleUSDToken.approve(address(saddleUSDPool), type(uint256).max);
    }

    modifier onlyTreasury()
    {
        require(msg.sender == _treasurer, "Not treasurer");
        _;
    }

    /* === VIEW FUNCTIONS === */

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

    /**
     * @dev Calculate total assets managed
     * @return totalManagedAssets total amount of underlying assets
     */
    function _totalAssets() private view returns (uint256)
    {
        return saddleUSDToken.balanceOf(address(this));
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
        return convertToAssets(_balances[owner]);
    }

    /**
     * @dev Maximum redemption allowed
     * @return maxRedemption maximum share redemption amount
     */
    function maxRedemption(address owner) external view returns (uint256)
    {
        return _balances[owner];
    }

    /* ################################
    ############# UNIQUE ##############
    ################################ */

    function getTreasury() external view returns (address)
    {
        return _treasurer;
    }

    /* === MUTATIVE FUNCTIONS === */
    
    /* ################################
    ######### ERC4626 Support #########
    ################################ */

    /**
     * @dev Allow user to send any supported stablecoin
     * @param amounts an array of amounts to deposit to Saddle
     * @param minToMint off-chain check to minimize slippage
     * @param receiver the receiving address to pass shares to
     * @return shares amount of vault shares to mint
     */
    function depositStable(uint256[] calldata amounts, uint256 minToMint, address receiver) external returns (uint256)
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

       return _deposit(output, sender, receiver);
        
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
     * @dev Performs main deposit logic
     * @param assets the LP tokens to deposit
     * @param sender the sending address
     * @param receiver the address receiving shares
     * @return shares amount of vault shares to mint
     */
    function _deposit(uint256 assets, address sender, address receiver) private returns (uint256)
    {
        uint256 shares = previewDeposit(assets);

        require(shares != 0, "Zero shares");

        // Mint shares and send to receiver address
        _mint(receiver, shares);

        emit Deposit(sender, receiver, assets, shares);

        // afterDeposit(assets, shares);

        return shares;
    }

    /**
     * @dev Allow user to withdraw their LP tokens directly
     * @param assets amount of assets to withdraw
     * @param receiver account to send LP tokens to
     * @param owner the owner of the assets
     *
     * @return shares amount of shares burned
     */
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256)
    {
        uint256 shares = _withdraw(assets, receiver, owner);

        return shares;
    }

    /**
     * @dev Redeem shares for LP tokens
     *
     * @param shares amount of shares to redeem
     * @param receiver the address to receive LP tokens
     * @param owner the owner of the shares
     *
     * @return assets the amount of LP tokens redeemed from shares
     */
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256)
    {
        if (msg.sender != owner) {
            uint256 allowed = _allowances[owner][msg.sender];
            if (allowed != type(uint256).max) {
                _allowances[owner][msg.sender] = allowed - shares;
            }
        }

        uint256 assets = previewRedeem(shares);

        require(assets != 0, "No assets");

        // beforeWithdraw(assets, shares);

        // _burn(owner, shares);

        _withdraw(assets, receiver, owner);

        return assets;
    }

    function redeem(uint256 shares, address receiver, address owner, uint256 minAmount, uint8 tokenIndex) external returns (uint256)
    {
        if (msg.sender != owner) {
            uint256 allowed = _allowances[owner][msg.sender];
            if (allowed != type(uint256).max) {
                _allowances[owner][msg.sender] = allowed - shares;
            }
        }

        uint256 assets = previewRedeem(shares);

        require(assets != 0, "No assets");

        _burn(owner, shares);
        _withdrawStable(receiver, assets, minAmount, tokenIndex);
        
        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        return assets;
    }

    function withdraw(uint256 assets, address receiver, address owner, uint256 minAmount, uint8 tokenIndex) external returns (uint256)
    {
        uint256 shares = convertToShares(assets);

        _burn(owner, shares);
        _withdrawStable(receiver, assets, minAmount, tokenIndex);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        
        return shares;
    }

    /**
     * @dev Perform withdrawal logic
     *
     * @param assets amount of assets to withdraw
     * @param receiver account to send LP tokens to
     * @param owner the owner of the assets
     *
     * @return shares the amount of vault shares to burn
     */
    function _withdraw(uint256 assets, address receiver, address owner) private returns (uint256)
    {
        uint256 shares = previewWithdraw(assets);
        address sender = _msgSender();

        if (sender != owner) {
            uint256 allowed = _allowances[owner][sender];

            if (allowed != type(uint256).max) {
                _allowances[owner][sender] = allowed - shares;
            }
        }

        uint256 vaultBalance = saddleUSDToken.balanceOf(address(this));

        require(vaultBalance >= assets, "Not enough assets");

        // beforeWithdraw(assets, shares);

        _burn(owner, shares);

        saddleUSDToken.transfer(receiver, assets);

        emit Withdraw(_msgSender(), receiver, owner, assets, shares);

        return shares;
    }

    /**
     * @dev Withdraws stablecoins from Saddle
     *
     * @param receiver address to receive stablecoins
     * @param tokenAmount amount of LP tokens to redeem
     * @param minAmount minimum stablecoin amount to receive
     * @param tokenIndex preferred stablecoin to withdraw from Saddle
     *
     * @return output the amount of stables withdrawn from Saddle
     */
    function _withdrawStable(address receiver, uint256 tokenAmount, uint256 minAmount, uint8 tokenIndex) private returns (uint256)
    {
        uint256 output = saddleUSDPool.removeLiquidityOneToken(tokenAmount, tokenIndex, minAmount, block.timestamp);
        
        if (tokenIndex == 0) {
            ALUSD.transfer(receiver, output);
        }
        if (tokenIndex == 1) {
            FEI.transfer(receiver, output);
        }
        if (tokenIndex == 2) {
            FRAX.transfer(receiver, output);
        }
        if (tokenIndex == 3) {
            LUSD.transfer(receiver, output);
        }

        return output;
    }

    /**
     * @dev Mints shares  
     */
    function mint(uint256 shares, address receiver) external returns (uint256)
    {
        uint256 assets = previewMint(shares);
        saddleUSDToken.transferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);

        return assets;
    }

    /**
     * @dev Peforms minting logic
     * @param account the account to mint shares for
     * @param shares the amount of shares to mint
     */
    function _mint(address account, uint256 shares) private
    {
        require(account != address(0), "ERC20: Mint to zero addr");

        // _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += shares;
        _balances[account] += shares;

        emit Transfer(address(0), account, shares);

        // _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Performs burning logic
     * @param account the account to burn shares from
     * @param shares the amount of shares to burn
     */
    function _burn(address account, uint256 shares) private
    {
        require(account != address(0), "ERC20: burn from zero address");

        // _beforeTokenTransfer(account, address(0), shares);

        uint256 balance = _balances[account];
        
        require(balance >= shares, "ERC20: burn exceeds balance");

        unchecked {
            _balances[account] = balance - shares;
        }

         _totalSupply -= shares;

        emit Transfer(account, address(0), shares);

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

    /* ################################
    ############# EVENTS ##############
    ################################ */

    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);
}