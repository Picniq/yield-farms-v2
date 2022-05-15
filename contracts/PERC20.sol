// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./Context.sol";

/**
 * @author Picniq Finance
 * @title Picniq Vault ERC20 Contract
 * @notice Slight customizations from standard
 * ERC20 to support deposit locks.
 */

// solhint-disable not-rely-on-time
abstract contract PERC20 is Context {

    uint256 internal _totalSupply;
    mapping (address => UserDeposit) internal _deposits;
    mapping (address => mapping (address => uint256 )) internal _allowances;

    struct UserDeposit {
        uint256 deposits;
        uint256 depositTime;
    }

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
     * @dev Total shares of vault
     * @return totalSupply the total supply of shares
     */
    function totalSupply() external view returns (uint256)
    {
        return _totalSupply;
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

        emit Transfer(from, to, amount);

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

        emit Approval(owner, spender, amount);
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

    // EVENTS

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}