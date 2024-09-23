// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SafeUint112 {
    /// @dev safeCast is a function that converts a uint256 to a uint112, and reverts on overflow
    function safeCast(uint256 value) internal pure returns (uint112) {
        require(value <= (1 << 112), "SafeUint112: value exceeds uint112 max");
        return uint112(value);
    }

    /// @dev safeMul is a function that multiplies two uint112 values, and reverts on overflow
    function safeMul(uint112 a, uint256 b) internal pure returns (uint112) {
        require(uint256(a) * b <= (1 << 112), "SafeUint112: value exceeds uint112 max");
        return uint112(a * b);
    }
}