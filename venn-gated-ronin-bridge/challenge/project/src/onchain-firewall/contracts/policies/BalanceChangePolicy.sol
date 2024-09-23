// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {FirewallPolicyBase} from "./FirewallPolicyBase.sol";

/**
 * @dev This policy asserts that a consumer contracts balance change (for eth or tokens) doesn't
 * exceed a configurable amount for a function call.
 *
 * NOTE: This policy works by comparing the balance of the consumer before and after the function call.
 * Based on your use case and how your Firewall Consumer's functions are implemented, there may still
 * be a change to a user's balance which may exceed a configured threshold, if the change occurs
 * internally (i.e. in a scope not managed by this policy) but then returns below the threshold when
 * execution is given back to the policy.
 *
 * If you have any questions on how or when to use this modifier, please refer to the Firewall's documentation
 * and/or contact our support.
 */
contract BalanceChangePolicy is FirewallPolicyBase {
    // The address of the ETH token
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // consumer => token => uint256
    mapping (address consumer => mapping (address token => uint256 tokenMaxBalanceChange)) public consumerMaxBalanceChange;
    // consumer => token => uint256[]
    mapping (address consumer => mapping(address token => uint256[] lastBalancesArray)) public consumerLastBalance;
    // consumer => token[]
    mapping (address consumer => address[] consumersMonitoredTokens) private _consumerTokens;
    // consumer => token => bool
    mapping (address consumer => mapping(address token => bool isConsumerMonitoringToken)) private _monitoringToken;

    constructor(address _firewallAddress) FirewallPolicyBase() {
        authorizedExecutors[_firewallAddress] = true;
    }

    /**
     * @dev This function is called before the execution of a transaction.
     * It stores the current balance of the consumer before the transaction is executed.
     *
     * @param consumer The address of the contract that is being called.
     */
    function preExecution(address consumer, address, bytes memory, uint256 value) external isAuthorized(consumer) {
        address[] memory consumerTokens = _consumerTokens[consumer];
        for (uint256 i = 0; i < consumerTokens.length; i++) {
            address token = consumerTokens[i];
            uint256 preBalance = token == ETH ? consumer.balance - value : IERC20(token).balanceOf(consumer);
            consumerLastBalance[consumer][token].push(preBalance);
        }
    }

    /**
     * @dev This function is called after the execution of a transaction.
     * It checks that the balance change of the consumer doesn't exceed the configured amount.
     *
     * @param consumer The address of the contract that is being called.
     */
    function postExecution(address consumer, address, bytes memory, uint256) external isAuthorized(consumer) {
        address[] memory consumerTokens = _consumerTokens[consumer];
        for (uint256 i = 0; i < consumerTokens.length; i++) {
            address token = consumerTokens[i];
            uint256[] storage lastBalanceArray = consumerLastBalance[consumer][token];
            uint256 lastBalance = lastBalanceArray[lastBalanceArray.length - 1];
            uint256 postBalance = token == ETH ? consumer.balance : IERC20(token).balanceOf(consumer);
            uint256 difference = postBalance >= lastBalance ? postBalance - lastBalance : lastBalance - postBalance;
            require(difference <= consumerMaxBalanceChange[consumer][token], "BalanceChangePolicy: Balance change exceeds limit");
            lastBalanceArray.pop();
        }
    }

    /**
     * @dev This function is called to remove a token from the consumer's list of monitored tokens.
     *
     * @param consumer The address of the consumer contract.
     * @param token The address of the token to remove.
     */
    function removeToken(
        address consumer,
        address token
    ) external onlyRole(POLICY_ADMIN_ROLE) {
        address[] storage consumerTokens = _consumerTokens[consumer];
        for (uint256 i = 0; i < consumerTokens.length; i++) {
            if (token == consumerTokens[i]) {
                consumerTokens[i] = consumerTokens[consumerTokens.length - 1];
                consumerTokens.pop();
                break;
            }
        }
        consumerMaxBalanceChange[consumer][token] = 0;
        _monitoringToken[consumer][token] = false;
    }

    /**
     * @dev This function is called to set the maximum balance change for a consumer.
     *
     * @param consumer The address of the consumer contract.
     * @param token The address of the token to set the maximum balance change for.
     * @param maxBalanceChange The maximum balance change to set.
     */
    function setConsumerMaxBalanceChange(
        address consumer,
        address token,
        uint256 maxBalanceChange
    ) external onlyRole(POLICY_ADMIN_ROLE) {
        consumerMaxBalanceChange[consumer][token] = maxBalanceChange;
        if (!_monitoringToken[consumer][token]) {
            _consumerTokens[consumer].push(token);
            _monitoringToken[consumer][token] = true;
        }
    }

    /**
     * @dev This function is called get the tokens that a consumer is monitoring.
     *
     * @param consumer The address of the consumer contract.
     */
    function getConsumerTokens(address consumer) external view returns (address[] memory) {
        return _consumerTokens[consumer];
    }
}
