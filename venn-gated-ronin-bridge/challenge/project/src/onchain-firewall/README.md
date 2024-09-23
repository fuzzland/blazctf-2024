# <img src="ironblocks-logo.svg" alt="Ironblocks" height="40px">

[![NPM Package](https://img.shields.io/npm/v/@ironblocks/firewall-consumer.svg)](https://www.npmjs.org/package/@ironblocks/firewall-consumer)

**A Solidity library providing an open marketplace of access control policies.** Build on a constantly growing community of open source policies.

 * Basic policies, like [Allowlists](./contracts/policies/AllowlistPolicy.sol) and [`Maximum Balance Change`](./contracts/policies/BalanceChangePolicy.sol)
 * More advanced policies, such as [2FA admin calls](./contracts/policies/AdminCallPolicy.sol) and general [`approved calls`](./contracts/policies/ApprovedCallsPolicy.sol)

:mage: **Not sure how to start?** Feel free to ping our devs in our [Discord](https://discord.com/invite/bHjwyrqsn6)

## Overview

### Inspiration

This collection of smart contracts can be thought of as an open marketplace of upgradeable access control policies. Consumers (contracts which use the firewall) need to add the modifier `firewallProtected` to any functions that they want to be able to have control of. After doing so, they can decide which policies they'd like to apply on a per-function basis. For example, there can be a `mint` function which asserts that the sender belongs on a certain allowlist, and a `ownerWithdraw` function which implements a 2 factor authentication method in case a sensitive key gets leaked. As more use cases are needed and brought to the marketplace, they can be added and subscribed to in a modular fashion without needing to upgrade any contracts.

### Installation

```
$ npm install @ironblocks/firewall-consumer
```

An alternative to npm is to use the GitHub repository (`ironblocks/firewall`) to retrieve the contracts. When doing this, make sure to specify the tag for a release such as `v4.5.0`, instead of using the `master` branch.

### Usage

Once installed, you can use the contracts in the library by importing them:

```solidity
pragma solidity ^0.8.19;

import "@ironblocks/firewall-consumer/contracts/FirewallConsumer.sol";

contract MyProtectedContract is FirewallConsumer {
    constructor() {
    }

    function1() external firewallProtected {

    }

    function2() external payable firewallProtected {

    }

    ...
}
```

To keep your system secure, you should **always** use the installed code as-is, and neither copy-paste it from online sources nor modify it yourself. The library is designed so that only the contracts and functions you use are deployed, so you don't need to worry about it needlessly increasing gas costs.

## Learn More

The guides in the [documentation site](https://www.ironblocks.com/) will teach about ...:

## Security

This project is maintained by [Ironblocks](https://www.ironblocks.com/) with the goal of providing a secure and reliable library of smart contract components for the ecosystem. We address security through risk management in various areas such as engineering and open source best practices, scoping and API design, multi-layered review processes, and incident response preparedness.

Audits can be found in [`audits/`](./audits).

Ironblocks Firewall Contracts are made available under the MIT License, which disclaims all warranties in relation to the project and which limits the liability of those that contribute and maintain the project, including Ironblocks. As set out further in the Terms, you acknowledge that you are solely responsible for any use of Ironblocks Contracts and you assume all risks associated with any such use.

## Contribute

Ironblocks Firewall Contracts exists as an opensource development and invites any and all contributors. There are many ways you can participate and improve the codebase, including adding custom policies. Check out the [contribution guide](CONTRIBUTING.md)!

## License

Ironblocks Firewall Contracts are released under the [MIT License](LICENSE).

## Legal

Your use of this Project is governed by the terms found at www.ironblocks.com/firewall-tos.