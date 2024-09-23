// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-ctf/CTFDeployer.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {Challenge} from "../src/challenge.sol";

contract Deploy is CTFDeployer {
    function deploy(address _system, address player) internal override returns (address challenge) {
        uint256 pk = uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);
        vm.startBroadcast(pk);
        address system = vm.addr(pk);

        payable(player).transfer(1 ether);
        PoolManager manager = new PoolManager();
        challenge = address(new Challenge{value: 1 ether}(player, manager));

        vm.stopBroadcast();
    }
}
