// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity ^0.8.19;

import {FirewallPolicyBase} from "./FirewallPolicyBase.sol";

/**
 * @dev This contract is a policy which requires a third party to approve any admin calls.
 *
 * This policy is useful for contracts that have sensitive admin functions that need to be called frequently, and you
 * don't necessarily want to use a multisig wallet to call them (although this can also be used on top of a multisig
 * for even better security). You can use this policy to allow a third party to approve the call after off-chain
 * authentication verifying that the owner of the contract is the one making the call.
 *
 * NOTE: By desgin, this policy does not support the same function multiple times in a single transaction.
 * This is a known tradeoff, which we believe makes for a good balance between security and usability.
 *
 */
contract AdminCallPolicy is FirewallPolicyBase {
    // The role that is allowed to approve admin calls.
    bytes32 public constant APPROVER_ROLE = keccak256("APPROVER_ROLE");

    // The default amount of time a call hash is valid for after it is approved.
    uint256 public expirationTime = 1 days;
    // The timestamp that a call hash was approved at (if approved at all).
    mapping (bytes32 callHash => uint256 approvedAtTimestamp) public adminCallHashApprovalTimestamp;

    constructor(address _firewallAddress) FirewallPolicyBase() {
        authorizedExecutors[_firewallAddress] = true;
    }

    /**
     * @dev This function is called before the execution of a transaction.
     * It checks if the call has been approved by a third party, and if it has, it checks if the approval has expired.
     *
     * @param consumer The address of the contract that is being called.
     * @param sender The address of the account that is calling the contract.
     * @param data The data that is being sent to the contract.
     * @param value The amount of value that is being sent to the contract.
     */
    function preExecution(address consumer, address sender, bytes calldata data, uint256 value) external isAuthorized(consumer) {
        bytes32 callHash = _getCallHash(consumer, sender, tx.origin, data, value);
        require(adminCallHashApprovalTimestamp[callHash] > 0, "AdminCallPolicy: Call not approved");
        require(adminCallHashApprovalTimestamp[callHash] + expirationTime > block.timestamp, "AdminCallPolicy: Call expired");
        adminCallHashApprovalTimestamp[callHash] = 0;
    }

    /**
     * @dev This function is called after the execution of a transaction.
     * It does nothing in this policy.
     */
    function postExecution(address, address, bytes calldata, uint256) external override {
    }

    /**
     * @dev This function is called to set the expiration time for approved call hashes.
     *
     * @param _expirationTime The new expiration time.
     */
    function setExpirationTime(uint256 _expirationTime) external onlyRole(APPROVER_ROLE) {
        expirationTime = _expirationTime;
    }

    /**
     * @dev This function is called to approve a call hash.
     *
     * @param _callHash The hash of the call that is being approved.
     */
    function approveCall(bytes32 _callHash) external onlyRole(APPROVER_ROLE) {
        adminCallHashApprovalTimestamp[_callHash] = block.timestamp;
    }

    /**
     * @dev Internal helper function to get the hash of a call.
     *
     * @param consumer The address of the contract that is being called.
     * @param sender The address of the account that is calling the contract.
     * @param origin The address of the account that originated the call.
     * @param data The data that is being sent to the contract.
     * @param value The amount of value that is being sent to the contract.
     * @return The hash of the call.
     */
    function _getCallHash(
        address consumer,
        address sender,
        address origin,
        bytes memory data,
        uint256 value
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(consumer, sender, origin, data, value));
    }

}
