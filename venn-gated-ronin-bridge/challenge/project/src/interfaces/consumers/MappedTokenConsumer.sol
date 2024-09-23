// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../libraries/LibTokenInfo.sol";

interface MappedTokenConsumer {
  struct MappedToken {
    TokenStandard erc;
    address tokenAddr;
  }
}
