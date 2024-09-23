// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract Challenge {
    address public immutable PLAYER;

    function isSolved() external view returns (bool) {
        bytes memory expectedCode = hex"dead";
        bytes memory code = address(0xdead).code;
        return keccak256(code) == keccak256(expectedCode);
    }
}
