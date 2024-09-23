// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity ^0.8.19;

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IFirewall} from "../interfaces/IFirewall.sol";
import {IFirewallConsumer} from "../interfaces/IFirewallConsumer.sol";
import {IFirewallTransparentUpgradeableProxy} from "./FirewallTransparentUpgradeableProxy.sol";

/**
 * @title Firewall Proxy Admin
 * @author David Benchimol @ Ironblocks
 * @dev This contract acts the same as OpenZeppelins `ProxyAdmin` contract,
 * but built to work with Ironblocks FirewallTransparentUpgradeableProxy.
 *
 */
contract FirewallProxyAdmin is ProxyAdmin {

    /**
     * @dev Returns the current firewall of `proxy`.
     *
     * @param proxy The proxy to query.
     * @return The address of the firewall of `proxy`.
     *
     * Requirements:
     *
     * - This contract must be the admin of `proxy`.
     */
    function getProxyFirewall(IFirewallTransparentUpgradeableProxy proxy) public view virtual returns (address) {
        // We need to manually run the static call since the getter cannot be flagged as view
        // bytes4(keccak256("firewall()")) == 0xc22a4a85
        (bool success, bytes memory returndata) = address(proxy).staticcall(hex"c22a4a85");
        require(success);
        return abi.decode(returndata, (address));
    }

    /**
     * @dev Returns the current firewall admin of `proxy`.
     *
     * @param proxy The proxy to query.
     * @return The address of the firewall admin of `proxy`.
     *
     * Requirements:
     *
     * - This contract must be the admin of `proxy`.
     */
    function getProxyFirewallAdmin(IFirewallTransparentUpgradeableProxy proxy) public view virtual returns (address) {
        // We need to manually run the static call since the getter cannot be flagged as view
        // bytes4(keccak256("firewallAdmin()")) == 0xf05c8582
        (bool success, bytes memory returndata) = address(proxy).staticcall(hex"f05c8582");
        require(success);
        return abi.decode(returndata, (address));
    }

    /**
     * @dev Changes the firewall of `proxy` to `newFirewall`.
     *
     * @param proxy The proxy to change the firewall of.
     * @param newFirewall The address of the new firewall
     *
     * Requirements:
     *
     * - This contract must be the current admin of `proxy`.
     */
    function changeFirewall(IFirewallTransparentUpgradeableProxy proxy, address newFirewall) public virtual onlyOwner {
        proxy.changeFirewall(newFirewall);
    }

    /**
     * @dev Changes the firewall admin of `proxy` to `newFirewallAdmin`.
     *
     * @param proxy The address of the proxy
     * @param newFirewallAdmin The address of the new admin of the firewall
     *
     * Requirements:
     *
     * - This contract must be the current admin of `proxy`.
     */
    function changeFirewallAdmin(IFirewallTransparentUpgradeableProxy proxy, address newFirewallAdmin) public virtual onlyOwner {
        proxy.changeFirewallAdmin(newFirewallAdmin);
    }

}