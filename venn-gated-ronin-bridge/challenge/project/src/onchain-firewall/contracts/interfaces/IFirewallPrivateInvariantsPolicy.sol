// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity ^0.8.19;

interface IFirewallPrivateInvariantsPolicy {
    function preExecution(
        address consumer,
        address sender,
        bytes memory data,
        uint256 value
    ) external returns (bytes32[] calldata);
    function postExecution(
        address consumer,
        address sender,
        bytes memory data,
        uint256 value,
        bytes32[] calldata preValues,
        bytes32[] calldata postValues
    ) external;
}
