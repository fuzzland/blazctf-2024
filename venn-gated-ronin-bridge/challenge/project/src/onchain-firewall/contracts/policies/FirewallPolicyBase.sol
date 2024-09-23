// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity ^0.8.19;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IFirewallPolicy} from "../interfaces/IFirewallPolicy.sol";

abstract contract FirewallPolicyBase is IFirewallPolicy, AccessControl {
    bytes32 public constant POLICY_ADMIN_ROLE = keccak256("POLICY_ADMIN_ROLE");

    mapping (address executor => bool authorized) public authorizedExecutors;
    mapping (address consumer => bool approved) public approvedConsumer;

    /**
     * @dev Modifier to check if the consumer is authorized to execute the function.
     */
    modifier isAuthorized(address consumer) {
        require(authorizedExecutors[msg.sender], "FirewallPolicy: Only authorized executor");
        require(approvedConsumer[consumer], "FirewallPolicy: Only approved consumers");
        _;
    }

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Sets approval status of multiple consumers.
     * This is useful for adding a large amount of consumers to the allowlist in a single transaction.
     *
     * @param consumers The consumers to set the approval status for.
     * @param statuses The approval status to set.
     */
    function setConsumersStatuses(address[] calldata consumers, bool[] calldata statuses) external onlyRole(POLICY_ADMIN_ROLE) {
        for (uint256 i = 0; i < consumers.length; i++) {
            approvedConsumer[consumers[i]] = statuses[i];
        }
    }

    /**
     * @dev Sets the executor status.
     *
     * @param caller The address of the executor.
     * @param status The executor status to set.
     */
    function setExecutorStatus(address caller, bool status) external onlyRole(POLICY_ADMIN_ROLE) {
        authorizedExecutors[caller] = status;
    }
}
