// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2024
pragma solidity ^0.8.0;

interface IFirewallConsumerStorage {
    function getFirewallAdmin() external view returns (address);
    function getFirewall() external view returns (address);
    function getApprovedVennPolicy() external view returns (address);
    function getUserNativeFee() external view returns (uint256);
}