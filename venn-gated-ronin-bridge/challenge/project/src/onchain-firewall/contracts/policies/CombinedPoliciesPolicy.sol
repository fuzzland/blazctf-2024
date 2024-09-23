// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity ^0.8.19;

import {FirewallPolicyBase, IFirewallPolicy} from "./FirewallPolicyBase.sol";

/**
 * @dev This policy allows the combining of multiple other policies
 *
 * This policy is useful for consumers that want to combine multiple policies, requiring some
 * combination of them to pass for this policy to pass. Amongst the benefits of this policy are
 * increased security due to not needing to write a custom policy which combines the logic of the
 * desired combinations.
 *
 */
contract CombinedPoliciesPolicy is FirewallPolicyBase {

    bytes32[] public allowedCombinationHashes;

    // combination hash => bool
    mapping (bytes32 combinationHash => bool isAllowedHash) public isAllowedCombination;

    address[] public policies;
    bool[][] public currentResults;

    constructor(address _firewallAddress) FirewallPolicyBase() {
        authorizedExecutors[_firewallAddress] = true;
    }

    /**
     * @dev This function is called before the execution of a transaction.
     * It calls the preExecution function of all the policies and stores the results.
     *
     * @param consumer The address of the contract that is being called.
     * @param sender The address of the contract that is calling the consumer.
     * @param data The data of the transaction.
     * @param value The value of the transaction.
     */
    function preExecution(address consumer, address sender, bytes calldata data, uint256 value) external isAuthorized(consumer) {
        bool[] memory currentResult = new bool[](policies.length);
        for (uint256 i = 0; i < policies.length; i++) {
            IFirewallPolicy policy = IFirewallPolicy(policies[i]);
            try policy.preExecution(consumer, sender, data, value) {
                currentResult[i] = true;
            } catch {
                // Do nothing
            }
        }
        currentResults.push(currentResult);
    }

    /**
     * @dev This function is called after the execution of a transaction.
     * It calls the postExecution function of all the policies and checks the results against the allowed combinations.
     *
     * @param consumer The address of the contract that is being called.
     * @param sender The address of the contract that is calling the consumer.
     * @param data The data of the transaction.
     * @param value The value of the transaction.
     */
    function postExecution(address consumer, address sender, bytes calldata data, uint256 value) external isAuthorized(consumer) {
        bool[] memory currentResult = currentResults[currentResults.length - 1];
        currentResults.pop();
        for (uint256 i = 0; i < policies.length; i++) {
            IFirewallPolicy policy = IFirewallPolicy(policies[i]);
            try policy.postExecution(consumer, sender, data, value) {
                // Do nothing
            } catch {
                currentResult[i] = false;
            }
        }
        bytes32 combinationHash = keccak256(abi.encodePacked(currentResult));
        require(isAllowedCombination[combinationHash], "CombinedPoliciesPolicy: Disallowed combination");
    }

    /**
     * @dev This function is called to set the allowed combinations of policies.
     *
     * @param _policies The policies to combine.
     * @param _allowedCombinations The allowed combinations of the policies.
     */
    function setAllowedCombinations(address[] calldata _policies, bool[][] calldata _allowedCombinations) external onlyRole(POLICY_ADMIN_ROLE) {
        // Reset all combinations to false
        for (uint256 i = 0; i < allowedCombinationHashes.length; i++) {
            isAllowedCombination[allowedCombinationHashes[i]] = false;
        }
        allowedCombinationHashes = new bytes32[](_allowedCombinations.length);
        // Set all new combinations to true
        for (uint256 i = 0; i < _allowedCombinations.length; i++) {
            require(_policies.length == _allowedCombinations[i].length, "CombinedPoliciesPolicy: Invalid combination length");
            isAllowedCombination[keccak256(abi.encodePacked(_allowedCombinations[i]))] = true;
            allowedCombinationHashes[i] = (keccak256(abi.encodePacked(_allowedCombinations[i])));
        }
        policies = _policies;
    }
}
