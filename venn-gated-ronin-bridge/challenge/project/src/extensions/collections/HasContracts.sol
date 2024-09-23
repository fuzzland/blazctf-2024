// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { HasProxyAdmin } from "./HasProxyAdmin.sol";
import "../../interfaces/collections/IHasContracts.sol";
import { IdentityGuard } from "../../utils/IdentityGuard.sol";
import { ErrUnexpectedInternalCall } from "../../utils/CommonErrors.sol";

/**
 * @title HasContracts
 * @dev A contract that provides functionality to manage multiple contracts with different roles.
 */
abstract contract HasContracts is HasProxyAdmin, IHasContracts, IdentityGuard {
  /// @dev value is equal to keccak256("@ronin.dpos.collections.HasContracts.slot") - 1
  bytes32 private constant _STORAGE_SLOT = 0xdea3103d22025c269050bea94c0c84688877f12fa22b7e6d2d5d78a9a49aa1cb;

  /**
   * @dev Modifier to restrict access to functions only to contracts with a specific role.
   * @param contractType The contract type that allowed to call
   */
  modifier onlyContract(ContractType contractType) virtual {
    _requireContract(contractType);
    _;
  }

  /**
   * @inheritdoc IHasContracts
   */
  function setContract(ContractType contractType, address addr) external virtual onlyProxyAdmin {
    _requireHasCode(addr);
    _setContract(contractType, addr);
  }

  /**
   * @inheritdoc IHasContracts
   */
  function getContract(ContractType contractType) public view returns (address contract_) {
    contract_ = _getContractMap()[uint8(contractType)];
    if (contract_ == address(0)) revert ErrContractTypeNotFound(contractType);
  }

  /**
   * @dev Internal function to set the address of a contract with a specific role.
   * @param contractType The contract type of the contract to set.
   * @param addr The address of the contract to set.
   */
  function _setContract(ContractType contractType, address addr) internal virtual {
    _getContractMap()[uint8(contractType)] = addr;
    emit ContractUpdated(contractType, addr);
  }

  /**
   * @dev Internal function to access the mapping of contract addresses with roles.
   * @return contracts_ The mapping of contract addresses with roles.
   */
  function _getContractMap() private pure returns (mapping(uint8 => address) storage contracts_) {
    assembly {
      contracts_.slot := _STORAGE_SLOT
    }
  }

  /**
   * @dev Internal function to check if the calling contract has a specific role.
   * @param contractType The contract type that the calling contract must have.
   * @dev Throws an error if the calling contract does not have the specified role.
   */
  function _requireContract(ContractType contractType) private view {
    if (msg.sender != getContract(contractType)) {
      revert ErrUnexpectedInternalCall(msg.sig, contractType, msg.sender);
    }
  }
}
