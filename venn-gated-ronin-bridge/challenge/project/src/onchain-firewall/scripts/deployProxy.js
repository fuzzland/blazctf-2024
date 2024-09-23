const hre = require('hardhat')

const ETH_ADDRESS = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';

async function main() {
    const deployer = await hre.ethers.getSigner();

    const ProxyAdminFactory = await ethers.getContractFactory('ProxyAdmin');
    const Firewall = await hre.ethers.getContractFactory("Firewall", deployer);
    const BalanceChangeOrApprovedCallsWithSignaturePolicy = await hre.ethers.getContractFactory("BalanceChangeOrApprovedCallsWithSignaturePolicy", deployer);
    const TransparentUpgradeableProxyFactory = await ethers.getContractFactory(
        'TransparentUpgradeableProxy'
    );
    const FirewallProxyInterceptFactory = await hre.ethers.getContractFactory(
        'FirewallProxyIntercept'
    );
    const SampleConsumerUpgradeableFactory = await hre.ethers.getContractFactory(
        'SampleConsumerUpgradeable'
    );
    const SampleToken = await ethers.getContractFactory('SampleToken');

    const testToken = await SampleToken.deploy();
    await testToken.deployed();
    console.log("TestToken deployed to:", testToken.address);
    const firewall = await Firewall.deploy();
    await firewall.deployed();
    console.log("Firewall deployed to:", firewall.address);
    const balanceChangeOrApprovedCallsWithSignaturePolicy = await BalanceChangeOrApprovedCallsWithSignaturePolicy.deploy();
    await balanceChangeOrApprovedCallsWithSignaturePolicy.deployed();
    console.log("BalanceChangeOrApprovedCallsWithSignaturePolicy deployed to:", balanceChangeOrApprovedCallsWithSignaturePolicy.address);
    const proxyAdmin = await ProxyAdminFactory.deploy();
    await proxyAdmin.deployed();
    console.log("ProxyAdmin deployed to:", proxyAdmin.address);
    const sampleConsumerImplementation = await SampleConsumerUpgradeableFactory.deploy();
    await sampleConsumerImplementation.deployed();
    const sampleConsumerIface = SampleConsumerUpgradeableFactory.interface;
    const firewallProxyInterceptIface = FirewallProxyInterceptFactory.interface;
    const sampleConsumerProxy = await TransparentUpgradeableProxyFactory.deploy(
        sampleConsumerImplementation.address,
        proxyAdmin.address,
        sampleConsumerIface.encodeFunctionData('initialize', []),
    );
    await sampleConsumerProxy.deployed();
    console.log("SampleConsumer (Proxy) deployed to:", sampleConsumerProxy.address);

    const firewallProxyIntercept = await FirewallProxyInterceptFactory.deploy(
        sampleConsumerImplementation.address,
        proxyAdmin.address,
        '0x'
    );
    await firewallProxyIntercept.deployed();
    await (await proxyAdmin.upgradeAndCall(
        sampleConsumerProxy.address,
        firewallProxyIntercept.address,
        firewallProxyInterceptIface.encodeFunctionData(
            'initialize(address,address,address)',
            [firewall.address, deployer.address, sampleConsumerImplementation.address]
        )
    )).wait();

    await (await balanceChangeOrApprovedCallsWithSignaturePolicy.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes('SIGNER_ROLE')), deployer.address)).wait();

    await (await firewall.setPolicyStatus(balanceChangeOrApprovedCallsWithSignaturePolicy.address, true)).wait();
    await (await firewall.addGlobalPolicy(
        sampleConsumerProxy.address,
        balanceChangeOrApprovedCallsWithSignaturePolicy.address
    )).wait();
    await (await balanceChangeOrApprovedCallsWithSignaturePolicy.setConsumerMaxBalanceChange(
        sampleConsumerProxy.address,
        ETH_ADDRESS,
        ethers.utils.parseEther("0.0001")
    )).wait();
    await (await balanceChangeOrApprovedCallsWithSignaturePolicy.setConsumerMaxBalanceChange(
        sampleConsumerProxy.address,
        testToken.address,
        ethers.utils.parseEther("0.0001")
    )).wait();
    await (await testToken.transfer(
        '0xF092dAD59019613109cB8Cec9547b2aEE3BB6f28',
        ethers.utils.parseEther("100")
    )).wait();
    console.log("Done");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
