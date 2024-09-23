// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity ^0.8.19;

import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IFirewall} from "./interfaces/IFirewall.sol";
import {IFirewallConsumer} from "./interfaces/IFirewallConsumer.sol";

/**
 * @title Firewall Consumer Base Contract
 * @author David Benchimol @ Ironblocks
 * @dev This contract is a parent contract that can be used to add firewall protection to any contract.
 *
 * The contract must define a firewall contract which will manage the policies that are applied to the contract.
 * It also must define a firewall admin which will be able to add and remove policies.
 *
 */
contract FirewallConsumerBase is IFirewallConsumer, Context {

    // This slot is used to store the firewall address
    bytes32 private constant FIREWALL_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.firewall")) - 1);

    // This slot is used to store the firewall admin address
    bytes32 private constant FIREWALL_ADMIN_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.firewall.admin")) - 1);

    // This slot is used to store the new firewall admin address (when changing admin)
    bytes32 private constant NEW_FIREWALL_ADMIN_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.new.firewall.admin")) - 1);
    bytes4 private constant SUPPORTS_APPROVE_VIA_SIGNATURE_INTERFACE_ID = bytes4(0x0c908cff); // sighash of approveCallsViaSignature

    // This slot is special since it's used for mappings and not a single value
    bytes32 private constant APPROVED_VENN_POLICY_SLOT = bytes32(uint256(keccak256("eip1967.approved.venn.policy")) - 1);

    event FirewallAdminUpdated(address newAdmin);
    event FirewallUpdated(address newFirewall);

    /**
     * @dev modifier that will run the preExecution and postExecution hooks of the firewall, applying each of
     * the subscribed policies.
     *
     * NOTE: Applying this modifier on functions that exit execution flow by an inline assmebly "return" call will
     * prevent the postExecution hook from running - breaking the protection provided by the firewall.
     * If you have any questions, please refer to the Firewall's documentation and/or contact our support.
     */
    modifier firewallProtected() {
        address firewall = _getAddressBySlot(FIREWALL_STORAGE_SLOT);
        if (firewall == address(0)) {
            _;
            return;
        }
        uint256 value = _msgValue();
        IFirewall(firewall).preExecution(_msgSender(), _msgData(), value);
        _;
        IFirewall(firewall).postExecution(_msgSender(), _msgData(), value);
    }

    /**
     * @dev modifier that will run the preExecution and postExecution hooks of the firewall, applying each of
     * the subscribed policies. Allows passing custom data to the firewall, not necessarily msg.data.
     * Useful for checking internal function calls
     *
     * @param data custom data to be passed to the firewall
     * NOTE: Using this modifier affects the data that is passed to the firewall, and as such it is mainly meant
     * to be used by internal functions, and only in conjuction with policies that whose protection strategy
     * requires this data.
     *
     * Using this modifier incorrectly may result in unexpected behavior.
     *
     * If you have any questions on how or when to use this modifier, please refer to the Firewall's documentation
     * and/or contact our support.
     *
     * NOTE: Applying this modifier on functions that exit execution flow by an inline assmebly "return" call will
     * prevent the postExecution hook from running - breaking the protection provided by the firewall.
     * If you have any questions, please refer to the Firewall's documentation and/or contact our support.
     */
    modifier firewallProtectedCustom(bytes memory data) {
        address firewall = _getAddressBySlot(FIREWALL_STORAGE_SLOT);
        if (firewall == address(0)) {
            _;
            return;
        }
        uint256 value = _msgValue();
        IFirewall(firewall).preExecution(_msgSender(), data, value);
        _;
        IFirewall(firewall).postExecution(_msgSender(), data, value);
    }

    /**
     * @dev identical to the rest of the modifiers in terms of logic, but makes it more
     * aesthetic when all you want to pass are signatures/unique identifiers.
     *
     * @param selector unique identifier for the function
     *
     * NOTE: Using this modifier affects the data that is passed to the firewall, and as such it is mainly to
     * be used by policies that whose protection strategy relies on the function's signature hahs.
     *
     * Using this modifier incorrectly may result in unexpected behavior.
     *
     * If you have any questions on how or when to use this modifier, please refer to the Firewall's documentation
     * and/or contact our support.
     *
     * NOTE: Applying this modifier on functions that exit execution flow by an inline assmebly "return" call will
     * prevent the postExecution hook from running - breaking the protection provided by the firewall.
     * If you have any questions, please refer to the Firewall's documentation and/or contact our support.
     */
    modifier firewallProtectedSig(bytes4 selector) {
        address firewall = _getAddressBySlot(FIREWALL_STORAGE_SLOT);
        if (firewall == address(0)) {
            _;
            return;
        }
        uint256 value = _msgValue();
        IFirewall(firewall).preExecution(_msgSender(), abi.encodePacked(selector), value);
        _;
        IFirewall(firewall).postExecution(_msgSender(), abi.encodePacked(selector), value);
    }

    /**
     * @dev modifier that will run the preExecution and postExecution hooks of the firewall invariant policy,
     * applying the subscribed invariant policy
     *
     * NOTE: Applying this modifier on functions that exit execution flow by an inline assmebly "return" call will
     * prevent the postExecution hook from running - breaking the protection provided by the firewall.
     * If you have any questions, please refer to the Firewall's documentation and/or contact our support.
     */
    modifier invariantProtected() {
        address firewall = _getAddressBySlot(FIREWALL_STORAGE_SLOT);
        if (firewall == address(0)) {
            _;
            return;
        }
        uint256 value = _msgValue();
        bytes32[] memory storageSlots = IFirewall(firewall).preExecutionPrivateInvariants(_msgSender(), _msgData(), value);
        bytes32[] memory preValues = _readStorage(storageSlots);
        _;
        bytes32[] memory postValues = _readStorage(storageSlots);
        IFirewall(firewall).postExecutionPrivateInvariants(_msgSender(), _msgData(), value, preValues, postValues);
    }


    /**
     * @dev modifier asserting that the Venn policy is approved
     * @param vennPolicy address of the Venn policy
     */
    modifier onlyApprovedVennPolicy(address vennPolicy) {
        // We use the same logic that solidity uses for mapping locations, but we add a pseudorandom
        // constant "salt" instead of a constant placeholder so that there are no storage collisions
        // if adding this to an upgradeable contract implementation
        bytes32 _slot = keccak256(abi.encode(APPROVED_VENN_POLICY_SLOT, vennPolicy));
        bool isApprovedVennPolicy = _getValueBySlot(_slot) != bytes32(0);
        require(isApprovedVennPolicy, "FirewallConsumer: Not approved Venn policy");
        require(ERC165Checker.supportsERC165InterfaceUnchecked(vennPolicy, SUPPORTS_APPROVE_VIA_SIGNATURE_INTERFACE_ID));
        _;
    }

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

    /**
     * @dev Allows calling an approved external Venn policy before executing a method.
     *
     * This can be used for multiple purposes, but the initial one is to call `approveCallsViaSignature` before
     * executing a function, allowing synchronous transaction approvals.
     *
     * @param vennPolicy address of the Venn policy
     * @param vennPolicyPayload payload to be sent to the Venn policy
     * @param data data to be executed after the Venn policy call
     */
    function safeFunctionCall(
        address vennPolicy,
        bytes calldata vennPolicyPayload,
        bytes calldata data
    ) external payable onlyApprovedVennPolicy(vennPolicy) {
        (bool success, ) = vennPolicy.call(vennPolicyPayload);
        require(success);
        require(msg.sender == _msgSender(), "FirewallConsumer: No meta transactions");
        Address.functionDelegateCall(address(this), data);
    }

    /**
     * @dev Allows firewall admin to set approved Venn policies.
     * IMPORTANT: Only set approved Venn policy if you know what you're doing. Anyone can cause this contract
     * to send any data to an approved Venn policy.
     *
     * @param vennPolicy address of the Venn policy
     * @param status status of the Venn policy
     */
    function setApprovedVennPolicy(address vennPolicy, bool status) external onlyFirewallAdmin {
        bytes32 _slot = keccak256(abi.encode(APPROVED_VENN_POLICY_SLOT, vennPolicy));
        assembly {
            sstore(_slot, status)
        }
    }

    /**
     * @dev View function for the firewall admin
     */
    function firewallAdmin() external view returns (address) {
        return _getAddressBySlot(FIREWALL_ADMIN_STORAGE_SLOT);
    }

    /**
     * @dev Admin only function allowing the consumers admin to set the firewall address.
     * @param _firewall address of the firewall
     */
    function setFirewall(address _firewall) external onlyFirewallAdmin {
        internalSetFirewall(_firewall);
    }

    function internalSetFirewall(address _firewall) internal {
        _setAddressBySlot(FIREWALL_STORAGE_SLOT, _firewall);
        emit FirewallUpdated(_firewall);
    }

    /**
     * @dev Admin only function, sets new firewall admin. New admin must accept.
     * @param _firewallAdmin address of the new firewall admin
     */
    function setFirewallAdmin(address _firewallAdmin) external onlyFirewallAdmin {
        internalSetFirewallAdmin(_firewallAdmin);
    }

    function internalSetFirewallAdmin(address _firewallAdmin) internal {
        _setAddressBySlot(FIREWALL_ADMIN_STORAGE_SLOT, _firewallAdmin);
        emit FirewallAdminUpdated(_firewallAdmin);
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
     * @dev Internal helper funtion to get the msg.value
     * @return value of the msg.value
     */
    function _msgValue() internal view returns (uint256 value) {
        // We do this because msg.value can only be accessed in payable functions.
        assembly {
            value := callvalue()
        }
    }

    /**
     * @dev Internal helper function to read storage slots
     * @param storageSlots array of storage slots
     */
    function _readStorage(bytes32[] memory storageSlots) internal view returns (bytes32[] memory) {
        uint256 slotsLength = storageSlots.length;
        bytes32[] memory values = new bytes32[](slotsLength);

        for (uint256 i = 0; i < slotsLength; i++) {
            bytes32 slotValue = _getValueBySlot(storageSlots[i]);
            values[i] = slotValue;
        }
        return values;
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
