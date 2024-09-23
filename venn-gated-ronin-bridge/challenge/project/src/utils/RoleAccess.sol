// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

enum RoleAccess {
  UNKNOWN, // 0
  ADMIN, // 1
  COINBASE, // 2
  GOVERNOR, // 3
  CANDIDATE_ADMIN, // 4
  WITHDRAWAL_MIGRATOR, // 5
  __DEPRECATED_BRIDGE_OPERATOR, // 6
  BLOCK_PRODUCER, // 7
  VALIDATOR_CANDIDATE, // 8
  CONSENSUS, // 9
  TREASURY // 10

}
