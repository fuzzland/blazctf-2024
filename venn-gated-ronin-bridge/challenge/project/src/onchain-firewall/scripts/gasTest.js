const hre = require('hardhat')

async function main() {
    const deployer = await hre.ethers.getSigner();
    const ApprovedCallsPolicyFactory = await hre.ethers.getContractFactory("ApprovedCallsPolicy", deployer);
    const approvedCallsPolicy = await ApprovedCallsPolicyFactory.deploy();
    const callHash = hre.ethers.utils.solidityKeccak256(
    ["address", "address", "address", "bytes", "uint256", "uint256"],
    [
        deployer.address,
        deployer.address,
        deployer.address,
        "0x12",
        0,
        123123123,
    ]);
    console.log(callHash);
    const estimation = await approvedCallsPolicy.estimateGas.approveCall(
        callHash
    );
    console.log("Estimation: ", estimation.toString());
    const gasCostInEth = hre.ethers.utils.formatEther(estimation.mul(hre.ethers.utils.parseUnits("20", "gwei")));
    console.log(gasCostInEth.toString());
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
