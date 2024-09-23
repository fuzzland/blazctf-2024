// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity ^0.8.19;

import {Ownable2Step} from "./lib/openzeppelin/access/Ownable2Step.sol";
import {IFirewall} from "./interfaces/IFirewall.sol";
import {IFirewallConsumer} from "./interfaces/IFirewallConsumer.sol";
import {IFirewallPolicy} from "./interfaces/IFirewallPolicy.sol";
import {IFirewallPrivateInvariantsPolicy} from "./interfaces/IFirewallPrivateInvariantsPolicy.sol";

/**
 * @title Firewall
 * @author David Benchimol @ Ironblocks
 * @dev This contract provides an open marketplace of firewall policies that can be subscribed to by consumers.
 *
 * Each policy is a contract that must implement the IFirewallPolicy interface. The policy contract is responsible for
 * making the decision on whether or not to allow a call to be executed. The policy contract gets access to the consumers
 * full context, including the sender, data, and value of the call as well as the ability to read state before and after
 * function execution.
 *
 * Each consumer is a contract whos policys are managed by a single admin. The admin is responsible for adding and removing
 * policies.
 */
contract Firewall is IFirewall, Ownable2Step {

    /**
     * @dev Emitted when a policy is approved or disapproved by the owner.
     * @param policy The address of the policy contract.
     * @param status The status of the policy.
     */
    event PolicyStatusUpdate(address policy, bool status);

    /**
     * @dev Emitted when a policy is globally added or to a consumer.
     * @param consumer The address of the consumer contract.
     * @param policy The address of the policy contract.
     */
    event GlobalPolicyAdded(address indexed consumer, address policy);

    /**
     * @dev Emitted when a policy is globally removed or from a consumer.
     * @param consumer The address of the consumer contract.
     * @param policy The address of the policy contract.
     */
    event GlobalPolicyRemoved(address indexed consumer, address policy);

    /**
     * @dev Emitted when a policy is added to a consumer.
     * @param consumer The address of the consumer contract.
     * @param methodSig The method signature of the consumer contract to which the policy applies
     * @param policy The address of the policy contract.
     */
    event PolicyAdded(address indexed consumer, bytes4 methodSig, address policy);

    /**
     * @dev Emitted when a policy is removed from a consumer.
     * @param consumer The address of the consumer contract.
     * @param methodSig The method signature of the consumer contract to which the policy applies
     * @param policy The address of the policy contract.
     */
    event PolicyRemoved(address indexed consumer, bytes4 methodSig, address policy);

    /**
     * @dev Emitted when a private invariants policy is set for a consumer.
     * @param consumer The address of the consumer contract.
     * @param methodSig The method signature of the consumer contract to which the policy applies
     * @param policy The address of the policy contract.
     */
    event InvariantPolicySet(address indexed consumer, bytes4 methodSig, address policy);

    /**
     * @dev Emitted when a policy's pre-execution hook was succesfully executed in dry-run mode.
     * @param consumer The address of the consumer contract.
     * @param methodSig The method signature of the consumer contract to which the policy applies
     * @param policy The address of the policy contract.
     */
    event DryrunPolicyPreSuccess(address indexed consumer, bytes4 methodSig, address policy);

    /**
     * @dev Emitted when a policy's post-execution hook was succesfully executed in dry-run mode.
     * @param consumer The address of the consumer contract.
     * @param methodSig The method signature of the consumer contract to which the policy applies
     * @param policy The address of the policy contract.
     */
    event DryrunPolicyPostSuccess(address indexed consumer, bytes4 methodSig, address policy);

    /**
     * @dev Emitted when a policy's pre-execution hook failed in dry-run mode.
     * @param consumer The address of the consumer contract.
     * @param methodSig The method signature of the consumer contract to which the policy applies
     * @param policy The address of the policy contract.
     * @param error The error message.
     */
    event DryrunPolicyPreError(address indexed consumer, bytes4 methodSig, address policy, bytes error);

    /**
     * @dev Emitted when a policy's post-execution hook failed in dry-run mode.
     * @param consumer The address of the consumer contract.
     * @param methodSig The method signature of the consumer contract to which the policy applies
     * @param policy The address of the policy contract.
     * @param error The error message.
     */
    event DryrunPolicyPostError(address indexed consumer, bytes4 methodSig, address policy, bytes error);

    /**
     * @dev Emitted when a private invariants policy's pre-execution hook was succesfully executed in dry-run mode.
     * @param consumer The address of the consumer contract.
     * @param methodSig The method signature of the consumer contract to which the policy applies
     * @param policy The address of the policy contract.
     */
    event DryrunInvariantPolicyPreSuccess(address indexed consumer, bytes4 methodSig, address policy);

    /**
     * @dev Emitted when a private invariants policy's post-execution hook was succesfully executed in dry-run mode.
     * @param consumer The address of the consumer contract.
     * @param methodSig The method signature of the consumer contract to which the policy applies
     * @param policy The address of the policy contract.
     */
    event DryrunInvariantPolicyPostSuccess(address indexed consumer, bytes4 methodSig, address policy);

    /**
     * @dev Emitted when a private invariants policy's pre-execution hook failed in dry-run mode.
     * @param consumer The address of the consumer contract.
     * @param methodSig The method signature of the consumer contract to which the policy applies
     * @param policy The address of the policy contract.
     * @param error The error message.
     */
    event DryrunInvariantPolicyPreError(address indexed consumer, bytes4 methodSig, address policy, bytes error);

    /**
     * @dev Emitted when a private invariants policy's post-execution hook failed in dry-run mode.
     * @param consumer The address of the consumer contract.
     * @param methodSig The method signature of the consumer contract to which the policy applies
     * @param policy The address of the policy contract.
     * @param error The error message.
     */
    event DryrunInvariantPolicyPostError(address indexed consumer, bytes4 methodSig, address policy, bytes error);

    /**
     * @dev Modifier to check if the caller is the consumer admin.
     * @param consumer The address of the consumer contract.
     */
    modifier onlyConsumerAdmin(address consumer) {
        require(msg.sender == IFirewallConsumer(consumer).firewallAdmin(), "Firewall: not consumer admin");
        _;
    }

    // Mapping of policies approved by firewall owner
    mapping (address policy => bool isApproved) public approvedPolicies;
    // Mapping of consumer + sighash to array of policy addresses
    mapping (address consumer => mapping (bytes4 sighash => address[] policies)) public subscribedPolicies;
    // Mapping of consumer to array of policy addresses applied to all consumer methods
    mapping (address consumer => address[] globalPolicies) public subscribedGlobalPolicies;
    // Mapping of consumer + sighash to a single invariant policy
    mapping (address consumer => mapping (bytes4 sighash => address privateInvariantsPolicy)) public subscribedPrivateInvariantsPolicy;
    // Mapping of consumer to boolean indicating whether dry-run mode is enabled or not
    mapping (address consumer => bool dryrun) public dryrunEnabled;

    /**
     * @dev Runs the preExecution hook of all subscribed policies.
     * @param sender The address of the caller.
     * @param data The calldata of the call (some firewall modifiers may pass custom data based on the use case)
     * @param value The value of the call.
     */
    function preExecution(address sender, bytes calldata data, uint256 value) external override {
        bytes4 selector = bytes4(data);
        address[] memory policies = subscribedPolicies[msg.sender][selector];
        address[] memory globalPolicies = subscribedGlobalPolicies[msg.sender];
        if (dryrunEnabled[msg.sender]) {
            for (uint256 i = 0; i < policies.length; i++) {
                try IFirewallPolicy(policies[i]).preExecution(msg.sender, sender, data, value) {
                    emit DryrunPolicyPreSuccess(msg.sender, selector, policies[i]);
                } catch(bytes memory err) {
                    emit DryrunPolicyPreError(msg.sender, selector, policies[i], err);
                }
            }
            for (uint256 i = 0; i < globalPolicies.length; i++) {
                try IFirewallPolicy(globalPolicies[i]).preExecution(msg.sender, sender, data, value) {
                    emit DryrunPolicyPreSuccess(msg.sender, selector, globalPolicies[i]);
                } catch(bytes memory err) {
                    emit DryrunPolicyPreError(msg.sender, selector, globalPolicies[i], err);
                }
            }
        } else {
            for (uint256 i = 0; i < policies.length; i++) {
                IFirewallPolicy(policies[i]).preExecution(msg.sender, sender, data, value);
            }
            for (uint256 i = 0; i < globalPolicies.length; i++) {
                IFirewallPolicy(globalPolicies[i]).preExecution(msg.sender, sender, data, value);
            }
        }
    }

    /**
     * @dev Runs the postExecution hook of all subscribed policies.
     * @param sender The address of the caller.
     * @param data The calldata of the call (some firewall modifiers may pass custom data based on the use case)
     * @param value The value of the call.
     */
    function postExecution(address sender, bytes calldata data, uint256 value) external override {
        bytes4 selector = bytes4(data);
        address[] memory policies = subscribedPolicies[msg.sender][selector];
        address[] memory globalPolicies = subscribedGlobalPolicies[msg.sender];
        if (dryrunEnabled[msg.sender]) {
            for (uint256 i = 0; i < policies.length; i++) {
                try IFirewallPolicy(policies[i]).postExecution(msg.sender, sender, data, value) {
                    emit DryrunPolicyPostSuccess(msg.sender, selector, policies[i]);
                } catch(bytes memory err) {
                    emit DryrunPolicyPostError(msg.sender, selector, policies[i], err);
                }
            }
            for (uint256 i = 0; i < globalPolicies.length; i++) {
                try IFirewallPolicy(globalPolicies[i]).postExecution(msg.sender, sender, data, value) {
                    emit DryrunPolicyPostSuccess(msg.sender, selector, globalPolicies[i]);
                } catch(bytes memory err) {
                    emit DryrunPolicyPostError(msg.sender, selector, globalPolicies[i], err);
                }
            }
        } else {
            for (uint256 i = 0; i < policies.length; i++) {
                IFirewallPolicy(policies[i]).postExecution(msg.sender, sender, data, value);
            }
            for (uint256 i = 0; i < globalPolicies.length; i++) {
                IFirewallPolicy(globalPolicies[i]).postExecution(msg.sender, sender, data, value);
            }
        }
    }


    /**
     * @dev Runs the preExecution hook of private variables policy
     * @param sender The address of the caller.
     * @param data The calldata of the call (some firewall modifiers may pass custom data based on the use case)
     * @param value The value of the call.
     * @return storageSlots The storage slots that the policy wants to read
     */
    function preExecutionPrivateInvariants(
        address sender,
        bytes calldata data,
        uint256 value
    ) external override returns (bytes32[] memory storageSlots) {
        bytes4 selector = bytes4(data);
        address privateInvariantsPolicy = subscribedPrivateInvariantsPolicy[msg.sender][selector];
        if (privateInvariantsPolicy == address(0)) {
            return storageSlots;
        }
        if (dryrunEnabled[msg.sender]) {
            try IFirewallPrivateInvariantsPolicy(privateInvariantsPolicy).preExecution(msg.sender, sender, data, value) returns (bytes32[] memory sSlots) {
                storageSlots = sSlots;
                emit DryrunInvariantPolicyPreSuccess(msg.sender, selector, privateInvariantsPolicy);
            } catch(bytes memory err) {
                emit DryrunInvariantPolicyPreError(msg.sender, selector, privateInvariantsPolicy, err);
            }
        } else {
            storageSlots = IFirewallPrivateInvariantsPolicy(privateInvariantsPolicy).preExecution(msg.sender, sender, data, value);
        }
    }

    /**
     * @dev Runs the postExecution hook of private variables policy
     * @param sender The address of the caller.
     * @param data The calldata of the call (some firewall modifiers may pass custom data
     * based on the use case)
     * @param value The value of the call.
     * @param preValues The values of the storage slots before the original call
     * @param postValues The values of the storage slots after the original call
     */
    function postExecutionPrivateInvariants(
        address sender,
        bytes memory data,
        uint256 value,
        bytes32[] calldata preValues,
        bytes32[] calldata postValues
    ) external override {
        bytes4 selector = bytes4(data);
        address privateInvariantsPolicy = subscribedPrivateInvariantsPolicy[msg.sender][selector];
        if (privateInvariantsPolicy == address(0)) {
            return;
        }
        if (dryrunEnabled[msg.sender]) {
            try IFirewallPrivateInvariantsPolicy(privateInvariantsPolicy).postExecution(msg.sender, sender, data, value, preValues, postValues) {
                emit DryrunInvariantPolicyPostSuccess(msg.sender, selector, privateInvariantsPolicy);
            } catch(bytes memory err) {
                emit DryrunInvariantPolicyPostError(msg.sender, selector, privateInvariantsPolicy, err);
            }
        } else {
            IFirewallPrivateInvariantsPolicy(privateInvariantsPolicy).postExecution(msg.sender, sender, data, value, preValues, postValues);
        }
    }

    /**
     * @dev Owner only function allowing the owner to approve or remove a policy contract. This allows the policy
     * to be subscribed to by consumers, or conversely no longer be allowed.
     * @param policy The address of the policy contract.
     * @param status The status of the policy.
     */
    function setPolicyStatus(address policy, bool status) external onlyOwner {
        approvedPolicies[policy] = status;
        emit PolicyStatusUpdate(policy, status);
    }

    /**
     * @dev Admin only function allowing the consumers admin enable/disable dry run mode.
     * @param consumer The address of the consumer contract.
     * @param status The status of the dry run mode.
     */
    function setConsumerDryrunStatus(address consumer, bool status) external onlyConsumerAdmin(consumer) {
        dryrunEnabled[consumer] = status;
    }

    /**
     * @dev Admin only function allowing the consumers admin to add a policy to the consumers subscribed policies.
     * @param consumer The address of the consumer contract.
     * @param policy The address of the policy contract.
     *
     * NOTE: Policies that you register to may become obsolete in the future, there may be a an upgraded
     * version of the policy in the future, and / or a new vulnerability may be found in a policy at some
     * future time. For these reason, the Firewall Owner has the ability to disapprove a policy in the future,
     * preventing consumers from being able to subscribe to it in the future.
     *
     * While doesn't block already-subscribed consumers from using the policy, it is highly recommended
     * to have periodical reviews of the policies you are subscribed to and to make any required changes
     * accordingly.
     */
    function addGlobalPolicy(address consumer, address policy) external onlyConsumerAdmin(consumer) {
        _addGlobalPolicy(consumer, policy);
    }

    /**
     * @dev Admin only function allowing the consumers admin to remove a policy from the consumers subscribed policies.
     * @param consumer The address of the consumer contract.
     * @param policy The address of the policy contract.
     */
    function removeGlobalPolicy(address consumer, address policy) external onlyConsumerAdmin(consumer) {
        _removeGlobalPolicy(consumer, policy);
    }

    /**
     * @dev Admin only function allowing the consumers admin to add a single policy to multiple consumers.
     * Note that the consumer admin needs to be the same for all consumers
     *
     * @param consumers The addresses of the consumer contracts.
     * @param policy The address of the policy contract.
     * NOTE: Policies that you register to may become obsolete in the future, there may be a an upgraded
     * version of the policy in the future, and / or a new vulnerability may be found in a policy at some
     * future time. For these reason, the Firewall Owner has the ability to disapprove a policy in the future,
     * preventing consumers from being able to subscribe to it in the future.
     *
     * While doesn't block already-subscribed consumers from using the policy, it is highly recommended
     * to have periodical reviews of the policies you are subscribed to and to make any required changes
     * accordingly.
     */
    function addGlobalPolicyForConsumers(address[] calldata consumers, address policy) external {
        for (uint256 i = 0; i < consumers.length; i++) {
            require(msg.sender == IFirewallConsumer(consumers[i]).firewallAdmin(), "Firewall: not consumer admin");
            _addGlobalPolicy(consumers[i], policy);
        }
    }

    /**
     * @dev Admin only function allowing the consumers admin to remove a single policy from multiple consumers.
     * Note that the consumer admin needs to be the same for all consumers
     *
     * @param consumers The addresses of the consumer contracts.
     * @param policy The address of the policy contract.
     */
    function removeGlobalPolicyForConsumers(address[] calldata consumers, address policy) external {
        for (uint256 i = 0; i < consumers.length; i++) {
            require(msg.sender == IFirewallConsumer(consumers[i]).firewallAdmin(), "Firewall: not consumer admin");
            _removeGlobalPolicy(consumers[i], policy);
        }
    }

    /**
     * @dev Admin only function allowing the consumers admin to add multiple policies to the consumers subscribed policies.
     * @param consumer The address of the consumer contract.
     * @param methodSigs The method signatures of the consumer contract to which the policies apply
     * @param policies The addresses of the policy contracts.
     *
     * NOTE: Policies that you register to may become obsolete in the future, there may be a an upgraded
     * version of the policy in the future, and / or a new vulnerability may be found in a policy at some
     * future time. For these reason, the Firewall Owner has the ability to disapprove a policy in the future,
     * preventing consumers from being able to subscribe to it in the future.
     *
     * While doesn't block already-subscribed consumers from using the policy, it is highly recommended
     * to have periodical reviews of the policies you are subscribed to and to make any required changes
     * accordingly.
     */
    function addPolicies(address consumer, bytes4[] calldata methodSigs, address[] calldata policies) external onlyConsumerAdmin(consumer) {
        for (uint256 i = 0; i < policies.length; i++) {
            _addPolicy(consumer, methodSigs[i], policies[i]);
        }
    }

    /**
     * @dev Admin only function allowing the consumers admin to add a policy to the consumers subscribed policies.
     * @param consumer The address of the consumer contract.
     * @param methodSig The method signature of the consumer contract to which the policy applies
     * @param policy The address of the policy contract.
     *
     * NOTE: Policies that you register to may become obsolete in the future, there may be a an upgraded
     * version of the policy in the future, and / or a new vulnerability may be found in a policy at some
     * future time. For these reason, the Firewall Owner has the ability to disapprove a policy in the future,
     * preventing consumers from being able to subscribe to it in the future.
     *
     * While doesn't block already-subscribed consumers from using the policy, it is highly recommended
     * to have periodical reviews of the policies you are subscribed to and to make any required changes
     * accordingly.
     */
    function addPolicy(address consumer, bytes4 methodSig, address policy) external onlyConsumerAdmin(consumer) {
        _addPolicy(consumer, methodSig, policy);
    }

    /**
     * @dev Admin only function allowing the consumers admin to remove multiple policies from the consumers subscribed policies.
     * @param consumer The address of the consumer contract.
     * @param methodSigs The method signatures of the consumer contract to which the policies apply
     * @param policies The addresses of the policy contracts.
     */
    function removePolicies(address consumer, bytes4[] calldata methodSigs, address[] calldata policies) external onlyConsumerAdmin(consumer) {
        for (uint256 i = 0; i < policies.length; i++) {
            _removePolicy(consumer, methodSigs[i], policies[i]);
        }
    }

    /**
     * @dev Admin only function allowing the consumers admin to remove a policy from the consumers subscribed policies.
     * @param consumer The address of the consumer contract.
     * @param methodSig The method signature of the consumer contract to which the policy applies
     * @param policy The address of the policy contract.
     */
    function removePolicy(address consumer, bytes4 methodSig, address policy) external onlyConsumerAdmin(consumer) {
        _removePolicy(consumer, methodSig, policy);
    }

    /**
     * @dev Admin only function allowing the consumers admin to set the private variables policies
     * @param consumer The address of the consumer contract.
     * @param methodSigs The method signatures of the consumer contract to which the policies apply
     * @param policies The addresses of the policy contracts.
     */
    function setPrivateInvariantsPolicy(address consumer, bytes4[] calldata methodSigs, address[] calldata policies) external onlyConsumerAdmin(consumer) {
        for (uint256 i = 0; i < policies.length; i++) {
            require(approvedPolicies[policies[i]], "Firewall: policy not approved");
            subscribedPrivateInvariantsPolicy[consumer][methodSigs[i]] = policies[i];
            emit InvariantPolicySet(consumer, methodSigs[i], policies[i]);
        }
    }

    /**
     * @dev View function for retrieving a consumers subscribed policies for a given method.
     * @param consumer The address of the consumer contract.
     * @param methodSig The method signature of the consumer contract.
     * @return policies The addresses of the policy contracts.
     */
    function getActivePolicies(address consumer, bytes4 methodSig) external view returns (address[] memory) {
        return subscribedPolicies[consumer][methodSig];
    }

    /**
     * @dev View function for retrieving a consumers subscribed global policies.
     * @param consumer The address of the consumer contract.
     * @return policies The addresses of the policy contracts.
     */
    function getActiveGlobalPolicies(address consumer) external view returns (address[] memory) {
        return subscribedGlobalPolicies[consumer];
    }

    /**
     * @dev Internal function for adding a policy to a consumer.
     * @param consumer The address of the consumer contract.
     * @param methodSig The method signature of the consumer contract to which the policy applies
     * @param policy The address of the policy contract.
     */
    function _addPolicy(address consumer, bytes4 methodSig, address policy) internal {
        require(approvedPolicies[policy], "Firewall: policy not approved");
        address[] memory policies = subscribedPolicies[consumer][methodSig];
        for (uint256 i = 0; i < policies.length; i++) {
            require(policy != policies[i], "Firewall: policy already exists");
        }
        subscribedPolicies[consumer][methodSig].push(policy);
        emit PolicyAdded(consumer, methodSig, policy);
    }

    /**
     * @dev Internal function for removing a policy from a consumer.
     * @param consumer The address of the consumer contract.
     * @param methodSig The method signature of the consumer contract to which the policy applies
     * @param policy The address of the policy contract.
     */
    function _removePolicy(address consumer, bytes4 methodSig, address policy) internal {
        address[] storage policies = subscribedPolicies[consumer][methodSig];
        for (uint256 i = 0; i < policies.length; i++) {
            if (policy == policies[i]) {
                policies[i] = policies[policies.length - 1];
                policies.pop();
                emit PolicyRemoved(consumer, methodSig, policy);
                return;
            }
        }
    }

    /**
     * @dev Internal function for adding a global policy to a consumer.
     * @param consumer The address of the consumer contract.
     * @param policy The address of the policy contract.
     */
    function _addGlobalPolicy(address consumer, address policy) internal {
        require(approvedPolicies[policy], "Firewall: policy not approved");
        address[] memory policies = subscribedGlobalPolicies[consumer];
        for (uint256 i = 0; i < policies.length; i++) {
            require(policy != policies[i], "Firewall: policy already exists");
        }
        subscribedGlobalPolicies[consumer].push(policy);
        emit GlobalPolicyAdded(consumer, policy);
    }

    /**
     * @dev Internal function for removing a global policy from a consumer.
     * @param consumer The address of the consumer contract.
     * @param policy The address of the policy contract.
     */
    function _removeGlobalPolicy(address consumer, address policy) internal {
        address[] storage globalPolicies = subscribedGlobalPolicies[consumer];
        for (uint256 i = 0; i < globalPolicies.length; i++) {
            if (policy == globalPolicies[i]) {
                globalPolicies[i] = globalPolicies[globalPolicies.length - 1];
                globalPolicies.pop();
                emit GlobalPolicyRemoved(consumer, policy);
                return;
            }
        }
    }
}
