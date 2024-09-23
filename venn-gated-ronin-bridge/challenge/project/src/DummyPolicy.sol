pragma solidity ^0.8.19;

contract DummyPolicy {
    function preExecution(address consumer, address sender, bytes calldata, uint256) external view {

    }

    function postExecution(address, address, bytes calldata, uint256) external {}
}
