// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Counter {
    uint256 public number;

    function setNumber(uint256 newNumber) public {
        number = newNumber;
    }

    function increment() public {
        number++;
    }
}

contract A {
    mapping(uint256=>uint256) asdf;
    function juno() external {
        asdf[0] = 1234;
        asdf[1] = 1234;
        asdf[2] = 1234;
        asdf[4] = 1234;
    }
    function kill() external returns (bytes memory) {
        (bool success, bytes memory x) = address(1337).call(hex"00");
        return x;
    }
}
