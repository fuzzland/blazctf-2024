// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { ContractType } from "../../utils/ContractType.sol";

interface IHasContracts {
  /// @dev Error of invalid role.
  error ErrContractTypeNotFound(ContractType contractType);

  /// @dev Emitted when a contract is updated.
  event ContractUpdated(ContractType indexed contractType, address indexed addr);

  /**
   * @dev Returns the address of a contract with a specific role.
   * Throws an error if no contract is set for the specified role.
   *
   * @param contractType The role of the contract to retrieve.
   * @return contract_ The address of the contract with the specified role.
   */
  function getContract(ContractType contractType) external view returns (address contract_);

  /**
   * @dev Sets the address of a contract with a specific role.
   * Emits the event {ContractUpdated}.
   * @param contractType The role of the contract to set.
   * @param addr The address of the contract to set.
   */
  function setContract(ContractType contractType, address addr) external;
}
