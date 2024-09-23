// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity ^0.8.19;

import {FirewallPolicyBase} from "./FirewallPolicyBase.sol";

/**
 * @dev This policy only allows addresses on an allowlist to call the protected method
 *
 */
contract AllowlistPolicy is FirewallPolicyBase {

    /**
     * @dev A mapping of consumer addresses to a mapping of sender addresses to a boolean value.
     * The boolean value is true if the sender is allowed to call the consumer, and false if they are not.
     */
    mapping (address consumer => mapping (address caller => bool isAllowed)) public consumerAllowlist;

    /**
     * @dev This function is called before the execution of a transaction.
     * It checks if the sender is allowed to call the consumer.
     *
     * @param consumer The address of the contract that is being called.
     * @param sender The address of the account that is calling the contract.
     */
    function preExecution(address consumer, address sender, bytes calldata, uint256) external view override {
        require(consumerAllowlist[consumer][sender], "AllowlistPolicy: Sender not allowed");
    }

    /**
     * @dev This function is called after the execution of a transaction.
     * It does nothing in this policy.
     */
    function postExecution(address, address, bytes calldata, uint256) external override {
        // Do nothing
    }

    /**
     * @dev This function is called to set the allowlist for a consumer.
     *
     * @param consumer The address of the consumer contract.
     * @param accounts The addresses to set the allowlist for.
     * @param status The status to set the allowlist to.
     */
    function setConsumerAllowlist(address consumer, address[] calldata accounts, bool status) external onlyRole(POLICY_ADMIN_ROLE) {
        for (uint256 i = 0; i < accounts.length; i++) {
            consumerAllowlist[consumer][accounts[i]] = status;
        }
    }
}
