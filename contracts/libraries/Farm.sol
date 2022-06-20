// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

library Farm {

    function takeFee(uint256 fee, uint256 total) internal pure returns (uint256)
    {
        return total * fee / 1e18;
    }

    function calculatePercent(uint256 total, uint256 percent) internal pure returns (uint256)
    {
        return total * percent / 1e18;
    }
}