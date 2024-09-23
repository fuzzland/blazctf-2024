// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "./ERC20.sol";

contract PendleIntern is ERC20 {
    constructor() {
        _mint(msg.sender, 1337 ether);
    }

    function name() public pure override returns (string memory) {
        return "Pendle Intern";
    }

    function symbol() public pure override returns (string memory) {
        return "AMAZING";
    }
}

contract Challenge {
    address public immutable PLAYER;
    PendleIntern public immutable token;

    constructor(address player) {
        PLAYER = player;
        token = new PendleIntern();
        token.transfer(0x00000000005BBB0EF59571E58418F9a4357b68A0, 1337 ether);
    }

    function isSolved() external view returns (bool) {
        return token.balanceOf(PLAYER) >= 337 ether;
    }
}
