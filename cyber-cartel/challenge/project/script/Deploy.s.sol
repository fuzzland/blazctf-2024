// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-ctf/CTFDeployer.sol";

import "../src/Challenge.sol";
import "../src/CyberCartel.sol";

contract Deploy is CTFDeployer {
    function deploy(address system, address player) internal override returns (address challenge) {
        uint256 privateKey = uint256(keccak256("CyberCartel"));
        address deployer = vm.addr(privateKey);

        CartelTreasury cartel;

        {
            vm.startBroadcast(system);
            t(deployer, 888 ether);
            vm.stopBroadcast();
        }

        {
            vm.startBroadcast(privateKey);

            address guardian1 = 0xA66bA931da982b11a2f3b89d1D732537EA4bc30D;
            address guardian2 = 0xa66ba931dA982b11A2F3B89d1d732537ea4bC30E;
            address guardian3 = player;

            t(guardian1, 10 ether);
            t(guardian2, 10 ether);
            t(guardian3, 10 ether);

            cartel = new CartelTreasury();
            address[] memory guardians = new address[](3);
            guardians[0] = 0xA66bA931da982b11a2f3b89d1D732537EA4bc30D;
            guardians[1] = 0xa66ba931dA982b11A2F3B89d1d732537ea4bC30E;
            guardians[2] = player;
            address bodyguard = address(new BodyGuard(address(cartel), guardians));

            cartel.initialize(bodyguard);
            t(address(cartel), 777 ether);

            vm.stopBroadcast();
        }

        vm.startBroadcast(system);
        challenge = address(new Challenge(address(cartel)));
        vm.stopBroadcast();
    }

    function t(address r, uint256 v) internal {
        (bool success,) = r.call{value: v}("");
        require(success, "Failed to send ETH");
    }
}
