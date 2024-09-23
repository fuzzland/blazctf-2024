// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Doju {
    string public name = "Bonding Doju Curve Token";
    string public symbol = "BD";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    address public constant BURN_ADDRESS = address(0);

    mapping(address => uint256) public balanceOf;

    // Events for transfer, mint, and burn
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Mint(address indexed to, uint256 value);
    event Burn(address indexed from, uint256 value);

    // Fallback function to handle ETH sent to the contract

    constructor() {
        // total supply of 100 tokens
        totalSupply = 100 ether;
        balanceOf[msg.sender] = 100 ether;

        // pre-mint max tokens to contract
        balanceOf[address(this)] = type(uint256).max - totalSupply;
    }

    receive() external payable {
        buyTokens(msg.sender);
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0), "Invalid to");
        require(balanceOf[from] >= value, "Not enough balance");
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
    }

    // Buy tokens by sending ETH
    function buyTokens(address to) public payable {
        require(msg.value > 0, "Send ETH to buy tokens");
        uint256 tokensToMint = _ethToTokens(msg.value, totalSupply);
        _transfer(address(this), to, tokensToMint);
        totalSupply += tokensToMint;

        emit Mint(to, tokensToMint);
        emit Transfer(address(0), to, tokensToMint);
    }

    // Sell tokens and receive ETH
    function sellTokens(uint256 tokenAmount, address to, uint256 minOut) public {
        uint256 ethValue = _tokensToEth(tokenAmount);
        _transfer(msg.sender, address(this), tokenAmount);
        totalSupply -= tokenAmount;
        (bool success,) =
            payable(to).call{value: ethValue}(abi.encodePacked(minOut, to, tokenAmount, msg.sender, ethValue));
        require(minOut > ethValue, "minOut not met");
        require(success, "Transfer failed");
        emit Burn(msg.sender, tokenAmount);
        emit Transfer(msg.sender, address(0), tokenAmount);
    }

    // Bonding curve formula to calculate how many tokens to mint for given ETH
    function _ethToTokens(uint256 ethAmount, uint256 currentSupply) internal pure returns (uint256) {
        uint256 k = currentSupply * currentSupply;
        uint256 newSupply = sqrt(k + 2 * ethAmount * 1e18);
        return newSupply - currentSupply;
    }

    // Bonding curve formula to calculate how much ETH to return for given tokens
    function _tokensToEth(uint256 tokenAmount) internal view returns (uint256) {
        uint256 currentSupply = totalSupply;
        uint256 k = currentSupply * currentSupply;
        uint256 newSupply = currentSupply - tokenAmount;
        uint256 newK = newSupply * newSupply;
        return (k - newK) / (2 * 1e18);
    }

    // Basic ERC20 transfer function
    function transfer(address to, uint256 value) public returns (bool success) {
        if (to == BURN_ADDRESS) {
            sellTokens(value, msg.sender, 0);
            return true;
        }
        _transfer(msg.sender, to, value);
        return true;
    }

    // Square root helper function (for bonding curve math)
    function sqrt(uint256 x) internal pure returns (uint256) {
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return z;
    }
}
