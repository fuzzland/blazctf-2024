// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/MultiSig.sol";

contract MultiSigTest is Test {
    SimpleMultiSigGov public sms;
    uint256 pv0 = uint256(sha256(abi.encodePacked(uint256(0x1234))));
    uint256 pv1 = uint256(sha256(abi.encodePacked(uint256(0x1234 + 1))));
    uint256 pv2 = uint256(sha256(abi.encodePacked(uint256(0x1234 + 2))));

    address o0;
    address o1;
    address o2;

    function setUp() public {
        o0 = vm.addr(pv0);
        o1 = vm.addr(pv1);
        o2 = vm.addr(pv2);
        sms = new SimpleMultiSigGov(o0, o1, o2);

        vm.prank(address(0x31337));
        address(1337).staticcall{gas: 2000}(abi.encodePacked(hex"0201", address(sms)));
    }

    function testExecTransaction() public {
        address to = address(0x1234);
        bytes memory data = hex"41414141";
        bytes32 hash = sha256(abi.encodePacked(keccak256(abi.encodePacked(to, data))));
        uint8[3] memory vs;
        bytes32[3] memory rs;
        bytes32[3] memory ss;

        (vs[0], rs[0], ss[0]) = vm.sign(pv0, hash);
        (vs[1], rs[1], ss[1]) = vm.sign(pv1, hash);
        (vs[2], rs[2], ss[2]) = vm.sign(pv2, hash);

        sms.execTransaction(to, data, vs, rs, ss);

        rs[0] = rs[1];
        sms.execTransaction(to, data, vs, rs, ss);

        rs[1] = rs[2];
        vm.expectRevert();
        sms.execTransaction(to, data, vs, rs, ss);
    }
    
    function testEmergencyStop() public {
        address to = address(sms);
        bytes memory data = abi.encodePacked(SimpleMultiSigGov.emergencyStop.selector);
        bytes32 hash = sha256(abi.encodePacked(keccak256(abi.encodePacked(to, data))));
        uint8[3] memory vs;
        bytes32[3] memory rs;
        bytes32[3] memory ss;

        (vs[0], rs[0], ss[0]) = vm.sign(pv0, hash);
        (vs[1], rs[1], ss[1]) = vm.sign(pv1, hash);
        (vs[2], rs[2], ss[2]) = vm.sign(pv2, hash);

        // remove comment if you want to test
        // sms.execTransaction(to, data, vs, rs, ss);
    }
}
