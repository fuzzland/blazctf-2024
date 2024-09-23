// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./LibTokenInfo.sol";
import "./LibTokenOwner.sol";

library Transfer {
  using ECDSA for bytes32;
  using LibTokenOwner for TokenOwner;
  using LibTokenInfo for TokenInfo;

  enum Kind {
    Deposit,
    Withdrawal
  }

  struct Request {
    // For deposit request: Recipient address on Ronin network
    // For withdrawal request: Recipient address on mainchain network
    address recipientAddr;
    // Token address to deposit/withdraw
    // Value 0: native token
    address tokenAddr;
    TokenInfo info;
  }

  /**
   * @dev Converts the transfer request into the deposit receipt.
   */
  function into_deposit_receipt(
    Request memory _request,
    address _requester,
    uint256 _id,
    address _roninTokenAddr,
    uint256 _roninChainId
  ) internal view returns (Receipt memory _receipt) {
    _receipt.id = _id;
    _receipt.kind = Kind.Deposit;
    _receipt.mainchain.addr = _requester;
    _receipt.mainchain.tokenAddr = _request.tokenAddr;
    _receipt.mainchain.chainId = block.chainid;
    _receipt.ronin.addr = _request.recipientAddr;
    _receipt.ronin.tokenAddr = _roninTokenAddr;
    _receipt.ronin.chainId = _roninChainId;
    _receipt.info = _request.info;
  }

  /**
   * @dev Converts the transfer request into the withdrawal receipt.
   */
  function into_withdrawal_receipt(
    Request memory _request,
    address _requester,
    uint256 _id,
    address _mainchainTokenAddr,
    uint256 _mainchainId
  ) internal view returns (Receipt memory _receipt) {
    _receipt.id = _id;
    _receipt.kind = Kind.Withdrawal;
    _receipt.ronin.addr = _requester;
    _receipt.ronin.tokenAddr = _request.tokenAddr;
    _receipt.ronin.chainId = block.chainid;
    _receipt.mainchain.addr = _request.recipientAddr;
    _receipt.mainchain.tokenAddr = _mainchainTokenAddr;
    _receipt.mainchain.chainId = _mainchainId;
    _receipt.info = _request.info;
  }

  struct Receipt {
    uint256 id;
    Kind kind;
    TokenOwner mainchain;
    TokenOwner ronin;
    TokenInfo info;
  }

  // keccak256("Receipt(uint256 id,uint8 kind,TokenOwner mainchain,TokenOwner ronin,TokenInfo info)TokenInfo(uint8 erc,uint256 id,uint256 quantity)TokenOwner(address addr,address tokenAddr,uint256 chainId)");
  bytes32 public constant TYPE_HASH = 0xb9d1fe7c9deeec5dc90a2f47ff1684239519f2545b2228d3d91fb27df3189eea;

  /**
   * @dev Returns token info struct hash.
   */
  function hash(Receipt memory _receipt) internal pure returns (bytes32 digest) {
    bytes32 hashedReceiptMainchain = _receipt.mainchain.hash();
    bytes32 hashedReceiptRonin = _receipt.ronin.hash();
    bytes32 hashedReceiptInfo = _receipt.info.hash();

    /*
     * return
     *   keccak256(
     *     abi.encode(
     *       TYPE_HASH,
     *       _receipt.id,
     *       _receipt.kind,
     *       Token.hash(_receipt.mainchain),
     *       Token.hash(_receipt.ronin),
     *       Token.hash(_receipt.info)
     *     )
     *   );
     */
    assembly {
      let ptr := mload(0x40)
      mstore(ptr, TYPE_HASH)
      mstore(add(ptr, 0x20), mload(_receipt)) // _receipt.id
      mstore(add(ptr, 0x40), mload(add(_receipt, 0x20))) // _receipt.kind
      mstore(add(ptr, 0x60), hashedReceiptMainchain)
      mstore(add(ptr, 0x80), hashedReceiptRonin)
      mstore(add(ptr, 0xa0), hashedReceiptInfo)
      digest := keccak256(ptr, 0xc0)
    }
  }

  /**
   * @dev Returns the receipt digest.
   */
  function receiptDigest(bytes32 _domainSeparator, bytes32 _receiptHash) internal pure returns (bytes32) {
    return _domainSeparator.toTypedDataHash(_receiptHash);
  }
}
