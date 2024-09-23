// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-ctf/CTFDeployer.sol";

import "src/Challenge.sol";
import {MainchainGatewayV3} from "../src/mainchain/MainchainGatewayV3.sol";
import {Firewall} from "../src/onchain-firewall/contracts/Firewall.sol";
import {IFirewallPolicy} from "../src/onchain-firewall/contracts/interfaces/IFirewallPolicy.sol";
import {DummyPolicy} from "../src/DummyPolicy.sol";

contract Deploy is CTFDeployer {
    MainchainGatewayV3 constant BRIDGE = MainchainGatewayV3(payable(0x64192819Ac13Ef72bF6b5AE239AC672B43a9AF08));

    function deploy(address system, address player) internal override returns (address challenge) {
        uint256 policyDeployerKey = 0x3cf73404c02a3c268d175863b912e5af9dcce718728cba9e30ec649188e7c19d;

        vm.startBroadcast(system);
        MainchainGatewayV3 impl = new MainchainGatewayV3();
        Firewall firewall = new Firewall();
        (bool s,) = vm.addr(policyDeployerKey).call{value: 1 ether}("");
        require(s, "Failed to send ETH");
        vm.stopBroadcast();

        vm.startBroadcast(policyDeployerKey);
        DummyPolicy policy = new DummyPolicy();
        vm.stopBroadcast();

        vm.startBroadcast(player);
        (bool upgradeSuccess,) = address(BRIDGE).call(abi.encodeWithSignature("upgradeTo(address)", address(impl)));
        require(upgradeSuccess, "Upgrade failed");
        vm.stopBroadcast();

        vm.startBroadcast(system);
        BRIDGE.initializeFirewall(address(firewall));
        firewall.setPolicyStatus(address(policy), true);
        firewall.addGlobalPolicy(address(BRIDGE), address(policy));

        challenge = address(new Challenge());
        vm.stopBroadcast();
    }
}
