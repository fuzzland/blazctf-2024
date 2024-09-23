// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity ^0.8.19;

interface IFirewallConsumer {
    function firewallAdmin() external returns (address);
}
