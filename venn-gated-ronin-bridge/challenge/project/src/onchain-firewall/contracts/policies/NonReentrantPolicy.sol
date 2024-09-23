// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity ^0.8.19;

import {FirewallPolicyBase} from "./FirewallPolicyBase.sol";

/**
 * @dev This policy is simply the equivalent of the standard `nonReentrant` modifier.
 *
 * This is much less gas efficient than the `nonReentrant` modifier, but allows consumers to make
 * a non upgradeable contracts method `nonReentrant` post deployment.
 *
 * NOTE: This policy DOES NOT support Firewall Consumers that call themselves internally, as that would
 * be detected by this policy as a reentrancy attack - causing the transaction to revert.
 *
 * Advanced configuration using multiple instances of this policy can be used to support this use case.
 *
 * If you have any questions on how or when to use this policy, please refer to the Firewall's documentation
 * and/or contact our support.
 *
 */
contract NonReentrantPolicy is FirewallPolicyBase {

    // consumer => bool
    mapping (address consumer => bool hasEntered) public hasEnteredConsumer;

    constructor(address _firewallAddress) FirewallPolicyBase() {
        authorizedExecutors[_firewallAddress] = true;
    }

    /**
     * @dev This function is called before the execution of a transaction.
     * It checks that the consumer is not currently executing a transaction.
     *
     * @param consumer The address of the contract that is being called.
     */
    function preExecution(address consumer, address, bytes calldata, uint256) external isAuthorized(consumer) {
        require(!hasEnteredConsumer[consumer], "NO REENTRANCY");
        hasEnteredConsumer[consumer] = true;
    }

    /**
     * @dev This function is called after the execution of a transaction.
     * It sets the consumer as not currently executing a transaction.
     *
     * @param consumer The address of the contract that is being called.
     */
    function postExecution(address consumer, address, bytes calldata, uint256) external isAuthorized(consumer) {
        hasEnteredConsumer[consumer] = false;
    }

}
