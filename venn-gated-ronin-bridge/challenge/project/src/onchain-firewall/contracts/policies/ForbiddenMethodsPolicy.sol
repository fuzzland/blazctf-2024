// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity ^0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {FirewallPolicyBase} from "./FirewallPolicyBase.sol";

/**
 * @dev This policy reverts if a given method is called.
 *
 * While the obvious use case of this policy is to disable methods, there's much more to it.
 * Note that this policy will revert any time it's called again once a forbidden method has been
 * called in a transaction. It may seem counterintuitive to write to storage during the `preExecution`
 * if it causes the `postExecution` to revert. However this makes sense once you consider that this is
 * meant to be used in conjunction with the `CombinedPoliciesPolicy`, allowing the consumer to create a policy
 * which will only require certain policies to pass once you hit a defined "forbidden" method.
 *
 * IMPORTANT: This function relies on the "tx.origin", "block.number", and "tx.gasprice" for determining
 * the current execution context - which in some cases may not be unique - and therefore comes with the following
 * known limitations:
 *
 *   1. Account Abstraction is not supported (EIP-4337)
 *   2. Transactions with similar gas-price in the same block may not be unique, causing false-positives
 *
 * If you have any questions and / or need additional support regrading this policy,
 * please contact our support.
 *
 */
contract ForbiddenMethodsPolicy is FirewallPolicyBase {

    // consumer => methodSig => bool
    mapping (address consumer => mapping (bytes4 sighash => bool isForbidden)) public consumerMethodStatus;
    // context => bool
    mapping (bytes32 currentContextHash => bool hasEntered) public hasEnteredForbiddenMethod;

    /**
     * @dev This function is called before the execution of a transaction.
     * It marks the context as having entered a forbidden method if the method is forbidden.
     *
     * @param consumer The address of the contract that is being called.
     * @param data The data of the transaction.
     */
    function preExecution(address consumer, address, bytes calldata data, uint256) external override {
        bytes32 currentContext = keccak256(abi.encodePacked(tx.origin, block.timestamp, tx.gasprice));
        if (consumerMethodStatus[consumer][bytes4(data)]) {
            hasEnteredForbiddenMethod[currentContext] = true;
        }
    }

    /**
     * @dev This function is called after the execution of a transaction.
     * It reverts if the context has entered a forbidden method.
     */
    function postExecution(address, address, bytes calldata, uint256) external view override {
        bytes32 currentContext = keccak256(abi.encodePacked(tx.origin, block.timestamp, tx.gasprice));
        require(!hasEnteredForbiddenMethod[currentContext], "Forbidden method");
    }

    /**
     * @dev This function is called to set the forbidden status of a method.
     *
     * @param consumer The address of the contract that is being called.
     * @param methodSig The signature of the method to set the forbidden status for.
     * @param status The forbidden status to set.
     */
    function setConsumerForbiddenMethod(address consumer, bytes4 methodSig, bool status) external onlyRole(POLICY_ADMIN_ROLE) {
        consumerMethodStatus[consumer][methodSig] = status;
    }

}
