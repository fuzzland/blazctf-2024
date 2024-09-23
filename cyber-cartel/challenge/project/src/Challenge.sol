// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract Challenge {
    address public immutable TREASURY;

    constructor(address treasury) {
        TREASURY = treasury;
    }

    function isSolved() external view returns (bool) {
        return address(TREASURY).balance == 0;
    }
}
