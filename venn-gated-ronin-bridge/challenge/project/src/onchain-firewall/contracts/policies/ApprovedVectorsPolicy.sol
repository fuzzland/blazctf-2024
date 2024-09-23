// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity ^0.8.19;

import {FirewallPolicyBase} from "./FirewallPolicyBase.sol";

/**
 * @dev This policy requires a transaction to follow a pre-approved pattern of external and/or internal calls
 * to a protocol or set of contracts.
 *
 * This policy is useful for contracts that want to protect against zero day business logic exploits. By pre
 * approving a large and tested amount of known and approved "vectors" or "patterns", a protocol can allow
 * the vast majority of transactions to pass without requiring any type asynchronous approval mechanism.
 *
 * NOTE: Misconfiguration of the approved vectors may result in legitimate transactions being reverted.
 * For example, execution paths that include internal calls must also be included as approved vectors
 * in order to work as expected.
 *
 * If you have any questions on how or when to use this modifier, please refer to the Firewall's documentation
 * and/or contact our support.
 *
 */
contract ApprovedVectorsPolicy is FirewallPolicyBase {

    // Execution States
    // tx.origin => block.number => vectorHash
    mapping (address txOrigin => mapping(uint256 blockNumber => bytes32 currentVectorHash)) public originCurrentVectorHash;
    // Vector Hashes Approval Status
    mapping (bytes32 vectorHash => bool isApproved) public approvedVectorHashes;

    constructor(address _firewallAddress) FirewallPolicyBase() {
        authorizedExecutors[_firewallAddress] = true;
    }

    /**
     * @dev Before executing a call, check that the call has been approved by a signer.
     *
     * @param consumer The address of the contract that is being called.
     */
    function preExecution(address consumer, address, bytes calldata data, uint256) external isAuthorized(consumer) {
        bytes32 currentVectorHash = originCurrentVectorHash[tx.origin][block.number];
        bytes4 selector = bytes4(data);
        bytes32 newVectorHash = keccak256(abi.encodePacked(currentVectorHash, selector));
        require(approvedVectorHashes[newVectorHash], "ApprovedVectorsPolicy: Unapproved Vector");
        originCurrentVectorHash[tx.origin][block.number] = newVectorHash;
    }

    /**
     * @dev This function is called after the execution of a transaction.
     * It does nothing in this policy.
     */
    function postExecution(address, address, bytes calldata, uint256) external override {
    }

    /**
     * @dev This function is called to approve multiple vector hashes.
     * This is useful for adding a large amount of vectors to the allowlist in a single transaction.
     *
     * @param _vectorHashes The vector hashes to approve.
     */
    function approveMultipleHashes(bytes32[] calldata _vectorHashes) external onlyRole(POLICY_ADMIN_ROLE) {
        for (uint256 i = 0; i < _vectorHashes.length; i++) {
            approvedVectorHashes[_vectorHashes[i]] = true;
        }
    }

    /**
     * @dev This function is called to remove multiple vector hashes from the allowlist.
     * This is useful for removing a large amount of vectors from the allowlist in a single transaction.
     *
     * @param _vectorHashes The vector hashes to remove.
     */
    function removeMultipleHashes(bytes32[] calldata _vectorHashes) external onlyRole(POLICY_ADMIN_ROLE) {
        for (uint256 i = 0; i < _vectorHashes.length; i++) {
            approvedVectorHashes[_vectorHashes[i]] = false;
        }
    }

    /**
     * @dev This function is called to set the status of a vector hash.
     *
     * @param _vectorHash The vector hash to set the status of.
     * @param _status The status to set the vector hash to.
     */
    function setVectorHashStatus(bytes32 _vectorHash, bool _status) external onlyRole(POLICY_ADMIN_ROLE) {
        approvedVectorHashes[_vectorHash] = _status;
    }

}
