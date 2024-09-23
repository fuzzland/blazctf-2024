// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2024
pragma solidity ^0.8.0;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IFirewall} from "../interfaces/IFirewall.sol";
import {IFirewallConsumerStorage} from "../interfaces/IFirewallConsumerStorage.sol";

/**
 * @title Firewall Consumer Storage Contract
 * @author David Benchimol @ Ironblocks
 * @dev This contract is a parent contract that can be used to add firewall protection to any contract.
 *
 * The contract must define a firewall contract which will manage the policies that are applied to the contract.
 * It also must define a firewall admin which will be able to add and remove policies.
 *
 */
contract FirewallConsumerStorage is IFirewallConsumerStorage {

    // This slot is used to store the firewall address
    bytes32 private constant FIREWALL_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.firewall")) - 1);

    // This slot is used to store the firewall admin address
    bytes32 private constant FIREWALL_ADMIN_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.firewall.admin")) - 1);

    // This slot is used to store the new firewall admin address (when changing admin)
    bytes32 private constant NEW_FIREWALL_ADMIN_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.new.firewall.admin")) - 1);

    bytes32 private constant APPROVED_VENN_POLICY_SLOT = bytes32(uint256(keccak256("eip1967.approved.venn.policy")) - 1);

    bytes32 private constant USER_NATIVE_FEE_SLOT = bytes32(uint256(keccak256("eip1967.user.native.fee")) - 1);

    event FirewallAdminUpdated(address newAdmin);
    event FirewallUpdated(address newFirewall);

    /**
     * @dev modifier similar to onlyOwner, but for the firewall admin.
     */
    modifier onlyFirewallAdmin() {
        require(msg.sender == _getAddressBySlot(FIREWALL_ADMIN_STORAGE_SLOT), "FirewallConsumer: not firewall admin");
        _;
    }

    /**
     * @dev Initializes a contract protected by a firewall, with a firewall address and a firewall admin.
     */
    constructor(
        address _firewall,
        address _firewallAdmin
    ) {
        _setAddressBySlot(FIREWALL_STORAGE_SLOT, _firewall);
        _setAddressBySlot(FIREWALL_ADMIN_STORAGE_SLOT, _firewallAdmin);
    }

    function getApprovedVennPolicy() external view returns (address) {
        return _getAddressBySlot(APPROVED_VENN_POLICY_SLOT);
    }

    function getUserNativeFee() external view returns (uint256) {
        return uint256(_getValueBySlot(USER_NATIVE_FEE_SLOT));
    }

    function getFirewall() external view returns (address) {
        return _getAddressBySlot(FIREWALL_STORAGE_SLOT);
    }

    function getFirewallAdmin() external view returns (address) {
        return _getAddressBySlot(FIREWALL_ADMIN_STORAGE_SLOT);
    }

    /**
     * @dev Allows firewall admin to set Venn policy.
     * IMPORTANT: Only set approved Venn policy if you know what you're doing. Anyone can cause this contract
     * to send any data to an approved Venn policy.
     *
     * @param vennPolicy address of the Venn policy
     */
    function setVennPolicy(address vennPolicy) external onlyFirewallAdmin {
        _setAddressBySlot(APPROVED_VENN_POLICY_SLOT, vennPolicy);
    }

    /**
     * @dev Allows firewall admin to set user native fee for safeFunctionCall.
     *
     * @param fee native fee for the user
     */
    function setUserNativeFee(uint256 fee) external onlyFirewallAdmin {
        _setValueBySlot(USER_NATIVE_FEE_SLOT, fee);
    }

    /**
     * @dev Admin only function allowing the consumers admin to set the firewall address.
     * @param _firewall address of the firewall
     */
    function setFirewall(address _firewall) external onlyFirewallAdmin {
        _setAddressBySlot(FIREWALL_STORAGE_SLOT, _firewall);
        emit FirewallUpdated(_firewall);
    }

    /**
     * @dev Admin only function, sets new firewall admin. New admin must accept.
     * @param _firewallAdmin address of the new firewall admin
     */
    function setFirewallAdmin(address _firewallAdmin) external onlyFirewallAdmin {
        require(_firewallAdmin != address(0), "FirewallConsumer: zero address");
        _setAddressBySlot(NEW_FIREWALL_ADMIN_STORAGE_SLOT, _firewallAdmin);
    }

    /**
     * @dev Accept the role as firewall admin.
     */
    function acceptFirewallAdmin() external {
        require(msg.sender == _getAddressBySlot(NEW_FIREWALL_ADMIN_STORAGE_SLOT), "FirewallConsumer: not new admin");
        _setAddressBySlot(FIREWALL_ADMIN_STORAGE_SLOT, msg.sender);
        emit FirewallAdminUpdated(msg.sender);
    }

    /**
     * @dev Internal helper function to set an address in a storage slot
     * @param _slot storage slot
     * @param _address address to be set
     */
    function _setAddressBySlot(bytes32 _slot, address _address) internal {
        assembly {
            sstore(_slot, _address)
        }
    }

    /**
     * @dev Internal helper function to get an address from a storage slot
     * @param _slot storage slot
     * @return _address from the storage slot
     */
    function _getAddressBySlot(bytes32 _slot) internal view returns (address _address) {
        assembly {
            _address := sload(_slot)
        }
    }

    function _setValueBySlot(bytes32 _slot, uint256 _value) internal {
        assembly {
            sstore(_slot, _value)
        }
    }

    /**
     * @dev Internal helper function to get a value from a storage slot
     * @param _slot storage slot
     * @return _value from the storage slot
     */
    function _getValueBySlot(bytes32 _slot) internal view returns (bytes32 _value) {
        assembly {
            _value := sload(_slot)
        }
    }
}