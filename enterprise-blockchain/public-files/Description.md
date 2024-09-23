# Enterprise Chain

Hack the block-chain.

# [Account Information]

- L1/L2 Address: 0xa89117eee9a536373914f703f415967e57428544
- Private key: 0x4d871d0798f979898989813d4936a73bf461626364414243447033dff6d40982
- Balance: 10 ETH / 1 FTT (L1)

# [RPC Usage]

`ACCESS_TOKEN`: Whatever you want. Each access token creates a unique environment. Don't use an easily guessable token!

- RPC: `http://host:port/rpc/{L1|L2}/{ACCESS_TOKEN}`
- Reset: `http://host:port/reset/{ACCESS_TOKEN}`
- Get Flag: `http://host:port/flag/{ACCESS_TOKEN}`
  - Make L1 bridge's FTT balance < 90.
- Chain ID: 78704 (L1) / 78705 (L2)

# [Address Information]
- Bridge: 0x15c4cA379fce93A279ac49222116A443B972C777
- FTT (L1): 0x5a8a905508532d4C98D1f8318233A96FeFb4cEbc
- L2 Multisig: 0x31337

# [Patch Version]
- foundry: commit 8e365beee278975720ecd3eb529b5dd6d17cac3b (tag: nightly-8e365beee278975720ecd3eb529b5dd6d17cac3b, tag: nightly)
- revm: commit 88337924f4d16ed1f5e4cde12a03d0cb755cd658 (origin/release/v25)
