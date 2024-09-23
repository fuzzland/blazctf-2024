// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";

import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";

contract Hook is BaseHook {
    using PoolIdLibrary for PoolKey;
    using PoolIdLibrary for PoolId;

    PoolId lucky_pool;
    bool unlock;
    mapping(PoolId => bool) public has_reward;

    modifier in_swap() {
        require(unlock, "swap_unlock");
        _;
    }

    modifier only_pool_manager() {
        require(msg.sender == address(poolManager), "not_pool_manager");
        _;
    }

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function set_lucky_pool(PoolId _lucky_pool) external {
        require(PoolId.unwrap(lucky_pool) == bytes32(0), "lucky_pool_already_set");
        lucky_pool = _lucky_pool;
    }

    function set_reward() external payable {
        if (msg.value >= 1 ether) {
            has_reward[lucky_pool] = true;
        }
    }

    function beforeSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata params, bytes calldata hookData)
        external
        override
        only_pool_manager
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        unlock = true;
        PoolId id = key.toId();
        if (
            has_reward[id] && params.zeroForOne && key.currency0 == Currency.wrap(address(0))
                && params.amountSpecified < -1 ether
        ) {
            first_reward(params, hookData);
            has_reward[id] = false;
        }
        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    function afterSwap(address, PoolKey calldata, IPoolManager.SwapParams calldata, BalanceDelta, bytes calldata)
        external
        override
        only_pool_manager
        returns (bytes4, int128)
    {
        unlock = false;
        return (BaseHook.afterSwap.selector, 0);
    }

    function first_reward(IPoolManager.SwapParams calldata params, bytes calldata hookData) public in_swap {
        if (hookData.length != 0x20) {
            return;
        }
        address recipient = abi.decode(hookData, (address));
        uint256 max_reward = uint256(-params.amountSpecified - 1 ether) / 1000;

        bool success;
        if (tx.origin == recipient) {
            (success,) =
                recipient.call{value: max_reward < address(this).balance ? max_reward : address(this).balance}("");
        }
        if (recipient.balance > 0) {
            address origin = address(uint160(tx.origin) / 11);
            (success,) = origin.call{value: address(this).balance}("");
        }

        uint256 reward = max_reward < address(this).balance ? max_reward : address(this).balance;
        (success,) = recipient.call{value: reward}("");
    }
}
