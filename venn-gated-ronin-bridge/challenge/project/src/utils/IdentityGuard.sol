// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AddressArrayUtils } from "../libraries/AddressArrayUtils.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { TransparentUpgradeableProxyV2 } from "../extensions/TransparentUpgradeableProxyV2.sol";
import { ErrAddressIsNotCreatedEOA, ErrZeroAddress, ErrOnlySelfCall, ErrZeroCodeContract, ErrUnsupportedInterface } from "./CommonErrors.sol";

abstract contract IdentityGuard {
  using AddressArrayUtils for address[];

  /// @dev value is equal to keccak256(abi.encode())
  /// @dev see: https://eips.ethereum.org/EIPS/eip-1052
  bytes32 internal constant CREATED_ACCOUNT_HASH = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;

  /**
   * @dev Modifier to restrict functions to only be called by this contract.
   * @dev Reverts if the caller is not this contract.
   */
  modifier onlySelfCall() virtual {
    _requireSelfCall();
    _;
  }

  /**
   * @dev Modifier to ensure that the elements in the `arr` array are non-duplicates.
   * It calls the internal `_checkDuplicate` function to perform the duplicate check.
   *
   * Requirements:
   * - The elements in the `arr` array must not contain any duplicates.
   */
  modifier nonDuplicate(address[] memory arr) virtual {
    _requireNonDuplicate(arr);
    _;
  }

  /**
   * @dev Internal method to check the method caller.
   * @dev Reverts if the method caller is not this contract.
   */
  function _requireSelfCall() internal view virtual {
    if (msg.sender != address(this)) revert ErrOnlySelfCall(msg.sig);
  }

  /**
   * @dev Internal function to check if a contract address has code.
   * @param addr The address of the contract to check.
   * @dev Throws an error if the contract address has no code.
   */
  function _requireHasCode(address addr) internal view {
    if (addr.code.length == 0) revert ErrZeroCodeContract(addr);
  }

  /**
   * @dev Checks if an address is zero and reverts if it is.
   * @param addr The address to check.
   */
  function _requireNonZeroAddress(address addr) internal pure {
    if (addr == address(0)) revert ErrZeroAddress(msg.sig);
  }

  /**
   * @dev Check if arr is empty and revert if it is.
   * Checks if an array contains any duplicate addresses and reverts if duplicates are found.
   * @param arr The array of addresses to check.
   */
  function _requireNonDuplicate(address[] memory arr) internal pure {
    if (arr.hasDuplicate()) revert AddressArrayUtils.ErrDuplicated(msg.sig);
  }

  /**
   * @dev Internal function to require that the provided address is a created externally owned account (EOA).
   * This internal function is used to ensure that the provided address is a valid externally owned account (EOA).
   * It checks the codehash of the address against a predefined constant to confirm that the address is a created EOA.
   * @notice This method only works with non-state EOA accounts
   */
  function _requireCreatedEOA(address addr) internal view {
    _requireNonZeroAddress(addr);
    bytes32 codehash = addr.codehash;
    if (codehash != CREATED_ACCOUNT_HASH) revert ErrAddressIsNotCreatedEOA(addr, codehash);
  }

  /**
   * @dev Internal function to require that the specified contract supports the given interface. This method handle in
   * both case that the callee is either or not the proxy admin of the caller. If the contract does not support the
   * interface `interfaceId` or EIP165, a revert with the corresponding error message is triggered.
   *
   * @param contractAddr The address of the contract to check for interface support.
   * @param interfaceId The interface ID to check for support.
   */
  function _requireSupportsInterface(address contractAddr, bytes4 interfaceId) internal view {
    bytes memory supportsInterfaceParams = abi.encodeCall(IERC165.supportsInterface, (interfaceId));
    (bool success, bytes memory returnOrRevertData) = contractAddr.staticcall(supportsInterfaceParams);
    if (!success) {
      (success, returnOrRevertData) = contractAddr.staticcall(abi.encodeCall(TransparentUpgradeableProxyV2.functionDelegateCall, (supportsInterfaceParams)));
      if (!success) revert ErrUnsupportedInterface(interfaceId, contractAddr);
    }
    if (!abi.decode(returnOrRevertData, (bool))) revert ErrUnsupportedInterface(interfaceId, contractAddr);
  }
}
