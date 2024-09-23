// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import { IBridgeManager } from "../interfaces/bridge/IBridgeManager.sol";
import { IBridgeManagerCallback } from "../interfaces/bridge/IBridgeManagerCallback.sol";
import { HasContracts, ContractType } from "../extensions/collections/HasContracts.sol";
import "../extensions/WethUnwrapper.sol";
import "../extensions/WithdrawalLimitation.sol";
import "../libraries/Transfer.sol";
import "../interfaces/IMainchainGatewayV3.sol";

contract MainchainGatewayV3 is
  WithdrawalLimitation,
  Initializable,
  AccessControlEnumerable,
  ERC1155Holder,
  IMainchainGatewayV3,
  HasContracts,
  IBridgeManagerCallback
{
  using LibTokenInfo for TokenInfo;
  using Transfer for Transfer.Request;
  using Transfer for Transfer.Receipt;

  /// @dev Withdrawal unlocker role hash
  bytes32 public constant WITHDRAWAL_UNLOCKER_ROLE = keccak256("WITHDRAWAL_UNLOCKER_ROLE");

  /// @dev Wrapped native token address
  IWETH public wrappedNativeToken;
  /// @dev Ronin network id
  uint256 public roninChainId;
  /// @dev Total deposit
  uint256 public depositCount;
  /// @dev Domain separator
  bytes32 internal _domainSeparator;
  /// @dev Mapping from mainchain token => token address on Ronin network
  mapping(address => MappedToken) internal _roninToken;
  /// @dev Mapping from withdrawal id => withdrawal hash
  mapping(uint256 => bytes32) public withdrawalHash;
  /// @dev Mapping from withdrawal id => locked
  mapping(uint256 => bool) public withdrawalLocked;

  /// @custom:deprecated Previously `_bridgeOperatorAddedBlock` (mapping(address => uint256))
  uint256 private ______deprecatedBridgeOperatorAddedBlock;
  /// @custom:deprecated Previously `_bridgeOperators` (uint256[])
  uint256 private ______deprecatedBridgeOperators;

  uint96 private _totalOperatorWeight;
  mapping(address operator => uint96 weight) private _operatorWeight;
  WethUnwrapper public wethUnwrapper;

  constructor() {
    _disableInitializers();
  }

  fallback() external payable {
    _fallback();
  }

  receive() external payable {
    _fallback();
  }

  function initializeFirewall(address firewall) external {
    internalSetFirewallAdmin(msg.sender);
    internalSetFirewall(firewall);
  }

  /**
   * @dev Initializes contract storage.
   */
  function initialize(
    address _roleSetter,
    IWETH _wrappedToken,
    uint256 _roninChainId,
    uint256 _numerator,
    uint256 _highTierVWNumerator,
    uint256 _denominator,
    // _addresses[0]: mainchainTokens
    // _addresses[1]: roninTokens
    // _addresses[2]: withdrawalUnlockers
    address[][3] calldata _addresses,
    // _thresholds[0]: highTierThreshold
    // _thresholds[1]: lockedThreshold
    // _thresholds[2]: unlockFeePercentages
    // _thresholds[3]: dailyWithdrawalLimit
    uint256[][4] calldata _thresholds,
    TokenStandard[] calldata _standards
  ) external payable virtual initializer {
    _setupRole(DEFAULT_ADMIN_ROLE, _roleSetter);
    roninChainId = _roninChainId;

    _setWrappedNativeTokenContract(_wrappedToken);
    _updateDomainSeparator();
    _setThreshold(_numerator, _denominator);
    _setHighTierVoteWeightThreshold(_highTierVWNumerator, _denominator);
    _verifyThresholds();

    if (_addresses[0].length > 0) {
      // Map mainchain tokens to ronin tokens
      _mapTokens(_addresses[0], _addresses[1], _standards);
      // Sets thresholds based on the mainchain tokens
      _setHighTierThresholds(_addresses[0], _thresholds[0]);
      _setLockedThresholds(_addresses[0], _thresholds[1]);
      _setUnlockFeePercentages(_addresses[0], _thresholds[2]);
      _setDailyWithdrawalLimits(_addresses[0], _thresholds[3]);
    }

    // Grant role for withdrawal unlocker
    for (uint256 i; i < _addresses[2].length; i++) {
      _grantRole(WITHDRAWAL_UNLOCKER_ROLE, _addresses[2][i]);
    }
  }

  function initializeV2(address bridgeManagerContract) external reinitializer(2) {
    _setContract(ContractType.BRIDGE_MANAGER, bridgeManagerContract);
  }

  function initializeV3() external reinitializer(3) {
    IBridgeManager mainchainBridgeManager = IBridgeManager(getContract(ContractType.BRIDGE_MANAGER));
    (, address[] memory operators, uint96[] memory weights) = mainchainBridgeManager.getFullBridgeOperatorInfos();

    uint96 totalWeight;
    for (uint i; i < operators.length; i++) {
      _operatorWeight[operators[i]] = weights[i];
      totalWeight += weights[i];
    }
    _totalOperatorWeight = totalWeight;
  }

  function initializeV4(address payable wethUnwrapper_) external reinitializer(4) {
    wethUnwrapper = WethUnwrapper(wethUnwrapper_);
  }

  /**
   * @dev Receives ether without doing anything. Use this function to topup native token.
   */
  function receiveEther() external payable firewallProtected { }

  /**
   * @inheritdoc IMainchainGatewayV3
   */
  function DOMAIN_SEPARATOR() external view virtual returns (bytes32) {
    return _domainSeparator;
  }

  /**
   * @inheritdoc IMainchainGatewayV3
   */
  function setWrappedNativeTokenContract(IWETH _wrappedToken) external virtual onlyProxyAdmin firewallProtected {
    _setWrappedNativeTokenContract(_wrappedToken);
  }

  /**
   * @inheritdoc IMainchainGatewayV3
   */
  function requestDepositFor(Transfer.Request calldata _request) external payable virtual whenNotPaused firewallProtected {
    _requestDepositFor(_request, msg.sender);
  }

  /**
   * @inheritdoc IMainchainGatewayV3
   */
  function requestDepositForBatch(Transfer.Request[] calldata _requests) external payable virtual whenNotPaused firewallProtected {
    uint length = _requests.length;
    for (uint256 i; i < length; ++i) {
      _requestDepositFor(_requests[i], msg.sender);
    }
  }

  /**
   * @inheritdoc IMainchainGatewayV3
   */
  function submitWithdrawal(Transfer.Receipt calldata _receipt, Signature[] calldata _signatures) external virtual whenNotPaused firewallProtected returns (bool _locked) {
    return _submitWithdrawal(_receipt, _signatures);
  }

  /**
   * @inheritdoc IMainchainGatewayV3
   */
  function unlockWithdrawal(Transfer.Receipt calldata receipt) external onlyRole(WITHDRAWAL_UNLOCKER_ROLE) firewallProtected {
    bytes32 _receiptHash = receipt.hash();
    if (withdrawalHash[receipt.id] != receipt.hash()) {
      revert ErrInvalidReceipt();
    }
    if (!withdrawalLocked[receipt.id]) {
      revert ErrQueryForApprovedWithdrawal();
    }
    delete withdrawalLocked[receipt.id];
    emit WithdrawalUnlocked(_receiptHash, receipt);

    address token = receipt.mainchain.tokenAddr;
    if (receipt.info.erc == TokenStandard.ERC20) {
      TokenInfo memory feeInfo = receipt.info;
      feeInfo.quantity = _computeFeePercentage(receipt.info.quantity, unlockFeePercentages[token]);
      TokenInfo memory withdrawInfo = receipt.info;
      withdrawInfo.quantity = receipt.info.quantity - feeInfo.quantity;

      feeInfo.handleAssetOut(payable(msg.sender), token, wrappedNativeToken);
      withdrawInfo.handleAssetOut(payable(receipt.mainchain.addr), token, wrappedNativeToken);
    } else {
      receipt.info.handleAssetOut(payable(receipt.mainchain.addr), token, wrappedNativeToken);
    }

    emit Withdrew(_receiptHash, receipt);
  }

  /**
   * @inheritdoc IMainchainGatewayV3
   */
  function mapTokens(address[] calldata _mainchainTokens, address[] calldata _roninTokens, TokenStandard[] calldata _standards) external virtual onlyProxyAdmin firewallProtected {
    if (_mainchainTokens.length == 0) revert ErrEmptyArray();
    _mapTokens(_mainchainTokens, _roninTokens, _standards);
  }

  /**
   * @inheritdoc IMainchainGatewayV3
   */
  function mapTokensAndThresholds(
    address[] calldata _mainchainTokens,
    address[] calldata _roninTokens,
    TokenStandard[] calldata _standards,
    // _thresholds[0]: highTierThreshold
    // _thresholds[1]: lockedThreshold
    // _thresholds[2]: unlockFeePercentages
    // _thresholds[3]: dailyWithdrawalLimit
    uint256[][4] calldata _thresholds
  ) external virtual onlyProxyAdmin firewallProtected {
    if (_mainchainTokens.length == 0) revert ErrEmptyArray();
    _mapTokens(_mainchainTokens, _roninTokens, _standards);
    _setHighTierThresholds(_mainchainTokens, _thresholds[0]);
    _setLockedThresholds(_mainchainTokens, _thresholds[1]);
    _setUnlockFeePercentages(_mainchainTokens, _thresholds[2]);
    _setDailyWithdrawalLimits(_mainchainTokens, _thresholds[3]);
  }

  /**
   * @inheritdoc IMainchainGatewayV3
   */
  function getRoninToken(address mainchainToken) public view returns (MappedToken memory token) {
    token = _roninToken[mainchainToken];
    if (token.tokenAddr == address(0)) revert ErrUnsupportedToken();
  }

  /**
   * @dev Maps mainchain tokens to Ronin network.
   *
   * Requirement:
   * - The arrays have the same length.
   *
   * Emits the `TokenMapped` event.
   *
   */
  function _mapTokens(address[] calldata mainchainTokens, address[] calldata roninTokens, TokenStandard[] calldata standards) internal virtual {
    if (!(mainchainTokens.length == roninTokens.length && mainchainTokens.length == standards.length)) revert ErrLengthMismatch(msg.sig);

    for (uint256 i; i < mainchainTokens.length; ++i) {
      _roninToken[mainchainTokens[i]].tokenAddr = roninTokens[i];
      _roninToken[mainchainTokens[i]].erc = standards[i];
    }

    emit TokenMapped(mainchainTokens, roninTokens, standards);
  }

  /**
   * @dev Submits withdrawal receipt.
   *
   * Requirements:
   * - The receipt kind is withdrawal.
   * - The receipt is to withdraw on this chain.
   * - The receipt is not used to withdraw before.
   * - The withdrawal is not reached the limit threshold.
   * - The signer weight total is larger than or equal to the minimum threshold.
   * - The signature signers are in order.
   *
   * Emits the `Withdrew` once the assets are released.
   *
   */
  function _submitWithdrawal(Transfer.Receipt calldata receipt, Signature[] memory signatures) internal virtual returns (bool locked) {
    uint256 id = receipt.id;
    uint256 quantity = receipt.info.quantity;
    address tokenAddr = receipt.mainchain.tokenAddr;

    receipt.info.validate();
    if (receipt.kind != Transfer.Kind.Withdrawal) revert ErrInvalidReceiptKind();

    if (receipt.mainchain.chainId != block.chainid) {
      revert ErrInvalidChainId(msg.sig, receipt.mainchain.chainId, block.chainid);
    }

    MappedToken memory token = getRoninToken(receipt.mainchain.tokenAddr);

    if (!(token.erc == receipt.info.erc && token.tokenAddr == receipt.ronin.tokenAddr && receipt.ronin.chainId == roninChainId)) {
      revert ErrInvalidReceipt();
    }

    if (withdrawalHash[id] != 0) revert ErrQueryForProcessedWithdrawal();

    if (!(receipt.info.erc == TokenStandard.ERC721 || !_reachedWithdrawalLimit(tokenAddr, quantity))) {
      revert ErrReachedDailyWithdrawalLimit();
    }

    bytes32 receiptHash = receipt.hash();
    bytes32 receiptDigest = Transfer.receiptDigest(_domainSeparator, receiptHash);

    uint256 minimumWeight;
    (minimumWeight, locked) = _computeMinVoteWeight(receipt.info.erc, tokenAddr, quantity);

    {
      bool passed;
      address signer;
      address lastSigner;
      Signature memory sig;
      uint256 weight;
      for (uint256 i; i < signatures.length; i++) {
        sig = signatures[i];
        signer = ecrecover(receiptDigest, sig.v, sig.r, sig.s);
        if (lastSigner >= signer) revert ErrInvalidOrder(msg.sig);

        lastSigner = signer;

        weight += _getWeight(signer);
        if (weight >= minimumWeight) {
          passed = true;
          break;
        }
      }

      if (!passed) revert ErrQueryForInsufficientVoteWeight();
      withdrawalHash[id] = receiptHash;
    }

    if (locked) {
      withdrawalLocked[id] = true;
      emit WithdrawalLocked(receiptHash, receipt);
      return locked;
    }

    _recordWithdrawal(tokenAddr, quantity);
    receipt.info.handleAssetOut(payable(receipt.mainchain.addr), tokenAddr, wrappedNativeToken);
    emit Withdrew(receiptHash, receipt);
  }

  /**
   * @dev Requests deposit made by `_requester` address.
   *
   * Requirements:
   * - The token info is valid.
   * - The `msg.value` is 0 while depositing ERC20 token.
   * - The `msg.value` is equal to deposit quantity while depositing native token.
   *
   * Emits the `DepositRequested` event.
   *
   */
  function _requestDepositFor(Transfer.Request memory _request, address _requester) internal virtual {
    MappedToken memory _token;
    address _roninWeth = address(wrappedNativeToken);

    _request.info.validate();
    if (_request.tokenAddr == address(0)) {
      if (_request.info.quantity != msg.value) revert ErrInvalidRequest();

      _token = getRoninToken(_roninWeth);
      if (_token.erc != _request.info.erc) revert ErrInvalidTokenStandard();

      _request.tokenAddr = _roninWeth;
    } else {
      if (msg.value != 0) revert ErrInvalidRequest();

      _token = getRoninToken(_request.tokenAddr);
      if (_token.erc != _request.info.erc) revert ErrInvalidTokenStandard();

      _request.info.handleAssetIn(_requester, _request.tokenAddr);
      // Withdraw if token is WETH
      // The withdraw of WETH must go via `WethUnwrapper`, because `WETH.withdraw` only sends 2300 gas, which is insufficient when recipient is a proxy.
      if (_roninWeth == _request.tokenAddr) {
        wrappedNativeToken.approve(address(wethUnwrapper), _request.info.quantity);
        wethUnwrapper.unwrap(_request.info.quantity);
      }
    }

    uint256 _depositId = depositCount++;
    Transfer.Receipt memory _receipt = _request.into_deposit_receipt(_requester, _depositId, _token.tokenAddr, roninChainId);

    emit DepositRequested(_receipt.hash(), _receipt);
  }

  /**
   * @dev Returns the minimum vote weight for the token.
   */
  function _computeMinVoteWeight(TokenStandard _erc, address _token, uint256 _quantity) internal virtual returns (uint256 _weight, bool _locked) {
    uint256 _totalWeight = _getTotalWeight();
    _weight = _minimumVoteWeight(_totalWeight);
    if (_erc == TokenStandard.ERC20) {
      if (highTierThreshold[_token] <= _quantity) {
        _weight = _highTierVoteWeight(_totalWeight);
      }
      _locked = _lockedWithdrawalRequest(_token, _quantity);
    }
  }

  /**
   * @dev Update domain seperator.
   */
  function _updateDomainSeparator() internal {
    /*
     * _domainSeparator = keccak256(
     *   abi.encode(
     *     keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
     *     keccak256("MainchainGatewayV2"),
     *     keccak256("2"),
     *     block.chainid,
     *     address(this)
     *   )
     * );
     */
    assembly {
      let ptr := mload(0x40)
      // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
      mstore(ptr, 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f)
      // keccak256("MainchainGatewayV2")
      mstore(add(ptr, 0x20), 0x159f52c1e3a2b6a6aad3950adf713516211484e0516dad685ea662a094b7c43b)
      // keccak256("2")
      mstore(add(ptr, 0x40), 0xad7c5bef027816a800da1736444fb58a807ef4c9603b7848673f7e3a68eb14a5)
      mstore(add(ptr, 0x60), chainid())
      mstore(add(ptr, 0x80), address())
      sstore(_domainSeparator.slot, keccak256(ptr, 0xa0))
    }
  }

  /**
   * @dev Sets the WETH contract.
   *
   * Emits the `WrappedNativeTokenContractUpdated` event.
   *
   */
  function _setWrappedNativeTokenContract(IWETH _wrapedToken) internal {
    wrappedNativeToken = _wrapedToken;
    emit WrappedNativeTokenContractUpdated(_wrapedToken);
  }

  /**
   * @dev Receives ETH from WETH or creates deposit request if sender is not WETH or WETHUnwrapper.
   */
  function _fallback() internal virtual {
    if (msg.sender == address(wrappedNativeToken) || msg.sender == address(wethUnwrapper)) {
      return;
    }

    _createDepositOnFallback();
  }

  /**
   * @dev Creates deposit request.
   */
  function _createDepositOnFallback() internal virtual whenNotPaused {
    Transfer.Request memory _request;
    _request.recipientAddr = msg.sender;
    _request.info.quantity = msg.value;
    _requestDepositFor(_request, _request.recipientAddr);
  }

  /**
   * @inheritdoc GatewayV3
   */
  function _getTotalWeight() internal view override returns (uint256) {
    return _totalOperatorWeight;
  }

  /**
   * @dev Returns the weight of an address.
   */
  function _getWeight(address addr) internal view returns (uint256) {
    return _operatorWeight[addr];
  }

  ///////////////////////////////////////////////
  //                CALLBACKS
  ///////////////////////////////////////////////

  /**
   * @inheritdoc IBridgeManagerCallback
   */
  function onBridgeOperatorsAdded(
    address[] calldata operators,
    uint96[] calldata weights,
    bool[] memory addeds
  ) external onlyContract(ContractType.BRIDGE_MANAGER) returns (bytes4) {
    uint256 length = operators.length;
    if (length != addeds.length || length != weights.length) revert ErrLengthMismatch(msg.sig);
    if (length == 0) {
      return IBridgeManagerCallback.onBridgeOperatorsAdded.selector;
    }

    for (uint256 i; i < length; ++i) {
      unchecked {
        if (addeds[i]) {
          _totalOperatorWeight += weights[i];
          _operatorWeight[operators[i]] = weights[i];
        }
      }
    }

    return IBridgeManagerCallback.onBridgeOperatorsAdded.selector;
  }

  /**
   * @inheritdoc IBridgeManagerCallback
   */
  function onBridgeOperatorsRemoved(address[] calldata operators, bool[] calldata removeds) external onlyContract(ContractType.BRIDGE_MANAGER) returns (bytes4) {
    uint length = operators.length;
    if (length != removeds.length) revert ErrLengthMismatch(msg.sig);
    if (length == 0) {
      return IBridgeManagerCallback.onBridgeOperatorsRemoved.selector;
    }

    uint96 totalRemovingWeight;
    for (uint i; i < length; ++i) {
      unchecked {
        if (removeds[i]) {
          totalRemovingWeight += _operatorWeight[operators[i]];
          delete _operatorWeight[operators[i]];
        }
      }
    }

    _totalOperatorWeight -= totalRemovingWeight;

    return IBridgeManagerCallback.onBridgeOperatorsRemoved.selector;
  }

  function supportsInterface(bytes4 interfaceId) public view override(AccessControlEnumerable, IERC165, ERC1155Receiver) returns (bool) {
    return
      interfaceId == type(IMainchainGatewayV3).interfaceId || interfaceId == type(IBridgeManagerCallback).interfaceId || super.supportsInterface(interfaceId);
  }
}
