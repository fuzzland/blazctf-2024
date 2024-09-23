require('dotenv').config();
require('@nomiclabs/hardhat-waffle');
require('@nomiclabs/hardhat-etherscan');
require('@openzeppelin/hardhat-upgrades');
require('hardhat-abi-exporter');
require('hardhat-gas-reporter');
require('solidity-coverage');

module.exports = {
    networks: {
        local: {
            url: 'http://localhost:8545',
        },
        matic: {
            url: 'https://polygon-rpc.com/',
            accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
        },
        goerli: {
            url: 'https://rpc.ankr.com/eth_goerli',
            accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
        },
        sepolia: {
            url: 'https://ethereum-sepolia.publicnode.com',
            accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
            gasPrice: 100000000000,
        },
        bscTestnet: {
            url: 'https://bsc-testnet.publicnode.com',
            accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
        },
    },
    etherscan: {
        apiKey: process.env.API_KEY,
    },
    solidity: {
        version: '0.8.19',
        settings: {
            optimizer: {
                enabled: true,
                runs: 10000,
            },
        },
    },
    abiExporter: {
        runOnCompile: true,
        clear: true,
        flat: true,
    },
};
