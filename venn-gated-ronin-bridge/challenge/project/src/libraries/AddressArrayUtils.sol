// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

library AddressArrayUtils {
  /**
   * @dev Error thrown when a duplicated element is detected in an array.
   * @param msgSig The function signature that invoke the error.
   */
  error ErrDuplicated(bytes4 msgSig);

  /**
   * @dev Returns whether or not there's a duplicate. Runs in O(n^2).
   * @param A Array to search
   * @return Returns true if duplicate, false otherwise
   */
  function hasDuplicate(address[] memory A) internal pure returns (bool) {
    if (A.length == 0) {
      return false;
    }
    unchecked {
      for (uint256 i = 0; i < A.length - 1; i++) {
        for (uint256 j = i + 1; j < A.length; j++) {
          if (A[i] == A[j]) {
            return true;
          }
        }
      }
    }
    return false;
  }

  /**
   * @dev Returns whether two arrays of addresses are equal or not.
   */
  function isEqual(address[] memory _this, address[] memory _other) internal pure returns (bool yes_) {
    // Hashing two arrays and compare their hash
    assembly {
      let _thisHash := keccak256(add(_this, 32), mul(mload(_this), 32))
      let _otherHash := keccak256(add(_other, 32), mul(mload(_other), 32))
      yes_ := eq(_thisHash, _otherHash)
    }
  }

  /**
   * @dev Return the concatenated array from a and b.
   */
  function extend(address[] memory a, address[] memory b) internal pure returns (address[] memory c) {
    uint256 lengthA = a.length;
    uint256 lengthB = b.length;
    unchecked {
      c = new address[](lengthA + lengthB);
    }
    uint256 i;
    for (; i < lengthA;) {
      c[i] = a[i];
      unchecked {
        ++i;
      }
    }
    for (uint256 j; j < lengthB;) {
      c[i] = b[j];
      unchecked {
        ++i;
        ++j;
      }
    }
  }
}
