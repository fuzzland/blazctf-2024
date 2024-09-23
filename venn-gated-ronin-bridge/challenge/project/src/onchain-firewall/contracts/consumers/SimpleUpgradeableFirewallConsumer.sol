// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2024
pragma solidity ^0.8.0;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IFirewall} from "../interfaces/IFirewall.sol";
import {IFirewallConsumer} from "../interfaces/IFirewallConsumer.sol";
import {IFirewallConsumerStorage} from "../interfaces/IFirewallConsumerStorage.sol";

/**
 * @title Firewall Minimal Upgradeable Consumer Contract
 * @author David Benchimol @ Ironblocks
 * @dev This contract is a parent contract that can be used to add firewall protection to any contract.
 *
 * The contract is the most minimal upgradeable contract that implements the FirewallConsumer interface.
 *
 */
contract SimpleUpgradeableFirewallConsumer is IFirewallConsumer, Initializable {

    // This slot is used to store the consumer storage address
    bytes32 private constant FIREWALL_CONSUMER_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.firewall.consumer.storage")) - 1);
    bytes32 private constant FIREWALL_CONSUMER_INITIALIZER_FIREWALL_ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.firewall.consumer.initializer.firewall.admin")) - 1);

    /**
     * @dev modifier that will run the preExecution and postExecution hooks of the firewall, applying each of
     * the subscribed policies.
     *
     * NOTE: Applying this modifier on functions that exit execution flow by an inline assmebly "return" call will
     * prevent the postExecution hook from running - breaking the protection provided by the firewall.
     * If you have any questions, please refer to the Firewall's documentation and/or contact our support.
     */
    modifier firewallProtected() {
        address firewallConsumerStorage = _getFirewallConsumerStorage();
        if (firewallConsumerStorage == address(0)) {
            _;
            return;
        }
        address firewall = IFirewallConsumerStorage(firewallConsumerStorage).getFirewall();
        if (firewall == address(0)) {
            _;
            return;
        }
        // We do this because msg.value can only be accessed in payable functions.
        uint256 value;
        assembly {
            value := callvalue()
        }
        IFirewall(firewall).preExecution(msg.sender, msg.data, value);
        _;
        IFirewall(firewall).postExecution(msg.sender, msg.data, value);
    }

    /**
     * @dev modifier similar to onlyOwner, but for the firewall admin.
     */
    modifier onlyFirewallAdmin() {
        require(msg.sender == _getFirewallAdmin(), "FirewallConsumer: not firewall admin");
        _;
    }

    /**
     * @dev Allows calling an approved external Venn policy before executing a method.
     *
     * This can be used for multiple purposes, but the initial one is to call `approveCallsViaSignature` before
     * executing a function, allowing synchronous transaction approvals.
     *
     * NOTE: If userNativeFee is non zero, functions using this must take into account that
     * the value received will be slightly less than msg.value due to the fee.
     *
     * @param vennPolicyPayload payload to be sent to the Venn policy
     * @param data data to be executed after the Venn policy call
     */
    function safeFunctionCall(
        uint256 userNativeFee,
        bytes calldata vennPolicyPayload,
        bytes calldata data
    ) external payable {
        address firewallConsumerStorage = _getFirewallConsumerStorage();
        address vennPolicy = IFirewallConsumerStorage(firewallConsumerStorage).getApprovedVennPolicy();
        require(msg.value >= userNativeFee, "FirewallConsumer: Not enough native value for fee");
        (bool success,) = vennPolicy.call{value: userNativeFee}(vennPolicyPayload);
        require(success);
        Address.functionDelegateCall(address(this), data);
    }

    /**
     * @dev View function for the firewall admin
     */
    function firewallAdmin() external view returns (address) {
        return _getFirewallAdmin();
    }

    function setFirewallConsumerStorage(address _firewallConsumerStorage) external onlyFirewallAdmin {
        _setAddressBySlot(FIREWALL_CONSUMER_INITIALIZER_FIREWALL_ADMIN_SLOT, address(0));
        _setAddressBySlot(FIREWALL_CONSUMER_STORAGE_SLOT, _firewallConsumerStorage);
    }

    function __SimpleUpgradeableFirewallConsumer_init(IFirewallConsumerStorage _firewallConsumerStorage, address _firewallAdmin) internal onlyInitializing {
        require((address(_firewallConsumerStorage) != address(0)) || _firewallAdmin != address(0), "FirewallConsumer: must have firewall consumer storage or firewall admin");
        address _firewallConsumerStorageAddress = address(_firewallConsumerStorage);
        if (_firewallConsumerStorageAddress == address(0)) {
            _setAddressBySlot(FIREWALL_CONSUMER_INITIALIZER_FIREWALL_ADMIN_SLOT, _firewallAdmin);
            return;
        }
        _setAddressBySlot(FIREWALL_CONSUMER_STORAGE_SLOT, _firewallConsumerStorageAddress);
    }

    /**
     * @dev Internal view function for the firewall admin
     */
    function _getFirewallAdmin() internal view returns (address) {
        address firewallConsumerStorage = _getFirewallConsumerStorage();
        if (firewallConsumerStorage == address(0)) {
            return _getAddressBySlot(FIREWALL_CONSUMER_INITIALIZER_FIREWALL_ADMIN_SLOT);
        }
        return IFirewallConsumerStorage(firewallConsumerStorage).getFirewallAdmin();
    }

    /**
     * @dev Internal view function for the consumer storage
     */
    function _getFirewallConsumerStorage() internal view returns (address) {
        return _getAddressBySlot(FIREWALL_CONSUMER_STORAGE_SLOT);
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

}