// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ISaddlePool {
    // View functions
    function getTokenIndex(address tokenAddress) external view returns (uint8);

    function calculateTokenAmount(uint256[] calldata amounts, bool deposit)
        external
        view
        returns (uint256);

    function calculateRemoveLiquidityOneToken(
        uint256 tokenAmount,
        uint8 tokenIndex
    ) external view returns (uint256);

    function getVirtualPrice() external view returns (uint256);

    // Mutative functions
    function addLiquidity(
        uint256[] calldata amounts,
        uint256 minToMint,
        uint256 deadline
    ) external returns (uint256);

    function removeLiquidityOneToken(
        uint256 tokenAmount,
        uint8 tokenIndex,
        uint256 minAmount,
        uint256 deadline
    ) external returns (uint256);
}
