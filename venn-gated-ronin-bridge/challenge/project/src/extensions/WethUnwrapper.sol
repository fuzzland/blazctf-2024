// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IWETH.sol";

contract WethUnwrapper is ReentrancyGuard {
  IWETH public immutable weth;

  error ErrCannotTransferFrom();
  error ErrNotWrappedContract();
  error ErrExternalCallFailed(address sender, bytes4 sig);

  constructor(address weth_) {
    if (address(weth_).code.length == 0) revert ErrNotWrappedContract();
    weth = IWETH(weth_);
  }

  fallback() external payable {
    _fallback();
  }

  receive() external payable {
    _fallback();
  }

  function unwrap(uint256 amount) external nonReentrant {
    _deductWrappedAndWithdraw(amount);
    _sendNativeTo(payable(msg.sender), amount);
  }

  function unwrapTo(uint256 amount, address payable to) external nonReentrant {
    _deductWrappedAndWithdraw(amount);
    _sendNativeTo(payable(to), amount);
  }

  function _deductWrappedAndWithdraw(uint256 amount) internal {
    (bool success,) = address(weth).call(abi.encodeCall(IWETH.transferFrom, (msg.sender, address(this), amount)));
    if (!success) revert ErrCannotTransferFrom();

    weth.withdraw(amount);
  }

  function _sendNativeTo(address payable to, uint256 val) internal {
    (bool success,) = to.call{ value: val }("");
    if (!success) {
      revert ErrExternalCallFailed(to, msg.sig);
    }
  }

  function _fallback() internal view {
    if (msg.sender != address(weth)) revert ErrNotWrappedContract();
  }
}
