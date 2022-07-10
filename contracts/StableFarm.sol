// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "./libraries/Swaps.sol";
import "./libraries/Addresses.sol";
import "./VERC20.sol";
import "./Context.sol";
import "./libraries/FixedPointMath.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ISaddleFarm.sol";
import "./interfaces/IGauge.sol";

/**
 * @author Picniq Finance
 * @title Saddle USD Stablecoin Farm
 * @notice Accepts user deposits in various stablecoins,
 * deposits as LP into Saddle and stakes LP tokens to earn
 * SDL rewards, reinvesting those SDL rewards.
 */

// solhint-disable not-rely-on-time
contract StableFarm is VERC20 {
    using FixedPointMath for uint256;

    uint256 private _fee = 5e15; // 0.5% fee on deposits
    address private _treasurer;

    ISaddleFarm private _saddleFarm = ISaddleFarm(0x13Ba45c2B686c6db7C2E28BD3a9E8EDd24B894eD);
    IGauge private _gauge = IGauge(0x358fE82370a1B9aDaE2E3ad69D6cF9e503c96018);
    IERC20 private constant SDL = IERC20(0xf1Dc500FdE233A4055e25e5BbF516372BC4F6871);

    constructor() VERC20 ("Saddle USD Farm", "pUSDFarm") {
        _treasurer = msg.sender;
        // Give max approval to avoid user gas cost in future
        // ===== IS THIS DANGEROUS??? =====
        Addresses.USDC.approve(address(Addresses.SADDLE_USD_POOL), type(uint256).max);
        // Addresses.USDT.approve(address(Addresses.SADDLE_USD_POOL), type(uint256).max);
        Addresses.FRAX.approve(address(Addresses.SADDLE_USD_POOL), type(uint256).max);
        SDL.approve(address(Swaps.SUSHI_ROUTER), type(uint256).max);
        Addresses.SADDLE_USD_TOKEN.approve(address(Addresses.SADDLE_USD_POOL), type(uint256).max);
        Addresses.SADDLE_USD_TOKEN.approve(address(_saddleFarm), type(uint256).max);
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
     *
     * @return assetTokenAddress return underlying asset
     */
    function asset() external pure returns (address)
    {
        return address(Addresses.SADDLE_USD_TOKEN);
    }

    /**
     * @dev Total assets managed
     *
     * @return totalManagedAssets total amount of underlying assets
     */
    function totalAssets() external view returns (uint256)
    {
        return _totalAssets();
    }

    /**
     * @dev Calculate total assets managed
     *
     * @return totalManagedAssets total amount of underlying assets
     */
    function _totalAssets() private view returns (uint256)
    {
        return _saddleFarm.balanceOf(address(this));
    }

    /**
     * @dev Convert assets to vault shares
     *
     * @param assets the amount to convert
     *
     * @return shares the shares converted from input
     */
    function convertToShares(uint256 assets) public view returns (uint256)
    {
        uint256 supply = _totalSupply;

        return supply == 0 ? assets : assets.mulDivDown(supply, _totalAssets());
    }

    /**
     * @dev Convert vault shares to assets
     *
     * @param shares the amount to convert
     *
     * @return assets the assets converted from shares
     */
    function convertToAssets(uint256 shares) public view returns (uint256)
    {
        uint256 supply = _totalSupply;

        return supply == 0 ? shares : shares.mulDivDown(_totalAssets(), supply);
    }

    /**
     * @dev Preview deposit amount
     *
     * @param assets the amount of assets to deposit
     *
     * @return shares the amount of shares to return
     */
    function previewDeposit(uint256 assets) public view returns (uint256)
    {
        return convertToShares(assets);
    }

    /**
     * @dev Preview mint amount
     *
     * @param shares the amount of shares
     *
     * @return mintAmount the amount to mint
     */
    function previewMint(uint256 shares) public view returns (uint256)
    {
        uint256 supply = _totalSupply;

        return supply == 0 ? shares : shares.mulDivUp(_totalAssets(), supply);
    }

    /**
     * @dev Preview withdraw and return expected shares to burn
     *
     * @param assets the amount of assets
     *
     * @return amountToWithdraw the amount of shares from the asset
     */
    function previewWithdraw(uint256 assets) public view returns (uint256)
    {
        uint256 supply = _totalSupply;

        return supply == 0 ? assets : assets.mulDivUp(supply, _totalAssets());
    }

    /**
     * @dev Preview redemption and return expected amount of assets
     *
     * @return assets returns amount of assets in return for shares
     */
    function previewRedeem(uint256 shares) public view returns (uint256)
    {
        return convertToAssets(shares);
    }

    /**
     * @dev Maximum deposit allowed
     *
     * @return maxDeposit maximum deposit amount
     */
    function maxDeposit(address) external pure returns (uint256)
    {
        return type(uint256).max;
    }

    /**
     * @dev Maximum mint allowed
     *
     * @return maxMint maximum mint amount
     */
    function maxMint(address) external pure returns (uint256)
    {
        return type(uint256).max;
    }

    /**
     * @dev Maximum withdrawal allowed
     *
     * @return maxWithdraw maximum withdraw amount
     */
    function maxWithdrawal(address owner) external view returns (uint256)
    {
        return convertToAssets(_balances[owner]);
    }

    /**
     * @dev Maximum redemption allowed
     *
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

    function _takeFee(uint256 amount) private view returns (uint256)
    {
        if (_fee > 0) {
           return amount * _fee / 1e18; 
        } else {
            return 0;
        }
    }

    /* === MUTATIVE FUNCTIONS === */
    
    /* ################################
    ######### ERC4626 Support #########
    ################################ */

    /**
     * @dev Allow user to send any supported stablecoin
     *
     * @param amounts an array of amounts to deposit to Saddle
     * @param minToMint off-chain check to minimize slippage
     * @param receiver the receiving address to pass shares to
     *
     * @return shares amount of vault shares to mint
     */
    function depositStable(uint256[] calldata amounts, uint256 minToMint, address receiver) external returns (uint256)
    {
        address sender = _msgSender();

        // Transfer tokens from user to contract as required
        if (amounts[0] > 0) {
            Addresses.USDC.transferFrom(sender, address(this), amounts[0]);
        }
        if (amounts[1] > 0) {
            Addresses.USDT.transferFrom(sender, address(this), amounts[1]);
        }
        if (amounts[2] > 0) {
            Addresses.FRAX.transferFrom(sender, address(this), amounts[2]);
        }

        uint256 output = Addresses.SADDLE_USD_POOL.addLiquidity(amounts, minToMint, block.timestamp);

       return _deposit(output, sender, receiver);
    }

    /**
     * @dev Allow user to deposit Saddle USD LP tokens directly
     *
     * @param assets amount of LP tokens to deposit
     * @param receiver the receiving address
     *
     * @return shares Returns the amount of vault shares minted
     */
    function deposit(uint256 assets, address receiver) public returns (uint256)
    {
        address sender = _msgSender();

        Addresses.SADDLE_USD_TOKEN.transferFrom(sender, address(this), assets);
        return _deposit(assets, sender, receiver);
    }

    /**
     * @dev Performs main deposit logic
     *
     * @param assets the LP tokens to deposit
     * @param sender the sending address
     * @param receiver the address receiving shares
     *
     * @return shares amount of vault shares to mint
     */
    function _deposit(uint256 assets, address sender, address receiver) private returns (uint256)
    {
        uint256 shares = previewDeposit(assets);

        require(shares != 0, "Zero shares");

        _saddleFarm.deposit(assets);

        uint256 fee = _takeFee(shares);

        // Mint shares and send to receiver address
        _mint(receiver, shares - fee);

        if (fee > 0) {
            _mint(_treasurer, fee);    
        }
        
        emit Deposit(sender, receiver, assets, shares);

        // afterDeposit(assets, shares);

        return shares;
    }

    /**
     * @dev Allow user to withdraw their LP tokens directly
     *
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

    /**
     * @dev Redeem function passing a preferred stablecoin to receive
     *
     * @param shares Amount of shares to redeem for assets
     * @param receiver The receiver of the redeemed assets
     * @param owner The owner of the shares
     * @param minAmount The minimum amount of token to receive
     * @param tokenIndex The token index to withdraw from Saddle
     *
     * @return assets Returns the total amount of assets redeemed.
     */
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

    /**
     * @dev Withdraw function passing preferred stablecoin to receive
     *
     * @param assets The amount of assets to withdraw from vault
     * @param receiver The receiver of the redeemed assets
     * @param owner The owner of the shares currently
     * @param minAmount The minimum amount of stablecoin receive
     * @param tokenIndex The token index of the preferred stablecoin from Saddle
     *
     * @return shares The amount of shares burned in this withdrawal
     */
    function withdraw(uint256 assets, address receiver, address owner, uint256 minAmount, uint8 tokenIndex) external returns (uint256)
    {
        uint256 shares = convertToShares(assets);

        _burn(owner, shares);
        _saddleFarm.withdraw(assets, false);
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

        _saddleFarm.withdraw(assets, false);

        uint256 vaultBalance = Addresses.SADDLE_USD_TOKEN.balanceOf(address(this));

        require(vaultBalance >= assets, "Not enough assets");

        // beforeWithdraw(assets, shares);

        _burn(owner, shares);

        Addresses.SADDLE_USD_TOKEN.transfer(receiver, assets);

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
        uint256 output = Addresses.SADDLE_USD_POOL.removeLiquidityOneToken(tokenAmount, tokenIndex, minAmount, block.timestamp);
        
        if (tokenIndex == 0) {
            Addresses.USDC.transfer(receiver, output);
        }
        if (tokenIndex == 1) {
            Addresses.USDT.transfer(receiver, output);
        }
        if (tokenIndex == 2) {
            Addresses.FRAX.transfer(receiver, output);
        }

        return output;
    }

    /**
     * @dev Mints shares
     *
     * @param shares The amount of shares to mint
     * @param receiver The receiver of the minted shares
     *
     * @return assets The amount of assets deposited
     */
    function mint(uint256 shares, address receiver) external returns (uint256)
    {
        uint256 assets = previewMint(shares);
        Addresses.SADDLE_USD_TOKEN.transferFrom(msg.sender, address(this), assets);
        _saddleFarm.deposit(assets);

        _mint(receiver, shares);

        return assets;
    }

    /**
     * @dev Peforms minting logic
     *
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
     *
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

    /**
     * @dev Harvest Saddle rewards and redeposit in the pool
     */
    function harvest() external onlyTreasury
    {
        _saddleFarm.claim_rewards(address(this));
        _gauge.mint(address(_saddleFarm));

        uint256 balance = SDL.balanceOf(address(this));

        if (balance > 0) {
            Swaps.swapUsingSushi(address(SDL), address(Addresses.FRAX), SDL.balanceOf(address(this)), 0, true);

            uint256[] memory amounts = new uint256[](3);
            amounts[2] = Addresses.FRAX.balanceOf(address(this));

            Addresses.SADDLE_USD_POOL.addLiquidity(amounts, 0, block.timestamp);      
        }

        uint256 poolTokenBalance = Addresses.SADDLE_USD_TOKEN.balanceOf(address(this));

        if (poolTokenBalance > 0) {
            _saddleFarm.deposit(poolTokenBalance);
        }

    }

    /**
     * @dev Function to claim SDL rewards from their claim contract
     *
     * @param poolId The Saddle Pool ID to claim rewards for
     *
     * @notice This function can likely be removed as Saddle transitions
     * to staking contracts per pool as seen in the harvest() function.
     */
    function claimSDL(uint256 poolId) external onlyTreasury
    {
        Swaps.SDLClaim.harvest(poolId, _treasurer);
    }

    /* ################################
    ############# EVENTS ##############
    ################################ */

    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);
}