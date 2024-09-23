// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity ^0.8.19;

import {FirewallPolicyBase} from "./FirewallPolicyBase.sol";

/**
 * @dev This policy doesn't allows blocked addresses on a blocklist to call the protected method
 *
 */
contract BlocklistPolicy is FirewallPolicyBase {

    // consumer => sender => bool
    mapping (address consumer => mapping (address caller => bool isCallerBlocked)) public consumerBlocklist;

    /**
     * @dev This function is called before the execution of a transaction.
     * It checks that the sender is not on the blocklist.
     *
     * @param consumer The address of the contract that is being called.
     * @param sender The address of the contract that is calling the consumer.
     */
    function preExecution(address consumer, address sender, bytes calldata, uint256) external view override {
        require(!consumerBlocklist[consumer][sender], "BlocklistPolicy: Sender not allowed");
    }

    /**
     * @dev This function is called after the execution of a transaction.
     * It does nothing in this policy.
     */
    function postExecution(address, address, bytes calldata, uint256) external override {
        // Do nothing
    }

    /**
     * @dev This function is called to set the blocklist status of multiple addresses.
     * This is useful for adding a large amount of addresses to the blocklist in a single transaction.
     *
     * @param consumer The address of the contract that is being called.
     * @param accounts The addresses to set the blocklist status for.
     * @param status The blocklist status to set.
     */
    function setConsumerBlocklist(address consumer, address[] calldata accounts, bool status) external onlyRole(POLICY_ADMIN_ROLE) {
        for (uint256 i = 0; i < accounts.length; i++) {
            consumerBlocklist[consumer][accounts[i]] = status;
        }
    }
}
