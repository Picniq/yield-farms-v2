// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ISDLClaim {
    function harvest(uint poolId, address to) external;
}