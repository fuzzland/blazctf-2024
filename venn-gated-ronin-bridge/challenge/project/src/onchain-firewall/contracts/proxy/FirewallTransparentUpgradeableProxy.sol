// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity ^0.8.19;

import {TransparentUpgradeableProxy, StorageSlot} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IFirewall} from "../interfaces/IFirewall.sol";
import {IFirewallConsumer} from "../interfaces/IFirewallConsumer.sol";

/**
 * @dev Interface for {FirewallTransparentUpgradeableProxy}. In order to implement transparency, {FirewallTransparentUpgradeableProxy}
 * does not implement this interface directly, and some of its functions are implemented by an internal dispatch
 * mechanism. The compiler is unaware that these functions are implemented by {FirewallTransparentUpgradeableProxy} and will not
 * include them in the ABI so this interface must be used to interact with it.
 */
interface IFirewallTransparentUpgradeableProxy {
    function firewall() external view returns (address);
    function firewallAdmin() external view returns (address);
    function changeFirewall(address) external;
    function changeFirewallAdmin(address) external;
}


/**
 * @title Firewall protected TransparentUpgradeableProxy
 * @author David Benchimol @ Ironblocks
 * @dev This contract acts the same as OpenZeppelins `TransparentUpgradeableProxy` contract,
 * but with Ironblocks firewall built in to the proxy layer.
 *
 */
contract FirewallTransparentUpgradeableProxy is TransparentUpgradeableProxy {

    bytes32 private constant FIREWALL_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.firewall")) - 1);
    bytes32 private constant FIREWALL_ADMIN_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.firewall.admin")) - 1);

    event FirewallAdminUpdated(address newAdmin);
    event FirewallUpdated(address newFirewall);
    /**
     * @dev Emitted when a static call is detected.
     */
    event StaticCallCheck();

    /**
     * @dev Initializes a firewall upgradeable proxy managed by `_admin`, backed by the implementation at `_logic`, and
     * optionally initialized with `_data` as explained in {ERC1967Proxy-constructor}.
     * Also sets _firewall and _firewallAdmin.
     */
    constructor(
        address _logic,
        address admin_,
        bytes memory _data,
        address _firewall,
        address _firewallAdmin
    )
        payable
        TransparentUpgradeableProxy(_logic, admin_, _data)
    {
        _changeFirewall(_firewall);
        _changeFirewallAdmin(_firewallAdmin);
    }

    /**
     * @dev modifier that will run the preExecution and postExecution hooks of the firewall, applying each of
     * the subscribed policies.
     *
     * NOTE: See the note comment above `_isStaticCall` regarding limitations of detecting
     * view functions through low-level calls.
     */
    modifier firewallProtected() {
        address _firewall = _getFirewall();
        // Skip if view function or firewall disabled
        if (_firewall == address(0) || _isStaticCall()) {
            _;
            return;
        }

        uint256 value;
        // We do this because msg.value can only be accessed in payable functions.
        assembly {
            value := callvalue()
        }
        IFirewall(_firewall).preExecution(msg.sender, msg.data, value);
        _;
        IFirewall(_firewall).postExecution(msg.sender, msg.data, value);
    }

    function staticCallCheck() external {
        emit StaticCallCheck();
    }

    /**
     * @dev NOTE: The `_isStaticCall` function is designed to distinguish between view (pure/constant) calls
     * and non-view calls to optimize interaction with the firewall. It relies on the `staticCallCheck` function,
     * expecting it to revert on static calls. However, this mechanism can be circumvented by using low-level call
     * operations to invoke view functions, which would not trigger the expected revert and thus not be recognized
     * by `_isStaticCall`. This means the `firewallProtected` modifier, which relies on `_isStaticCall`, may
     * inadvertently apply firewall checks to some view calls if they're invoked via low-level calls.
     *
     * Integrators should be aware of this limitation and consider it when designing their interactions with
     * this contract to avoid unexpected behavior.
     */
    function _isStaticCall() private returns (bool) {
        try this.staticCallCheck() {
            return false;
        } catch {
            return true;
        }
    }

    /**
     * @dev If caller is the admin process the call internally, otherwise if the caller is the firewall,
     * return the firewall admin, else transparently fallback to the proxy behavior
     */
    function _fallback() internal virtual override {
        if (msg.sender == _getAdmin()) {
            bytes memory ret;
            bytes4 selector = msg.sig;
            if (selector == IFirewallTransparentUpgradeableProxy.changeFirewall.selector) {
                ret = _dispatchChangeFirewall();
            } else if (selector == IFirewallTransparentUpgradeableProxy.changeFirewallAdmin.selector) {
                ret = _dispatchChangeFirewallAdmin();
            } else if (selector == IFirewallTransparentUpgradeableProxy.firewall.selector) {
                ret = _dispatchFirewall();
            } else if (selector == IFirewallTransparentUpgradeableProxy.firewallAdmin.selector) {
                ret = _dispatchFirewallAdmin();
            } else {
                super._fallback();
            }
            assembly {
                return(add(ret, 0x20), mload(ret))
            }
        } else if (msg.sender == _getFirewall()) {
            bytes memory ret;
            bytes4 selector = msg.sig;
            if (selector == IFirewallTransparentUpgradeableProxy.firewallAdmin.selector) {
                ret = _dispatchFirewallAdmin();
            } else {
                revert("TransparentUpgradeableProxy: firewall cannot fallback to proxy target");
            }
            assembly {
                return(add(ret, 0x20), mload(ret))
            } 
        } else {
            super._fallback();
        }
    }

    /**
     * @dev Admin only function allowing the consumers admin to change the firewall address
     */
    function _dispatchChangeFirewall() private returns (bytes memory) {
        _requireZeroMsgValue();
        address newFirewall = abi.decode(msg.data[4:], (address));
        require(newFirewall != address(0), "FirewallConsumer: zero address");
        _changeFirewall(newFirewall);
        return "";
    }

    /**
     * @dev Admin only function allowing the consumers admin to set a new admin
     */
    function _dispatchChangeFirewallAdmin() private returns (bytes memory) {
        _requireZeroMsgValue();
        address newFirewallAdmin = abi.decode(msg.data[4:], (address));
        require(newFirewallAdmin != address(0), "FirewallConsumer: zero address");
        _changeFirewallAdmin(newFirewallAdmin);
        return "";
    }

    /**
     * @dev Returns the current firewall address.
     *
     * NOTE: Only the admin can call this function. See {FirewallProxyAdmin-getProxyFirewall}.
     *
     * TIP: To get this value clients can read directly from the storage slot shown below (specified by EIP1967) using the
     * https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
     * `0x5dd2e3b890564a8f99f7f203f226a27a8aa59aee19a4ece5cf5eaa77ab91f661`
     */
    function _dispatchFirewall() private returns (bytes memory) {
        _requireZeroMsgValue();
        address firewall = _getFirewall();
        return abi.encode(firewall);
    }

    /**
     * @dev Returns the current firewall admin address.
     *
     * NOTE: Only the admin OR firewall can call this function. See {FirewallProxyAdmin-getProxyFirewallAdmin}.
     *
     * TIP: To get this value clients can read directly from the storage slot shown below (specified by EIP1967) using the
     * https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
     * `0x29982a6ac507a2a707ced6dee5d76285dd49725db977de83d9702c628c974135`
     */
    function _dispatchFirewallAdmin() private returns (bytes memory) {
        _requireZeroMsgValue();
        address firewallAdmin = _getFirewallAdmin();
        return abi.encode(firewallAdmin);
    }

    /**
     * @dev Returns the current firewall admin address.
     */
    function _getFirewallAdmin() private view returns (address) {
        return StorageSlot.getAddressSlot(FIREWALL_ADMIN_STORAGE_SLOT).value;
    }

    /**
     * @dev Stores a new address in the firewall admin implementation slot.
     */
    function _changeFirewallAdmin(address _firewallAdmin) private {
        StorageSlot.getAddressSlot(FIREWALL_ADMIN_STORAGE_SLOT).value = _firewallAdmin;
        emit FirewallAdminUpdated(_firewallAdmin);
    }

    /**
     * @dev Returns the current firewall address.
     */
    function _getFirewall() private view returns (address) {
        return StorageSlot.getAddressSlot(FIREWALL_STORAGE_SLOT).value;
    }

    /**
     * @dev Stores a new address in the firewall implementation slot.
     */
    function _changeFirewall(address _firewall) private {
        StorageSlot.getAddressSlot(FIREWALL_STORAGE_SLOT).value = _firewall;
        emit FirewallUpdated(_firewall);
    }

    /**
     * @dev We can't call `TransparentUpgradeableProxy._delegate` because it uses an inline `RETURN`
     *      Since we have checks after the implementation call we need to save the return data,
     *      perform the checks, and only then return the data
     *
     * @param _toimplementation The address of the implementation to delegate the call to
     */
    function _internalDelegate(address _toimplementation) private firewallProtected returns (bytes memory) {
        bytes memory ret_data = Address.functionDelegateCall(_toimplementation, msg.data);
        return ret_data;
    }

    /**
     * @dev We can't call `TransparentUpgradeableProxy._delegate` because it uses an inline `RETURN`
     *      Since we have checks after the implementation call we need to save the return data,
     *      perform the checks, and only then return the data
     */
    function _delegate(address _toimplementation) internal override {
        bytes memory ret_data = _internalDelegate(_toimplementation);
        uint256 ret_size = ret_data.length;

        // slither-disable-next-line assembly
        assembly {
            return(add(ret_data, 0x20), ret_size)
        }
    }

    /**
     * @dev To keep this contract fully transparent, all `ifAdmin` functions must be payable. This helper is here to
     * emulate some proxy functions being non-payable while still allowing value to pass through.
     */
    function _requireZeroMsgValue() private {
        require(msg.value == 0);
    }
}