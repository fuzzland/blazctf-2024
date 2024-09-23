// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./TonyLend.sol";


// Fork Mainnet at block 18580700 after (https://etherscan.io/tx/0x6f4438aa1785589e2170599053a0cdc740d8987746a4b5ad9614b6ab7bb4e550)
contract Challenge {
    ERC20 public usde;
    ERC20 public usdc;

    IPriceOracle public usdePriceOracle;
    IPriceOracle public usdcPriceOracle;

    TonyLend public tonyLend;

    uint256 public startingBlock = 0;
    ICurve public curvePool;
    ICurveFactory public curveDeployer = ICurveFactory(0x6A8cbed756804B16E05E741eDaBd5cB544AE21bf);
    bool public claimed = false;

    constructor() {
        tonyLend = new TonyLend();

        usde = new MintableERC20("Wrapped USDe", "wUSDe", 18);
        usdc = new MintableERC20("Wrapped USDC", "wUSDC", 6);


        address[] memory coins = new address[](2);
        coins[0] = address(usde);
        coins[1] = address(usdc);

        uint8[]  memory asset_types = new uint8[](2);
        asset_types[0] = 0;
        asset_types[1] = 0;

        bytes4[] memory method_ids = new bytes4[](2);
        method_ids[0] = bytes4(0x00000000);
        method_ids[1] = bytes4(0x00000000);

        address[]memory oracles = new address[](2);
        oracles[0] = address(address(0));
        oracles[1] = address(address(0));

        // same params as in https://etherscan.io/tx/0x6f4438aa1785589e2170599053a0cdc740d8987746a4b5ad9614b6ab7bb4e550
        curvePool = ICurve(curveDeployer.deploy_plain_pool(
            "USDe/USDC Curve Pool",
            "USDeUSDC",
            coins,
            200,
            1000000,
            50000000000,
            866,
            0,
            asset_types,
            method_ids,
            oracles
        ));
        usde.approve(address(curvePool), type(uint256).max);
        usdc.approve(address(curvePool), type(uint256).max);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1e18 * 9e5;
        amounts[1] = 1e6 * 9e5;
        curvePool.add_liquidity(amounts, 1);

        usde.approve(address(tonyLend), type(uint256).max);
        usdc.approve(address(tonyLend), type(uint256).max);
        // create initial liquidity
        usde.transfer(address(tonyLend),  8e4 ether);
        usdc.transfer(address(tonyLend), 8e4 * 1e6);

        usdcPriceOracle = new CurvePriceOracle(
            address(curvePool), 0, 1e18
        );
        usdePriceOracle = new SimplePriceOracle(1e6);

        // add assets
        tonyLend.addAsset(address(usde), 1);
        tonyLend.addAsset(address(usdc), 1);

        // set price oracles
        tonyLend.setPriceOracle(0, address(usdePriceOracle));
        tonyLend.setPriceOracle(1, address(usdcPriceOracle));

        // deposit
        tonyLend.deposit(0, 1e4 ether);
        tonyLend.deposit(1, 1e4 * 1e6);

        // borrow
        tonyLend.borrow(1, 1.85e4 * 1e6);
    }

    function claimDust() external {
        require(!claimed, "Already claimed");
        claimed = true;
        usde.transfer(msg.sender, 1e4 ether);
        usdc.transfer(msg.sender, 1e4 * 1e6);
    }

    function isSolved() external view returns (bool) {
        return usde.balanceOf(address(0xc0ffee)) >= 21926 ether;
    }
}
