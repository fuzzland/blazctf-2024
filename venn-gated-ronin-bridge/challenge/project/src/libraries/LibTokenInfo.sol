// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/presets/ERC1155PresetMinterPauser.sol";
import "../interfaces/IWETH.sol";

enum TokenStandard {
  ERC20,
  ERC721,
  ERC1155
}

struct TokenInfo {
  TokenStandard erc;
  // For ERC20:  the id must be 0 and the quantity is larger than 0.
  // For ERC721: the quantity must be 0.
  uint256 id;
  uint256 quantity;
}

/**
 * @dev Error indicating that the `transfer` has failed.
 * @param tokenInfo Info of the token including ERC standard, id or quantity.
 * @param to Receiver of the token value.
 * @param token Address of the token.
 */
error ErrTokenCouldNotTransfer(TokenInfo tokenInfo, address to, address token);

/**
 * @dev Error indicating that the `handleAssetIn` has failed.
 * @param tokenInfo Info of the token including ERC standard, id or quantity.
 * @param from Owner of the token value.
 * @param to Receiver of the token value.
 * @param token Address of the token.
 */
error ErrTokenCouldNotTransferFrom(TokenInfo tokenInfo, address from, address to, address token);

/// @dev Error indicating that the provided information is invalid.
error ErrInvalidInfo();

/// @dev Error indicating that the minting of ERC20 tokens has failed.
error ErrERC20MintingFailed();

/// @dev Error indicating that the minting of ERC721 tokens has failed.
error ErrERC721MintingFailed();

/// @dev Error indicating that the transfer of ERC1155 tokens has failed.
error ErrERC1155TransferFailed();

/// @dev Error indicating that the mint of ERC1155 tokens has failed.
error ErrERC1155MintingFailed();

/// @dev Error indicating that an unsupported standard is encountered.
error ErrUnsupportedStandard();

library LibTokenInfo {
  /**
   *
   *        HASH
   *
   */

  // keccak256("TokenInfo(uint8 erc,uint256 id,uint256 quantity)");
  bytes32 public constant INFO_TYPE_HASH_SINGLE = 0x1e2b74b2a792d5c0f0b6e59b037fa9d43d84fbb759337f0112fcc15ca414fc8d;

  /**
   * @dev Returns token info struct hash.
   */
  function hash(TokenInfo memory self) internal pure returns (bytes32 digest) {
    // keccak256(abi.encode(INFO_TYPE_HASH_SINGLE, info.erc, info.id, info.quantity))
    assembly ("memory-safe") {
      let ptr := mload(0x40)
      mstore(ptr, INFO_TYPE_HASH_SINGLE)
      mstore(add(ptr, 0x20), mload(self)) // info.erc
      mstore(add(ptr, 0x40), mload(add(self, 0x20))) // info.id
      mstore(add(ptr, 0x60), mload(add(self, 0x40))) // info.quantity
      digest := keccak256(ptr, 0x80)
    }
  }

  /**
   *
   *         VALIDATE
   *
   */

  /**
   * @dev Validates the token info.
   */
  function validate(TokenInfo memory self) internal pure {
    if (!(_checkERC20(self) || _checkERC721(self) || _checkERC1155(self))) {
      revert ErrInvalidInfo();
    }
  }

  function _checkERC20(TokenInfo memory self) private pure returns (bool) {
    return (self.erc == TokenStandard.ERC20 && self.quantity > 0 && self.id == 0);
  }

  function _checkERC721(TokenInfo memory self) private pure returns (bool) {
    return (self.erc == TokenStandard.ERC721 && self.quantity == 0);
  }

  function _checkERC1155(TokenInfo memory self) private pure returns (bool res) {
    // Only validate the quantity, because id of ERC-1155 can be 0.
    return (self.erc == TokenStandard.ERC1155 && self.quantity > 0);
  }

  /**
   *
   *       TRANSFER IN/OUT METHOD
   *
   */

  /**
   * @dev Transfer asset in.
   *
   * Requirements:
   * - The `_from` address must approve for the contract using this library.
   *
   */
  function handleAssetIn(TokenInfo memory self, address from, address token) internal {
    bool success;
    bytes memory data;
    if (self.erc == TokenStandard.ERC20) {
      (success, data) = token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, address(this), self.quantity));
      success = success && (data.length == 0 || abi.decode(data, (bool)));
    } else if (self.erc == TokenStandard.ERC721) {
      success = _tryTransferFromERC721(token, from, address(this), self.id);
    } else if (self.erc == TokenStandard.ERC1155) {
      success = _tryTransferFromERC1155(token, from, address(this), self.id, self.quantity);
    } else {
      revert ErrUnsupportedStandard();
    }

    if (!success) revert ErrTokenCouldNotTransferFrom(self, from, address(this), token);
  }

  /**
   * @dev Tries transfer assets out, or mint the assets if cannot transfer.
   *
   * @notice Prioritizes transfer native token if the token is wrapped.
   *
   */
  function handleAssetOut(TokenInfo memory self, address payable to, address token, IWETH wrappedNativeToken) internal {
    if (token == address(wrappedNativeToken)) {
      // Try sending the native token before transferring the wrapped token
      if (!to.send(self.quantity)) {
        wrappedNativeToken.deposit{ value: self.quantity }();
        _transferTokenOut(self, to, token);
      }

      return;
    }

    if (self.erc == TokenStandard.ERC20) {
      uint256 balance = IERC20(token).balanceOf(address(this));
      if (balance < self.quantity) {
        if (!_tryMintERC20(token, address(this), self.quantity - balance)) revert ErrERC20MintingFailed();
      }

      _transferTokenOut(self, to, token);
      return;
    }

    if (self.erc == TokenStandard.ERC721) {
      if (!_tryTransferOutOrMintERC721(token, to, self.id)) {
        revert ErrERC721MintingFailed();
      }
      return;
    }

    if (self.erc == TokenStandard.ERC1155) {
      if (!_tryTransferOutOrMintERC1155(token, to, self.id, self.quantity)) {
        revert ErrERC1155MintingFailed();
      }
      return;
    }

    revert ErrUnsupportedStandard();
  }

  /**
   *
   *      TRANSFER HELPERS
   *
   */

  /**
   * @dev Transfer assets from current address to `_to` address.
   */
  function _transferTokenOut(TokenInfo memory self, address to, address token) private {
    bool success;
    if (self.erc == TokenStandard.ERC20) {
      success = _tryTransferERC20(token, to, self.quantity);
    } else if (self.erc == TokenStandard.ERC721) {
      success = _tryTransferFromERC721(token, address(this), to, self.id);
    } else {
      revert ErrUnsupportedStandard();
    }

    if (!success) revert ErrTokenCouldNotTransfer(self, to, token);
  }

  /**
   *      TRANSFER ERC-20
   */

  /**
   * @dev Transfers ERC20 token and returns the result.
   */
  function _tryTransferERC20(address token, address to, uint256 quantity) private returns (bool success) {
    bytes memory data;
    (success, data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, quantity));
    success = success && (data.length == 0 || abi.decode(data, (bool)));
  }

  /**
   * @dev Mints ERC20 token and returns the result.
   */
  function _tryMintERC20(address token, address to, uint256 quantity) private returns (bool success) {
    // bytes4(keccak256("mint(address,uint256)"))
    (success,) = token.call(abi.encodeWithSelector(0x40c10f19, to, quantity));
  }

  /**
   *      TRANSFER ERC-721
   */

  /**
   * @dev Transfers the ERC721 token out. If the transfer failed, mints the ERC721.
   * @return success Returns `false` if both transfer and mint are failed.
   */
  function _tryTransferOutOrMintERC721(address token, address to, uint256 id) private returns (bool success) {
    success = _tryTransferFromERC721(token, address(this), to, id);
    if (!success) {
      return _tryMintERC721(token, to, id);
    }
  }

  /**
   * @dev Transfers ERC721 token and returns the result.
   */
  function _tryTransferFromERC721(address token, address from, address to, uint256 id) private returns (bool success) {
    (success,) = token.call(abi.encodeWithSelector(IERC721.transferFrom.selector, from, to, id));
  }

  /**
   * @dev Mints ERC721 token and returns the result.
   */
  function _tryMintERC721(address token, address to, uint256 id) private returns (bool success) {
    // bytes4(keccak256("mint(address,uint256)"))
    (success,) = token.call(abi.encodeWithSelector(0x40c10f19, to, id));
  }

  /**
   *      TRANSFER ERC-1155
   */

  /**
   * @dev Transfers the ERC1155 token out. If the transfer failed, mints the ERC11555.
   * @return success Returns `false` if both transfer and mint are failed.
   */
  function _tryTransferOutOrMintERC1155(address token, address to, uint256 id, uint256 amount) private returns (bool success) {
    success = _tryTransferFromERC1155(token, address(this), to, id, amount);
    if (!success) {
      return _tryMintERC1155(token, to, id, amount);
    }
  }

  /**
   * @dev Transfers ERC1155 token and returns the result.
   */
  function _tryTransferFromERC1155(address token, address from, address to, uint256 id, uint256 amount) private returns (bool success) {
    (success,) = token.call(abi.encodeCall(IERC1155.safeTransferFrom, (from, to, id, amount, new bytes(0))));
  }

  /**
   * @dev Mints ERC1155 token and returns the result.
   */
  function _tryMintERC1155(address token, address to, uint256 id, uint256 amount) private returns (bool success) {
    (success,) = token.call(abi.encodeCall(ERC1155PresetMinterPauser.mint, (to, id, amount, new bytes(0))));
  }
}
