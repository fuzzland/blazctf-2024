// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";

import {ERC20} from "../src/ERC20.sol";
import {Hook} from "../src/Hook.sol";
import {HookMiner} from "../src/HookMiner.sol";

contract Challenge {
    using CurrencyLibrary for Currency;

    address immutable token;
    address immutable player;
    Hook immutable hook;
    PoolManager immutable manager;

    constructor(address _player, PoolManager _manager) payable {
        player = _player;
        token = address(new ERC20("Token", "T2"));
        manager = _manager;

        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG);
        (address hookAddress, bytes32 salt) =
            HookMiner.find(address(this), flags, type(Hook).creationCode, abi.encode(address(manager)));
        hook = new Hook{salt: salt}(manager);
        assert(hookAddress == address(hook));

        uint160 startingPrice = 79228162514264337593543950336;
        PoolKey memory pool = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(token),
            fee: 0,
            tickSpacing: 10,
            hooks: hook
        });
        PoolId lucky_pool = PoolIdLibrary.toId(pool);
        hook.set_lucky_pool(lucky_pool);
        manager.initialize(pool, startingPrice, new bytes(0));
    }

    uint256 start_block;

    function arbitrary(address a, bytes calldata data) external payable {
        if (start_block != 0) {
            require(msg.value >= (block.number - start_block) * 9e17, "insufficient fee");
        }
        start_block = block.number;
        if (a == address(this) || a == address(hook)) {
            (bool success,) = a.call{value: address(this).balance}(data);
            require(success, "call failed");
        } else if (a == msg.sender || a == address(manager)) {
            (bool success,) = a.call{value: msg.value}(data);
            require(success, "call failed");
        } else {
            start_block--;
            (bool success,) = a.call(data);
            require(success, "call failed");
        }
    }

    receive() external payable {}

    function isSolved() external view returns (bool) {
        return player.balance >= 19e17;
    }
}
