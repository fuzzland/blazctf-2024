// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Doju.sol";

contract Challenge {
    Doju public doju;

    constructor() {
        doju = new Doju();
    }

    function claimTokens() public {
        doju.transfer(msg.sender, doju.balanceOf(address(this)));
    }

    function isSolved() public view returns (bool) {
        return doju.balanceOf(address(0xc0ffee)) > type(uint256).max / 2;
    }
}
