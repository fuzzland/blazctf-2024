const hre = require('hardhat')

async function main() {
    const deployer = await hre.ethers.getSigner();

    const Firewall = await hre.ethers.getContractFactory("Firewall", deployer);
    const SampleConsumer = await hre.ethers.getContractFactory("SampleConsumer", deployer);
    const ApprovedCallsPolicy = await hre.ethers.getContractFactory("ApprovedCallsPolicy", deployer);

    const firewall = await Firewall.deploy();
    await firewall.deployed();
    const approvedCallsPolicy = await ApprovedCallsPolicy.deploy();
    await approvedCallsPolicy.deployed();
    const sampleConsumer = await SampleConsumer.deploy(firewall.address);
    await sampleConsumer.deployed();

    await approvedCallsPolicy.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes('SIGNER_ROLE')), deployer.address);

    console.log("Firewall deployed to:", firewall.address);
    console.log("ApprovedCallsPolicy deployed to:", approvedCallsPolicy.address);
    console.log("SampleConsumer deployed to:", sampleConsumer.address);

    await firewall.setPolicyStatus(approvedCallsPolicy.address, true);
    await firewall.addGlobalPolicy(
        sampleConsumer.address,
        approvedCallsPolicy.address
    );
    console.log("Done");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
