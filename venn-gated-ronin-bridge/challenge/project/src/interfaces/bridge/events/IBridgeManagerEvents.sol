// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBridgeManagerEvents {
  /**
   * @dev Emitted when new bridge operators are added.
   */
  event BridgeOperatorsAdded(bool[] statuses, uint96[] voteWeights, address[] governors, address[] bridgeOperators);

  /**
   * @dev Emitted when a bridge operator is failed to add.
   */
  event BridgeOperatorAddingFailed(address indexed operator);

  /**
   * @dev Emitted when bridge operators are removed.
   */
  event BridgeOperatorsRemoved(bool[] statuses, address[] bridgeOperators);

  /**
   * @dev Emitted when a bridge operator is failed to remove.
   */
  event BridgeOperatorRemovingFailed(address indexed operator);

  /**
   * @dev Emitted when a bridge operator is updated.
   */
  event BridgeOperatorUpdated(address indexed governor, address indexed fromBridgeOperator, address indexed toBridgeOperator);

  /**
   * @dev Emitted when the minimum number of required governors is updated.
   */
  event MinRequiredGovernorUpdated(uint min);
}
