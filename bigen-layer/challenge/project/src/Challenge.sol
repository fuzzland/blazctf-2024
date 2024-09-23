// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "./ERC20.sol";

contract iPhone16 is ERC20 {
    constructor() {
        _mint(msg.sender, 1000 * 10 ** 18); // Mint 1000 tokens to the deployer
    }

    function name() public pure override returns (string memory) {
        return "iPhone16";
    }

    function symbol() public pure override returns (string memory) {
        return "AMAZING";
    }
}

contract BigenLayer {
    address public immutable owner;
    iPhone16 public immutable token;

    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public withdrawalRequestTime;
    mapping(address => uint256) public pendingWithdrawals;
    mapping(address => address) public withdrawalRecipient;

    constructor(address _owner, iPhone16 _token) {
        owner = _owner;
        token = _token;
    }

    function stake(address onBehalf, uint256 amount) external {
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        stakedBalance[onBehalf] += amount;
    }

    function _requestWithdrawal(address user, uint256 amount, address recipient) internal {
        require(stakedBalance[user] >= amount, "Insufficient balance");
        stakedBalance[user] -= amount;
        pendingWithdrawals[user] += amount;
        withdrawalRequestTime[user] = block.timestamp;
        withdrawalRecipient[user] = recipient;
    }

    function requestWithdrawal(uint256 amount, address recipient) external {
        _requestWithdrawal(msg.sender, amount, recipient);
    }

    function adminRequestWithdrawal(address user, uint256 amount, address recipient) external {
        require(msg.sender == owner, "Only owner can call this function");
        _requestWithdrawal(user, amount, recipient);
    }

    function finalizeWithdrawal(address user) external {
        uint256 amount = pendingWithdrawals[user];
        require(amount > 0, "No pending withdrawal");
        require(block.timestamp >= withdrawalRequestTime[user] + 12 seconds, "Withdrawal too early");
        address recipient = withdrawalRecipient[user];
        pendingWithdrawals[user] = 0;
        require(token.transfer(recipient, amount), "Transfer failed");
    }
}

contract Challenge {
    address public immutable PLAYER;
    BigenLayer public immutable bigen;
    iPhone16 public immutable token;

    address public constant OWNER = 0x71556C38F44e17EC21F355Bd18416155000BF5a6;
    address public constant TIM_COOK = 0x2011082420110824201108242011082420110824;

    constructor(address player) {
        PLAYER = player;
        token = new iPhone16();
        bigen = new BigenLayer(OWNER, token);

        token.approve(address(bigen), type(uint256).max);
        bigen.stake(TIM_COOK, 16 * 10 ** 18);
    }

    function isSolved() external view returns (bool) {
        return token.balanceOf(PLAYER) >= 16 * 10 ** 18;
    }
}
