// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "./VERC20.sol";
import "./libraries/FixedPointMath.sol";
import "./libraries/Addresses.sol";
import "./libraries/Swaps.sol";
import "./interfaces/IAave.sol";
import "./interfaces/ICurve.sol";
import "./interfaces/ISaddlePool.sol";
import "./interfaces/IFraxStaking.sol";
import "./interfaces/IAlchemixStaking.sol";
import "./interfaces/IERC20.sol";

/**
 * @author Picniq Finance
 * @title AAVE / Saddle ETH Farm
 * @notice Accepts user deposits in ETH and
 * uses a safe leverage yield farm strategy
 * to maximize earnings with minimal risks.
 */

// TODO: Treasury fees

// solhint-disable var-name-mixedcase, not-rely-on-time, no-empty-blocks
contract ETHFarm is VERC20 {
    using FixedPointMath for uint256;

    uint256 private _fee;
    uint256 private _leverageRate = 65e16;
    address private _treasurer;

    constructor(string memory name_, string memory symbol_) VERC20 (name_, symbol_) {
        _treasurer = msg.sender;
        Addresses.STETH.approve(address(Addresses.AAVE), type(uint256).max);
        Addresses.AAVE_STETH.approve(address(Addresses.AAVE), type(uint256).max);
        Addresses.WETH.approve(address(Addresses.SADDLE_ETH_POOL), type(uint256).max);
        Addresses.WETH.approve(address(Addresses.AAVE), type(uint256).max);
        Addresses.SADDLE_ETH_TOKEN.approve(address(Addresses.ALCHEMIX), type(uint256).max);
        Addresses.SADDLE_ETH_TOKEN.approve(address(Addresses.SADDLE_ETH_POOL), type(uint256).max);
        Addresses.ALCX.approve(address(Swaps.SUSHI_ROUTER), type(uint256).max);
    }

    modifier onlyTreasury()
    {
        require(msg.sender == _treasurer, "Not treasurer");
        _;
    }

    receive() external payable {}
    fallback() external payable {}

    /* === VIEW FUNCTIONS === */

    /* ################################
    ######### ERC4626 Support #########
    ################################ */

    /**
     * @dev Underlying asset
     * @return assetTokenAddress return underlying asset
     */
    function asset() external pure returns (address)
    {
        return address(Addresses.STETH);
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
        (uint256 totalCollateral, , , , , ) = Addresses.AAVE.getUserAccountData(address(this));
        return totalCollateral;
    }

    /**
     * @dev Convert assets to vault shares
     * @param assets the amount to convert
     * @return shares the shares converted from input
     */
    function convertToShares(uint256 assets) public view returns (uint256)
    {
        uint256 supply = _totalSupply;

        if (supply > 0) {
            return assets.mulDivDown(supply, _totalAssets());
        } else {
            return assets;
        }
    }

    /**
     * @dev Convert vault shares to assets
     * @param shares the amount to convert
     * @return assets the assets converted from shares
     */
    function convertToAssets(uint256 shares) public view returns (uint256)
    {
        uint256 supply = _totalSupply;

        if (supply > 0) {
            return shares.mulDivDown(_totalAssets(), supply);
        } else {
            return shares;
        }
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

        if (supply > 0) {
            return shares.mulDivUp(_totalAssets(), supply);
        } else {
            return shares;
        }
    }

    /**
     * @dev Preview withdraw and return expected shares to burn
     * @param assets the amount of assets
     * @return amountToWithdraw the amount of shares from the asset
     */
    function previewWithdraw(uint256 assets) public view returns (uint256)
    {
        uint256 supply = _totalSupply;

        if (supply > 0) {
            return assets.mulDivUp(supply, _totalAssets());
        } else {
            return assets;
        }
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
     * @dev Maximum deposits allowed
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

    /**
     * @dev Returns treasury address
     */
    function getTreasury() external view returns (address)
    {
        return _treasurer;
    }

    /* === MUTATIVE FUNCTIONS === */
    
    /* ################################
    ######### ERC4626 Support #########
    ################################ */

    /**
     * @dev Allow user to deposit Saddle ETH LP tokens directly
     * @param assets amount of LP tokens to deposit
     * @param receiver address to send vault shares to
     */
    function deposit(uint256 assets, address receiver) public returns (uint256)
    {
        address sender = _msgSender();

        uint256 shares = previewDeposit(assets);

        require(shares != 0, "Zero shares");

        Addresses.SADDLE_ETH_TOKEN.transferFrom(sender, address(this), assets);

        Addresses.ALCHEMIX.deposit(6, assets);

        _mint(receiver, shares);

        emit Deposit(sender, receiver, assets, shares);

        // afterDeposit(assets, shares);

        return shares;
    }

    /**
     * @dev Allow user to deposit ETH into pool
     * @param receiver address to send vault shares to
     * @notice must receive greater than 0 value in msg.value
     * @return shares the amount of shares minted
     */
    function depositETH(address receiver) external payable returns (uint256)
    {
        require(msg.value != 0, "Must send ETH");

        address sender = _msgSender();

        uint256 output = Addresses.CURVE_STETH_POOL.exchange{value: msg.value}(0, 1, msg.value, 0);
        uint256 shares = previewDeposit(output);
        Addresses.AAVE.deposit(address(Addresses.STETH), output, address(this), 0);
        uint256 borrowPercent = output * _leverageRate / 1e18;
        Addresses.AAVE.borrow(address(Addresses.WETH), borrowPercent, 2, 0, address(this));
        uint256[] memory amounts = new uint256[](3);

        amounts[0] = Addresses.WETH.balanceOf(address(this));
        amounts[1] = 0;
        amounts[2] = 0;

        uint256 liq = Addresses.SADDLE_ETH_POOL.addLiquidity(amounts, 0, block.timestamp);

        Addresses.ALCHEMIX.deposit(6, liq);

        _mint(receiver, shares);

        emit Deposit(sender, receiver, output, shares);

        return shares;
    }

    /**
     * @dev Allow user to withdraw their LP tokens directly
     * @param assets amount of assets to withdraw
     * @param receiver account to send LP tokens to
     * @param owner the owner of the assets
     * @return shares the number of shares burned
     */
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256)
    {
        uint256 shares = previewWithdraw(assets);
        address sender = _msgSender();

        if (sender != owner) {
            uint256 allowed = _allowances[owner][sender];

            if (allowed != type(uint256).max) {
                _allowances[owner][sender] = allowed - shares;
            }
        }

        uint256 percentToWithdraw = shares * 1e18 / _totalSupply;

        _burn(owner, shares);

        uint256 totalStaked = Addresses.ALCHEMIX.getStakeTotalDeposited(address(this), 6);
        uint256 amountToWithdraw = totalStaked * percentToWithdraw / 1e18;
        Addresses.ALCHEMIX.withdraw(6, amountToWithdraw);
        uint256 output = Addresses.SADDLE_ETH_POOL.removeLiquidityOneToken(amountToWithdraw, 0, 0, block.timestamp);
        _repayAndWithdraw(output, assets, receiver);
        
        emit Withdraw(sender, receiver, owner, assets, shares);

        return shares;
    }

    /**
     * @dev Allow user to withdraw ETH asset
     * @param assets amount of assets to withdraw
     * @param receiver account to send token to
     * @param owner the owner of the assets
     * @param minAmount the minimum amount of ETH asset to receive
     * @return shares the amount of shares burned
     */
    function withdraw(uint256 assets, address receiver, address owner, uint256 minAmount) external returns (uint256)
    {
        uint256 shares = previewWithdraw(assets);
        address sender = _msgSender();

        if (sender != owner) {
            uint256 allowed = _allowances[owner][sender];

            if (allowed != type(uint256).max) {
                _allowances[owner][sender] = allowed - shares;
            }
        }

        uint256 percentToWithdraw = shares * 1e18 / _totalSupply;

        _burn(owner, shares);

        uint256 totalStaked = Addresses.ALCHEMIX.getStakeTotalDeposited(address(this), 6);
        uint256 amountToWithdraw = totalStaked * percentToWithdraw / 1e18;
        Addresses.ALCHEMIX.withdraw(6, amountToWithdraw);
        uint256 output = Addresses.SADDLE_ETH_POOL.removeLiquidityOneToken(amountToWithdraw, 0, minAmount, block.timestamp);
        _repayAndWithdraw(output, assets, receiver);
        
        emit Withdraw(sender, receiver, owner, assets, shares);

        return shares;
    }

    /**
     * @dev Allow user to redeem shares for LP tokens
     * @param shares amount of shares to burn
     * @param receiver account to send LP tokens to
     * @param owner the owner of the shares
     * @return assets the amount of assets to withdraw
     */
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256)
    {
        address sender = _msgSender();
        if (sender != owner) {
            uint256 allowed = _allowances[owner][sender];
            if (allowed != type(uint256).max) {
                _allowances[owner][sender] = allowed - shares;
            }
        }

        uint256 assets = previewRedeem(shares);
        
        require(assets != 0, "No assets");

        // beforeWithdraw(assets, shares);

        _burn(owner, shares);

        Addresses.ALCHEMIX.withdraw(6, assets);

        Addresses.SADDLE_ETH_TOKEN.transfer(receiver, assets);

        emit Withdraw(sender, receiver, owner, assets, shares);

        return assets;
    }

    /**
     * @dev Allow user to redeem shares for LP tokens
     * @param shares amount of shares to burn
     * @param receiver account to send LP tokens to
     * @param owner the owner of the shares
     * @param minAmount the minimum amount of ETH asset to withdraw
     * @return assets the amount of assets to withdraw
     */
    function redeem(uint256 shares, address receiver, address owner, uint256 minAmount) external returns (uint256)
    {
        address sender = _msgSender();

        if (sender != owner) {
            uint256 allowed = _allowances[owner][sender];
            if (allowed != type(uint256).max) {
                _allowances[owner][sender] = allowed - shares;
            }
        }

        uint256 assets = previewRedeem(shares);
        
        require(assets != 0, "No assets");

        // beforeWithdraw(assets, shares);

        uint256 percentToWithdraw = shares * 1e18 / _totalSupply;
        _burn(owner, shares);

        uint256 totalStaked = Addresses.ALCHEMIX.getStakeTotalDeposited(address(this), 6);
        uint256 amountToWithdraw = totalStaked * percentToWithdraw / 1e18;
        Addresses.ALCHEMIX.withdraw(6, amountToWithdraw);
        uint256 output = Addresses.SADDLE_ETH_POOL.removeLiquidityOneToken(amountToWithdraw, 0, minAmount, block.timestamp);
        _repayAndWithdraw(output, assets, receiver);
        
        emit Withdraw(sender, receiver, owner, assets, shares);
        
        return assets;
    }

    /**
     * @dev Repay AAVE loan and withdraw funds
     */
    function _repayAndWithdraw(uint256 repay, uint256 assets, address receiver) private
    {
        Addresses.AAVE.repay(address(Addresses.WETH), repay, 2, address(this));
        Addresses.AAVE.withdraw(address(Addresses.STETH), assets, receiver);
    }

    /**
     * @dev Mint shares
     * @param shares the amount of shares to mint
     * @param receiver account to send minted shares to
     * @return assets amount of assets taken for shares
     */
    function mint(uint256 shares, address receiver) external returns (uint256)
    {
        address sender = _msgSender();
        uint256 assets = previewMint(shares);

        Addresses.SADDLE_ETH_TOKEN.transferFrom(sender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(sender, receiver, assets, shares);

        return assets;
    }

    /**
     * @dev Performs minting logic
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
        require(account != address(0), "ERC20: burn from zero addr");
        
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
     * @dev Calculate amount to borrow
     * @param total the total amount held
     */
    function _calculateBorrow(uint256 total) private view returns (uint256)
    {
        return total * _leverageRate / 1e18;
    }

    /**
     * @dev Harvest and reinvest rewards
     */
    function harvest() external onlyTreasury
    {
        Addresses.ALCHEMIX.claim(6);
        uint256 alcxBalance = Addresses.ALCX.balanceOf(address(this));
        uint256 wethOutput = Swaps.swapUsingSushi(address(Addresses.ALCX), address(Addresses.WETH), alcxBalance, 0, false);
        Addresses.WETH.withdraw(wethOutput);
        uint256 stethOutput = Addresses.CURVE_STETH_POOL.exchange{value: wethOutput}(0, 1, wethOutput, 0);
        Addresses.AAVE.deposit(address(Addresses.STETH), stethOutput, address(this), 0);
        Addresses.AAVE.borrow(address(Addresses.WETH), _calculateBorrow(stethOutput), 2, 0, address(this));
        
        uint256[] memory amounts = new uint256[](3);

        amounts[0] = Addresses.WETH.balanceOf(address(this));
        amounts[1] = 0;
        amounts[2] = 0;

        uint256 liq = Addresses.SADDLE_ETH_POOL.addLiquidity(amounts, 0, block.timestamp);

        Addresses.ALCHEMIX.deposit(6, liq);
    }

    /**
     * @dev Claim SDL rewards from Saddle
     * @param poolId the Saddle pool ID
     */
    function claimSDL(uint256 poolId) external onlyTreasury
    {
        Swaps.SDLClaim.harvest(poolId, _treasurer);
    }

    /**
     * @dev Adjust amount of leverage the strategy uses
     * @param newLeverage new leverage percentage where 1e18 = 100%
     */
    function adjustLeverage(uint256 newLeverage) external onlyTreasury
    {
        require(newLeverage <= 75e16, "Leverage must be below 75%");
        _leverageRate = newLeverage;
    }

    /**
     * @dev Reset leverage percent to optimal amount
     */
    function resetLeverage() external onlyTreasury
    {
        (uint256 totalCollateral, uint256 totalDebt, , , , ) = Addresses.AAVE.getUserAccountData(address(this));
        uint256 currentLeverage = totalDebt * 1e18 / totalCollateral;
        uint256 desiredLeverage = _leverageRate;
        if (currentLeverage > desiredLeverage) {
            uint256 desiredDebt = totalCollateral * desiredLeverage / 1e18;
            uint256 delta = totalDebt - desiredDebt;
            uint256 currentPriceLP = Addresses.SADDLE_ETH_POOL.getVirtualPrice();
            // Withdraw 2% extra to cover any slippage
            uint256 withdrawAmount = delta * 102e16 / currentPriceLP;
            Addresses.ALCHEMIX.withdraw(6, withdrawAmount);
            Addresses.SADDLE_ETH_POOL.removeLiquidityOneToken(withdrawAmount, 0, 0, block.timestamp);
            Addresses.AAVE.repay(address(Addresses.WETH), delta, 2, address(this));
        } else if (currentLeverage < desiredLeverage) {
            uint256 desiredDebt = totalCollateral * desiredLeverage / 1e18;
            uint256 delta = desiredDebt - totalDebt;
            Addresses.AAVE.borrow(address(Addresses.WETH), delta, 2, 0, address(this));
            uint256[] memory amounts = new uint256[](3);
            amounts[0] = delta;
            amounts[1] = 0;
            amounts[2] = 0;
            uint256 output = Addresses.SADDLE_ETH_POOL.addLiquidity(amounts, 0, block.timestamp);
            Addresses.ALCHEMIX.deposit(6, output);
        }
    }

    /* ################################
    ############# EVENTS ##############
    ################################ */

    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);
}