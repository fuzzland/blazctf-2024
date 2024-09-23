// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/Pausable.sol";
import "../interfaces/IQuorum.sol";
import "./collections/HasProxyAdmin.sol";

abstract contract GatewayV3 is HasProxyAdmin, Pausable, IQuorum {
  uint256 internal _num;
  uint256 internal _denom;

  address private ______deprecated;
  uint256 public nonce;

  address public emergencyPauser;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[49] private ______gap;

  /**
   * @dev Grant emergency pauser role for `_addr`.
   */
  function setEmergencyPauser(address _addr) external onlyProxyAdmin {
    emergencyPauser = _addr;
  }

  /**
   * @inheritdoc IQuorum
   */
  function getThreshold() external view virtual returns (uint256 num_, uint256 denom_) {
    return (_num, _denom);
  }

  /**
   * @inheritdoc IQuorum
   */
  function checkThreshold(uint256 _voteWeight) external view virtual returns (bool) {
    return _voteWeight * _denom >= _num * _getTotalWeight();
  }

  /**
   * @inheritdoc IQuorum
   */
  function setThreshold(uint256 _numerator, uint256 _denominator) external virtual onlyProxyAdmin {
    return _setThreshold(_numerator, _denominator);
  }

  /**
   * @dev Triggers paused state.
   */
  function pause() external {
    _requireAuth();
    _pause();
  }

  /**
   * @dev Triggers unpaused state.
   */
  function unpause() external {
    _requireAuth();
    _unpause();
  }

  /**
   * @inheritdoc IQuorum
   */
  function minimumVoteWeight() public view virtual returns (uint256) {
    return _minimumVoteWeight(_getTotalWeight());
  }

  /**
   * @dev Sets threshold and returns the old one.
   *
   * Emits the `ThresholdUpdated` event.
   *
   */
  function _setThreshold(uint256 num, uint256 denom) internal virtual {
    if (num > denom) revert ErrInvalidThreshold(msg.sig);
    uint256 prevNum = _num;
    uint256 prevDenom = _denom;
    _num = num;
    _denom = denom;
    unchecked {
      emit ThresholdUpdated(nonce++, num, denom, prevNum, prevDenom);
    }
  }

  /**
   * @dev Returns minimum vote weight.
   */
  function _minimumVoteWeight(uint256 _totalWeight) internal view virtual returns (uint256) {
    return (_num * _totalWeight + _denom - 1) / _denom;
  }

  /**
   * @dev Internal method to check method caller.
   *
   * Requirements:
   *
   * - The method caller must be admin or pauser.
   *
   */
  function _requireAuth() private view {
    if (!(msg.sender == _getProxyAdmin() || msg.sender == emergencyPauser)) {
      revert ErrUnauthorized(msg.sig, RoleAccess.ADMIN);
    }
  }

  /**
   * @dev Returns the total weight.
   */
  function _getTotalWeight() internal view virtual returns (uint256);
}
