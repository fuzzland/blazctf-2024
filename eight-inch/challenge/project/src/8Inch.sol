// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20.sol";
import "./SafeUint112.sol";
import "forge-std/console.sol";

contract TradeSettlement is SafeUint112 {
    struct Trade {
        address maker;
        address taker;
        address tokenToSell;
        address tokenToBuy;
        uint112 amountToSell;
        uint112 amountToBuy;
        uint112 filledAmountToSell;
        uint112 filledAmountToBuy;
        bool isActive;
    }

    mapping(uint256 => Trade) public trades;
    uint256 public nextTradeId;
    bool private locked;
    uint256 public fee = 30 wei;

    event TradeCreated(uint256 indexed tradeId, address indexed maker, address tokenToSell, address tokenToBuy, uint256 amountToSell, uint256 amountToBuy);
    event TradeSettled(uint256 indexed tradeId, address indexed settler, uint256 settledAmountToSell);
    event TradeCancelled(uint256 indexed tradeId);

    modifier nonReentrant() {
        require(!locked, "ReentrancyGuard: reentrant call");
        locked = true;
        _;
        locked = false;
    }

    function createTrade(
        address _tokenToSell,
        address _tokenToBuy,
        uint256 _amountToSell,
        uint256 _amountToBuy
    ) external nonReentrant {
        require(_tokenToSell != address(0) && _tokenToBuy != address(0), "Invalid token addresses");

        uint256 tradeId = nextTradeId++;
        trades[tradeId] = Trade({
            maker: msg.sender,
            taker: address(0),
            tokenToSell: _tokenToSell,
            tokenToBuy: _tokenToBuy,
            amountToSell: safeCast(_amountToSell - fee),
            amountToBuy: safeCast(_amountToBuy),
            filledAmountToSell: 0,
            filledAmountToBuy: 0,
            isActive: true
        });

        require(IERC20(_tokenToSell).transferFrom(msg.sender, address(this), _amountToSell), "Transfer failed");

        emit TradeCreated(tradeId, msg.sender, _tokenToSell, _tokenToBuy, _amountToSell, _amountToBuy);
    }

    function scaleTrade(uint256 _tradeId, uint256 scale) external nonReentrant {
        require(msg.sender == trades[_tradeId].maker, "Only maker can scale");
        Trade storage trade = trades[_tradeId];
        require(trade.isActive, "Trade is not active");
        require(scale > 0, "Invalid scale");
        require(trade.filledAmountToBuy == 0, "Trade is already filled");
        uint112 originalAmountToSell = trade.amountToSell;
        trade.amountToSell = safeCast(safeMul(trade.amountToSell, scale));
        trade.amountToBuy = safeCast(safeMul(trade.amountToBuy, scale));
        uint256 newAmountNeededWithFee = safeCast(safeMul(originalAmountToSell, scale) + fee);
        if (originalAmountToSell < newAmountNeededWithFee) {
            require(
                IERC20(trade.tokenToSell).transferFrom(msg.sender, address(this), newAmountNeededWithFee - originalAmountToSell),
                "Transfer failed"
            );
        }
    }

    function settleTrade(uint256 _tradeId, uint256 _amountToSettle) external nonReentrant {
        Trade storage trade = trades[_tradeId];
        require(trade.isActive, "Trade is not active");
        require(_amountToSettle > 0, "Invalid settlement amount");
        uint256 tradeAmount = _amountToSettle * trade.amountToBuy;

        require(trade.filledAmountToSell + _amountToSettle <= trade.amountToSell, "Exceeds available amount");

        require(IERC20(trade.tokenToBuy).transferFrom(msg.sender, trade.maker, tradeAmount / trade.amountToSell), "Buy transfer failed");
        require(IERC20(trade.tokenToSell).transfer(msg.sender, _amountToSettle), "Sell transfer failed");

        trade.filledAmountToSell += safeCast(_amountToSettle);
        trade.filledAmountToBuy += safeCast(tradeAmount / trade.amountToSell);

        if (trade.filledAmountToSell > trade.amountToSell) {
            trade.isActive = false;
        }

        emit TradeSettled(_tradeId, msg.sender, _amountToSettle);
    }

    function cancelTrade(uint256 _tradeId) external nonReentrant {
        Trade storage trade = trades[_tradeId];
        require(msg.sender == trade.maker, "Only maker can cancel");
        require(trade.isActive, "Trade is not active");

        uint256 remainingAmount = trade.amountToSell - trade.filledAmountToSell;
        if (remainingAmount > 0) {
            require(IERC20(trade.tokenToSell).transfer(trade.maker, remainingAmount), "Transfer failed");
        }

        trade.isActive = false;

        emit TradeCancelled(_tradeId);
    }

    function getTrade(uint256 _tradeId) external view returns (
        address maker,
        address taker,
        address tokenToSell,
        address tokenToBuy,
        uint256 amountToSell,
        uint256 amountToBuy,
        uint256 filledAmountToSell,
        uint256 filledAmountToBuy,
        bool isActive
    ) {
        Trade storage trade = trades[_tradeId];
        return (
            trade.maker,
            trade.taker,
            trade.tokenToSell,
            trade.tokenToBuy,
            trade.amountToSell,
            trade.amountToBuy,
            trade.filledAmountToSell,
            trade.filledAmountToBuy,
            trade.isActive
        );
    }
}


contract Challenge {
    TradeSettlement public tradeSettlement;
    SimpleERC20 public wojak;
    SimpleERC20 public weth;

    constructor() {
        tradeSettlement = new TradeSettlement();

        weth = new SimpleERC20("Wrapped Ether", "WETH", 18, 10 ether);
        wojak = new SimpleERC20("Wojak", "WOJAK", 18, 10 ether);

        wojak.approve(address(tradeSettlement), 10 ether);

        // Sell 10 WOJAK for 1 weth
        tradeSettlement.createTrade(address(wojak), address(weth), 10 ether, 1 ether);
    }

    function isSolved() public view returns (bool) {
        return wojak.balanceOf(address(0xc0ffee)) >= 10 ether;
    }
}
