// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "hardhat/console.sol";
import "./Swaps.sol";
import "./VERC20.sol";
import "./libraries/FixedPointMath.sol";
import "./interfaces/IAave.sol";
import "./interfaces/ICurve.sol";
import "./interfaces/ISaddlePool.sol";
import "./interfaces/IFraxStaking.sol";
import "./interfaces/IAlchemixStaking.sol";
import "./interfaces/IERC20.sol";

pragma solidity 0.8.13;

/**
 * @author Picniq Finance
 * @title AAVE / Saddle ETH Farm
 * @notice Accepts user deposits in ETH and
 * uses a safe leverage yield farm strategy
 * to maximize earnings with minimal risks.
 */

// solhint-disable var-name-mixedcase, not-rely-on-time
contract ETHFarm is VERC20, Swaps {
    using FixedPointMath for uint256;

    uint256 private _fee;
    address private _treasurer;

    IERC20 private immutable STETH = IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    ICurve private immutable CURVE = ICurve(0xDC24316b9AE028F1497c275EB9192a3Ea0f67022);
    IAave private immutable AAVE = IAave(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
    // IERC20 private immutable WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 private immutable SADDLE_ETH_TOKEN = IERC20(0xc9da65931ABf0Ed1b74Ce5ad8c041C4220940368);
    IAlchemixStaking private immutable ALCHEMIX = IAlchemixStaking(0xAB8e74017a8Cc7c15FFcCd726603790d26d7DeCa);
    ISaddlePool internal saddleETHPool = ISaddlePool(0xa6018520EAACC06C30fF2e1B3ee2c7c22e64196a);
    // ISDLClaim internal SDLClaim = ISDLClaim(0x691ef79e40d909C715BE5e9e93738B3fF7D58534);

    constructor(string memory name_, string memory symbol_) VERC20 (name_, symbol_) {
        STETH.approve(address(AAVE), type(uint256).max);
        IERC20(0x1982b2F5814301d4e9a8b0201555376e62F82428).approve(address(AAVE), type(uint256).max);
        // IERC20(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9).approve(address(AAVE), type(uint256).max);
        WETH.approve(address(saddleETHPool), type(uint256).max);
        WETH.approve(address(AAVE), type(uint256).max);
        SADDLE_ETH_TOKEN.approve(address(ALCHEMIX), type(uint256).max);
        SADDLE_ETH_TOKEN.approve(address(saddleETHPool), type(uint256).max);
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
        return address(STETH);
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
        (uint256 totalDeposited, , , , ,) = AAVE.getUserAccountData(address(this));
        return totalDeposited + STETH.balanceOf(address(this));
        // return ALCHEMIX.getStakeTotalDeposited(address(this), 6) + saddleUSDToken.balanceOf(address(this));
    }

    /**
     * @dev Convert assets to vault shares
     * @param assets the amount to convert
     * @return shares the shares converted from input
     */
    function convertToShares(uint256 assets) public view returns (uint256)
    {
        uint256 supply = _totalSupply;

        return supply == 0 ? assets : assets.mulDivDown(supply, _totalAssets());
    }

    /**
     * @dev Convert vault shares to assets
     * @param shares the amount to convert
     * @return assets the assets converted from shares
     */
    function convertToAssets(uint256 shares) public view returns (uint256)
    {
        uint256 supply = _totalSupply;

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

        SADDLE_ETH_TOKEN.transferFrom(sender, address(this), assets);

        ALCHEMIX.deposit(6, assets);

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

        uint256 output = CURVE.exchange{value: msg.value}(0, 1, msg.value, 0);
        (uint256 preBorrowed,,,,,) = AAVE.getUserAccountData(address(this));
        AAVE.deposit(address(STETH), output, address(this), 0);
        AAVE.borrow(address(WETH), output / 2, 2, 0, address(this));
        uint256[] memory amounts = new uint256[](3);
        (uint256 postBorrowed, , , , ,) = AAVE.getUserAccountData(address(this));

        amounts[0] = WETH.balanceOf(address(this));
        amounts[1] = 0;
        amounts[2] = 0;

        uint256 liq = saddleETHPool.addLiquidity(amounts, 0, block.timestamp);
        uint256 shares = previewDeposit(postBorrowed - preBorrowed);

        ALCHEMIX.deposit(6, liq);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, output, shares);

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

        if (msg.sender != owner) {
            uint256 allowed = _allowances[owner][msg.sender];

            if (allowed != type(uint256).max) {
                _allowances[owner][msg.sender] = allowed - shares;
            }
        }

        uint256 percentToWithdraw = (shares * 1e18 / _totalSupply);

        _burn(owner, shares);

        uint256 totalStaked = ALCHEMIX.getStakeTotalDeposited(address(this), 6);
        uint256 amountToWithdraw = totalStaked * percentToWithdraw / 1e18;
        ALCHEMIX.withdraw(6, amountToWithdraw);
        uint256 output = saddleETHPool.removeLiquidityOneToken(amountToWithdraw, 0, 0, block.timestamp);
        output = AAVE.repay(address(WETH), output, 2, address(this));
        AAVE.withdraw(address(STETH), output, receiver);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        return shares;
    }

    /**
     * @dev Allow user to withdraw ETH asset
     * @param assets amount of assets to withdraw
     * @param receiver account to send token to
     * @param owner the owner of the assets
     * @param minAmount the minimum amount of ETH asset to receive
     * @param tokenIndex the index of preferred ETH asset to withdraw from Saddle
     * @return shares the amount of shares burned
     */
    function withdraw(uint256 assets, address receiver, address owner, uint256 minAmount, uint8 tokenIndex) external returns (uint256)
    {
        uint256 shares = previewWithdraw(assets);

        if (msg.sender != owner) {
            uint256 allowed = _allowances[owner][msg.sender];

            if (allowed != type(uint256).max) {
                _allowances[owner][msg.sender] = allowed - shares;
            }
        }

        uint256 percentToWithdraw = (shares * 1e18 / _totalSupply);
        console.log(percentToWithdraw / 1e16);
        _burn(owner, shares);

        uint256 totalStaked = ALCHEMIX.getStakeTotalDeposited(address(this), 6);
        uint256 amountToWithdraw = totalStaked * percentToWithdraw / 1e18;
        ALCHEMIX.withdraw(6, amountToWithdraw);
        uint256 output = saddleETHPool.removeLiquidityOneToken(amountToWithdraw, tokenIndex, minAmount, block.timestamp);
        output = AAVE.repay(address(WETH), output, 2, address(this));
        AAVE.withdraw(address(STETH), output, receiver);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

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
        if (msg.sender != owner) {
            uint256 allowed = _allowances[owner][msg.sender];
            if (allowed != type(uint256).max) {
                _allowances[owner][msg.sender] = allowed - shares;
            }
        }

        uint256 assets = previewRedeem(shares);
        
        require(assets != 0, "No assets");

        // beforeWithdraw(assets, shares);

        _burn(owner, shares);

        ALCHEMIX.withdraw(6, assets);

        SADDLE_ETH_TOKEN.transfer(receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        return assets;
    }

    /**
     * @dev Allow user to redeem shares for LP tokens
     * @param shares amount of shares to burn
     * @param receiver account to send LP tokens to
     * @param owner the owner of the shares
     * @param minAmount the minimum amount of ETH asset to withdraw
     * @param tokenIndex the index of preferred ETH asset from Saddle
     * @return assets the amount of assets to withdraw
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

        // beforeWithdraw(assets, shares);

        uint256 percentToWithdraw = (shares * 1e18 / _totalSupply);
        _burn(owner, shares);

        uint256 totalStaked = ALCHEMIX.getStakeTotalDeposited(address(this), 6);
        uint256 amountToWithdraw = totalStaked * percentToWithdraw / 1e18;
        ALCHEMIX.withdraw(6, amountToWithdraw);
        uint256 output = saddleETHPool.removeLiquidityOneToken(amountToWithdraw, tokenIndex, minAmount, block.timestamp);
        output = AAVE.repay(address(WETH), output, 2, address(this));
        AAVE.withdraw(address(STETH), output, receiver);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        
        return assets;
    }

    // function _repayLoan(uint256 assets, address receiver) private
    // {
    //     uint256 percentOfSupply = _balances[msg.sender] * 1e18 / (_totalSupply * 1e16);
    //     (uint256 totalBorrowed, , , , ,) = AAVE.getUserAccountData(address(this));
    //     uint256 amountToWithdraw = totalBorrowed * percentOfSupply / 100;
    //     AAVE.repay(address(WETH), assets, 0, address(this));
    //     AAVE.withdraw(address(STETH), amountToWithdraw, receiver);
    // }

    /**
     * @dev Mint shares
     * @param shares the amount of shares to mint
     * @param receiver account to send minted shares to
     * @return assets amount of assets taken for shares
     */
    function mint(uint256 shares, address receiver) external returns (uint256)
    {
        uint256 assets = previewMint(shares);
        SADDLE_ETH_TOKEN.transferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

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
        console.log(balance);
        console.log(shares);

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

    function harvest() external onlyTreasury
    {
        // TODO
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