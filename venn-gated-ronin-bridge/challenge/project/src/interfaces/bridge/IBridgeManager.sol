// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IBridgeManagerEvents } from "./events/IBridgeManagerEvents.sol";

/**
 * @title IBridgeManager
 * @dev The interface for managing bridge operators.
 */
interface IBridgeManager is IBridgeManagerEvents {
  /// @notice Error indicating that cannot find the querying operator
  error ErrOperatorNotFound(address operator);
  /// @notice Error indicating that cannot find the querying governor
  error ErrGovernorNotFound(address governor);
  /// @notice Error indicating that the msg.sender is not match the required governor
  error ErrGovernorNotMatch(address required, address sender);
  /// @notice Error indicating that the governors list will go below minimum number of required governor.
  error ErrBelowMinRequiredGovernors();
  /// @notice Common invalid input error
  error ErrInvalidInput();

  /**
   * @dev The domain separator used for computing hash digests in the contract.
   */
  function DOMAIN_SEPARATOR() external view returns (bytes32);

  /**
   * @dev Returns the total number of bridge operators.
   * @return The total number of bridge operators.
   */
  function totalBridgeOperator() external view returns (uint256);

  /**
   * @dev Checks if the given address is a bridge operator.
   * @param addr The address to check.
   * @return A boolean indicating whether the address is a bridge operator.
   */
  function isBridgeOperator(address addr) external view returns (bool);

  /**
   * @dev Retrieves the full information of all registered bridge operators.
   *
   * This external function allows external callers to obtain the full information of all the registered bridge operators.
   * The returned arrays include the addresses of governors, bridge operators, and their corresponding vote weights.
   *
   * @return governors An array of addresses representing the governors of each bridge operator.
   * @return bridgeOperators An array of addresses representing the registered bridge operators.
   * @return weights An array of uint256 values representing the vote weights of each bridge operator.
   *
   * Note: The length of each array will be the same, and the order of elements corresponds to the same bridge operator.
   *
   * Example Usage:
   * ```
   * (address[] memory governors, address[] memory bridgeOperators, uint256[] memory weights) = getFullBridgeOperatorInfos();
   * for (uint256 i = 0; i < bridgeOperators.length; i++) {
   *     // Access individual information for each bridge operator.
   *     address governor = governors[i];
   *     address bridgeOperator = bridgeOperators[i];
   *     uint256 weight = weights[i];
   *     // ... (Process or use the information as required) ...
   * }
   * ```
   *
   */
  function getFullBridgeOperatorInfos() external view returns (address[] memory governors, address[] memory bridgeOperators, uint96[] memory weights);

  /**
   * @dev Returns total weights of the governor list.
   */
  function sumGovernorsWeight(address[] calldata governors) external view returns (uint256 sum);

  /**
   * @dev Returns total weights.
   */
  function getTotalWeight() external view returns (uint256);

  /**
   * @dev Returns an array of all bridge operators.
   * @return An array containing the addresses of all bridge operators.
   */
  function getBridgeOperators() external view returns (address[] memory);

  /**
   * @dev Returns the corresponding `operator` of a `governor`.
   */
  function getOperatorOf(address governor) external view returns (address operator);

  /**
   * @dev Returns the corresponding `governor` of a `operator`.
   */
  function getGovernorOf(address operator) external view returns (address governor);

  /**
   * @dev External function to retrieve the vote weight of a specific governor.
   * @param governor The address of the governor to get the vote weight for.
   * @return voteWeight The vote weight of the specified governor.
   */
  function getGovernorWeight(address governor) external view returns (uint96);

  /**
   * @dev External function to retrieve the vote weight of a specific bridge operator.
   * @param bridgeOperator The address of the bridge operator to get the vote weight for.
   * @return weight The vote weight of the specified bridge operator.
   */
  function getBridgeOperatorWeight(address bridgeOperator) external view returns (uint96 weight);

  /**
   * @dev Returns the weights of a list of governor addresses.
   */
  function getGovernorWeights(address[] calldata governors) external view returns (uint96[] memory weights);

  /**
   * @dev Returns an array of all governors.
   * @return An array containing the addresses of all governors.
   */
  function getGovernors() external view returns (address[] memory);

  /**
   * @dev Adds multiple bridge operators.
   * @param governors An array of addresses of hot/cold wallets for bridge operator to update their node address.
   * @param bridgeOperators An array of addresses representing the bridge operators to add.
   */
  function addBridgeOperators(uint96[] calldata voteWeights, address[] calldata governors, address[] calldata bridgeOperators) external;

  /**
   * @dev Removes multiple bridge operators.
   * @param bridgeOperators An array of addresses representing the bridge operators to remove.
   */
  function removeBridgeOperators(address[] calldata bridgeOperators) external;

  /**
   * @dev Self-call to update the minimum required governor.
   * @param min The minimum number, this must not less than 3.
   */
  function setMinRequiredGovernor(uint min) external;
}
