// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";



interface ICurve {
    function add_liquidity(
        uint256[] calldata amounts,
        uint256 min_mint_amount
    ) external returns (uint256);

    function remove_liquidity_imbalance(
        uint256[] calldata amounts,
        uint256 max_burn_amount
    ) external returns (uint256);

    function price_oracle(uint256 idx) external view returns (uint256);
    function last_price(uint256 idx) external view returns (uint256);

    function exchange(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy
    ) external returns (uint256);
}

interface IPriceOracle {
    function getAssetPrice(uint256 _assetId) external view returns (uint256);
}

contract SimplePriceOracle is IPriceOracle, Ownable {
    uint256 public price;

    constructor(uint256 _price) Ownable(msg.sender) {
        price = _price;
    }

    function setPrice(uint256 _price) external onlyOwner {
        price = _price;
    }

    function getAssetPrice(uint256 _assetId) external view returns (uint256) {
        return price;
    }
}


contract CurvePriceOracle is IPriceOracle {
    address public curvePool;
    uint256 public idx;

    constructor(address _curvePool, uint256 _idx, uint256 anchor) {
        curvePool = _curvePool;

        uint256 absDiff = 0;
        if (ICurve(curvePool).price_oracle(_idx) > anchor) {
            absDiff = ICurve(curvePool).price_oracle(_idx) - anchor;
        } else {
            absDiff = anchor - ICurve(curvePool).price_oracle(_idx);
        }
        require(absDiff <= 1e8, "Price oracle has been manipulated :(");
    }

    function getAssetPrice(uint256 _assetId) external view returns (uint256) {
        return ICurve(curvePool).price_oracle(idx);
    }

    function getSpotPrice() external view returns (uint256) {
        return ICurve(curvePool).last_price(idx);
    }
}

contract TonyLend is ReentrancyGuard, Ownable {
    struct Asset {
        IERC20 token;
        uint256 totalDeposited;
        uint256 totalBorrowed;
        uint256 baseRate;
    }

    struct UserAccount {
        mapping(uint256 => uint256) deposited;
        mapping(uint256 => uint256) borrowed;
        mapping(uint256 => uint256) lastInterestBlock;
    }

    mapping(address => UserAccount) userAccounts;
    mapping(uint256 => Asset) public assets;
    uint256 public assetCount;

    uint256 public constant LIQUIDATION_CLOSE_FACTOR = 100; // 100% of the borrow can be liquidated
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MAX_LOOPS = 10;
    uint256 public constant BAD_DEBT_RATIO = 110;
    uint256 public constant MIN_HEALTH_FACTOR = 1.05e18;

    mapping(uint256 => address) public priceOracles;

    event AssetAdded(uint256 indexed assetId, address indexed token);
    event Deposit(address indexed user, uint256 indexed assetId, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed assetId, uint256 amount);
    event Borrow(address indexed user, uint256 indexed assetId, uint256 amount);
    event Repay(address indexed user, uint256 indexed assetId, uint256 amount);
    event Liquidate(
        address indexed liquidator,
        address indexed borrower,
        uint256 indexed assetId,
        uint256 amount,
        uint256 collateralAssetId,
        uint256 collateralAmount
    );

    constructor() Ownable(msg.sender) {}

    function addAsset(
        address _token,
        uint256 _baseRate
    ) external onlyOwner {
        assets[assetCount] = Asset({
            token: IERC20(_token),
            totalDeposited: 0,
            totalBorrowed: 0,
            baseRate: _baseRate
        });
        emit AssetAdded(assetCount, _token);
        assetCount++;
    }

    function setPriceOracle(uint256 _assetId, address _priceOracle) external onlyOwner {
        priceOracles[_assetId] = _priceOracle;
    }

    function deposit(uint256 _assetId, uint256 _amount) external nonReentrant {
        require(_assetId < assetCount, "Invalid asset");
        require(_amount > 0, "Amount must be greater than 0");

        Asset storage asset = assets[_assetId];
        require(asset.token.transferFrom(msg.sender, address(this), _amount), "Transfer failed");

        updateInterest(msg.sender, _assetId);
        userAccounts[msg.sender].deposited[_assetId] += _amount;
        asset.totalDeposited += _amount;

        emit Deposit(msg.sender, _assetId, _amount);
    }

    function borrow(uint256 _assetId, uint256 _amount) external nonReentrant {
        require(_assetId < assetCount, "Invalid asset");
        require(_amount > 0, "Amount must be greater than 0");

        updateInterest(msg.sender, _assetId);

        UserAccount storage account = userAccounts[msg.sender];
        Asset storage asset = assets[_assetId];

        uint256 newBorrowAmount = account.borrowed[_assetId] + _amount;
        account.borrowed[_assetId] = newBorrowAmount;
        asset.totalBorrowed += _amount;

        uint256 healthFactor = calculateHealthFactor(msg.sender);
        require(healthFactor >= MIN_HEALTH_FACTOR, "Borrow would result in undercollateralization");

        require(asset.token.transfer(msg.sender, _amount), "Transfer failed");

        emit Borrow(msg.sender, _assetId, _amount);
    }

    function liquidate(address _borrower, uint256 _assetId, uint256 _amount, uint256 _collateralAssetId)
        external
        nonReentrant
    {
        require(_assetId < assetCount && _collateralAssetId < assetCount, "Invalid asset");
        require(_amount > 0, "Amount must be greater than 0");
        require(_borrower != msg.sender, "Cannot liquidate own position");
        require(_assetId != _collateralAssetId, "Cannot liquidate same asset");

        updateInterest(_borrower, _assetId);
        updateInterest(_borrower, _collateralAssetId);

        UserAccount storage borrowerAccount = userAccounts[_borrower];
        Asset storage borrowedAsset = assets[_assetId];
        Asset storage collateralAsset = assets[_collateralAssetId];

        uint256 healthFactor = calculateHealthFactor(_borrower);
        require(healthFactor < PRECISION, "Account not liquidatable");

        uint256 maxLiquidatable = borrowerAccount.borrowed[_assetId] * LIQUIDATION_CLOSE_FACTOR / 100;
        uint256 actualLiquidation = Math.min(_amount, maxLiquidatable);

        uint256 realCollateralAmount = actualLiquidation * getAssetPrice(_assetId) / getAssetPrice(_collateralAssetId);
        uint256 collateralAmount = Math.min(realCollateralAmount, borrowerAccount.deposited[_collateralAssetId]);

        uint256 toLiquidate = collateralAmount * getAssetPrice(_collateralAssetId) / getAssetPrice(_assetId);
        if (realCollateralAmount > borrowerAccount.deposited[_collateralAssetId]) {
            toLiquidate = toLiquidate * BAD_DEBT_RATIO / 100;
        }

        require(borrowedAsset.token.transferFrom(msg.sender, address(this), toLiquidate), "Transfer failed");
        require(collateralAsset.token.transfer(msg.sender, collateralAmount), "Transfer failed");

        borrowerAccount.borrowed[_assetId] -= actualLiquidation;
        borrowerAccount.deposited[_collateralAssetId] -= collateralAmount;

        borrowedAsset.totalBorrowed -= actualLiquidation;
        collateralAsset.totalDeposited -= collateralAmount;

        emit Liquidate(msg.sender, _borrower, _assetId, actualLiquidation, _collateralAssetId, collateralAmount);
    }

    function updateInterest(address _user, uint256 _assetId) internal {
        UserAccount storage account = userAccounts[_user];
        Asset storage asset = assets[_assetId];

        if (account.lastInterestBlock[_assetId] == block.number) {
            return;
        }

        uint256 interestRate = getInterestRate(_assetId);
        uint256 blocksSinceLastUpdate = block.number - account.lastInterestBlock[_assetId];
        uint256 interest =
            account.borrowed[_assetId] * interestRate * blocksSinceLastUpdate / (365 days / 15) / PRECISION;
        account.borrowed[_assetId] += interest;
        asset.totalBorrowed += interest;
        account.lastInterestBlock[_assetId] = block.number;
    }

    function getInterestRate(uint256 _assetId) public view returns (uint256) {
        Asset storage asset = assets[_assetId];
        return asset.baseRate;
    }

    function calculateHealthFactor(address _user) public view returns (uint256) {
        uint256 totalCollateralInEth = 0;
        uint256 totalBorrowedInEth = 0;

        for (uint256 i = 0; i < assetCount; i++) {
            Asset storage asset = assets[i];
            UserAccount storage account = userAccounts[_user];

            uint256 collateralInEth = account.deposited[i] * getAssetPrice(i);
            uint256 borrowedInEth = account.borrowed[i] * getAssetPrice(i);

            totalCollateralInEth += collateralInEth;
            totalBorrowedInEth += borrowedInEth;
        }

        if (totalBorrowedInEth == 0) {
            return type(uint256).max;
        }

        return totalCollateralInEth * PRECISION / totalBorrowedInEth;
    }

    function getAssetPrice(uint256 _assetId) public view returns (uint256) {
        if (priceOracles[_assetId] == address(0)) {
            return 0;
        }
        return IPriceOracle(priceOracles[_assetId]).getAssetPrice(_assetId);
    }
}

contract MintableERC20 is ERC20 {
    uint8 public decimalsInternal;

    function decimals() public view override returns (uint8) {
        return decimalsInternal;
    }

    constructor(string memory name, string memory symbol, uint8 _decimals) ERC20(name, symbol) {
        _mint(msg.sender, 1e6 * 10 ** _decimals);
        decimalsInternal = _decimals;
    }
}

interface ICurveFactory {
    function deploy_plain_pool(
        string memory _name,
        string memory _symbol,
        address[] memory _coins,
        uint256 _A,
        uint256 _fee,
        uint256 _offpeg_fee_multiplier,
        uint256 _ma_exp_time,
        uint256 _implementation_idx,
        uint8[] memory _asset_types,
        bytes4[] memory _method_ids,
        address[] memory _oracles
    ) external returns (address);
}
