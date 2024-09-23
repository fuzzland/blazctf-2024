// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "./ERC20.sol";

contract WBTC is ERC20 {
    constructor() {
        _mint(msg.sender, 1337 ether);
    }

    function name() public pure override returns (string memory) {
        return "Wrapped Bitcoin";
    }

    function symbol() public pure override returns (string memory) {
        return "WBTC";
    }
}

contract Challenge {
    address public immutable PLAYER;
    WBTC public immutable token;

    constructor(address player) {
        PLAYER = player;
        token = new WBTC();
        token.transfer(0xCf9997FF3178eE54270735fDc00d4A26730787E0, 1337 ether);
    }

    function isSolved() external view returns (bool) {
        return token.balanceOf(PLAYER) >= 337 ether;
    }
}
