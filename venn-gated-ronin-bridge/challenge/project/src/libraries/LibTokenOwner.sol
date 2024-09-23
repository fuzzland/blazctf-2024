// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct TokenOwner {
  address addr;
  address tokenAddr;
  uint256 chainId;
}

library LibTokenOwner {
  // keccak256("TokenOwner(address addr,address tokenAddr,uint256 chainId)");
  bytes32 public constant OWNER_TYPE_HASH = 0x353bdd8d69b9e3185b3972e08b03845c0c14a21a390215302776a7a34b0e8764;

  /**
   * @dev Returns ownership struct hash.
   */
  function hash(TokenOwner memory owner) internal pure returns (bytes32 digest) {
    // keccak256(abi.encode(OWNER_TYPE_HASH, owner.addr, owner.tokenAddr, owner.chainId))
    assembly ("memory-safe") {
      let ptr := mload(0x40)
      mstore(ptr, OWNER_TYPE_HASH)
      mstore(add(ptr, 0x20), mload(owner)) // owner.addr
      mstore(add(ptr, 0x40), mload(add(owner, 0x20))) // owner.tokenAddr
      mstore(add(ptr, 0x60), mload(add(owner, 0x40))) // owner.chainId
      digest := keccak256(ptr, 0x80)
    }
  }
}
