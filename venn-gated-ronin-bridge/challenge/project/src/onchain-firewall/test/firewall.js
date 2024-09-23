const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('Firewall', function () {
    let owner, addr1, addr2;
    let firewall, sampleConsumer;
    const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
    const ZERO_METHOD_SIG = '0x00000000';

    beforeEach(async function () {
        [owner, addr1, addr2] = await ethers.getSigners();
        const FirewallFactory = await ethers.getContractFactory('Firewall');
        const SampleConsumerFactory = await ethers.getContractFactory(
            'SampleConsumer'
        );
        firewall = await FirewallFactory.deploy();
        sampleConsumer = await SampleConsumerFactory.deploy(firewall.address);
    });

    it('Firewall consumer settings', async function () {
        const FirewallFactory = await ethers.getContractFactory('Firewall');
        const firewall2 = await FirewallFactory.deploy();
        await expect(
            sampleConsumer.connect(addr2).setFirewall(firewall2.address)
        ).to.be.revertedWith('FirewallConsumer: not firewall admin');
        await expect(
            sampleConsumer.connect(owner).setFirewall(firewall2.address)
        ).to.not.be.reverted;
        await expect(
            sampleConsumer.connect(addr1).setFirewallAdmin(addr2.address)
        ).to.be.revertedWith('FirewallConsumer: not firewall admin');
        await expect(
            sampleConsumer.connect(owner).setFirewallAdmin(addr2.address)
        ).to.not.be.reverted;
        await expect(
            sampleConsumer.connect(addr2).acceptFirewallAdmin()
        ).to.not.be.reverted;
        await expect(
            firewall.connect(addr1).setPolicyStatus(ZERO_ADDRESS, true)
        ).to.be.revertedWith('Ownable: caller is not the owner');
        await firewall.connect(owner).setPolicyStatus(ZERO_ADDRESS, true);
        await expect(
            firewall
                .connect(owner)
                .addPolicy(
                    sampleConsumer.address,
                    ZERO_METHOD_SIG,
                    ZERO_ADDRESS
                )
        ).to.be.revertedWith('Firewall: not consumer admin');
        await expect(
            firewall
                .connect(addr1)
                .removePolicy(
                    sampleConsumer.address,
                    ZERO_METHOD_SIG,
                    ZERO_ADDRESS
                )
        ).to.be.revertedWith('Firewall: not consumer admin');
    });

    it('Firewall adding/removing policies', async function () {
        const AllowlistPolicy = await ethers.getContractFactory(
            'AllowlistPolicy'
        );
        const ApprovedCallsPolicy = await ethers.getContractFactory(
            'ApprovedCallsPolicy'
        );
        const BalanceChangePolicy = await ethers.getContractFactory(
            'BalanceChangePolicy'
        );
        const allowlistPolicy = await AllowlistPolicy.deploy();
        const approvedCallsPolicy =
            await ApprovedCallsPolicy.deploy(firewall.address);
        const balanceChangePolicy = await BalanceChangePolicy.deploy(firewall.address);

        await firewall
            .connect(owner)
            .setPolicyStatus(allowlistPolicy.address, true);
        await firewall
            .connect(owner)
            .setPolicyStatus(approvedCallsPolicy.address, true);
        await firewall
            .connect(owner)
            .setPolicyStatus(balanceChangePolicy.address, true);

        await firewall
            .connect(owner)
            .addPolicy(
                sampleConsumer.address,
                ZERO_METHOD_SIG,
                allowlistPolicy.address
            );
        await firewall
            .connect(owner)
            .addPolicy(
                sampleConsumer.address,
                ZERO_METHOD_SIG,
                approvedCallsPolicy.address
            );
        await firewall
            .connect(owner)
            .addPolicy(
                sampleConsumer.address,
                ZERO_METHOD_SIG,
                balanceChangePolicy.address
            );
        expect(
            await firewall.getActivePolicies(
                sampleConsumer.address,
                ZERO_METHOD_SIG
            )
        ).to.eql([
            allowlistPolicy.address,
            approvedCallsPolicy.address,
            balanceChangePolicy.address,
        ]);
        await expect(
            firewall
                .connect(owner)
                .addPolicy(
                    sampleConsumer.address,
                    ZERO_METHOD_SIG,
                    allowlistPolicy.address
                )
        ).to.be.revertedWith('Firewall: policy already exists');
        await firewall.removePolicy(sampleConsumer.address, ZERO_METHOD_SIG, approvedCallsPolicy.address);
        expect(
            await firewall.getActivePolicies(
                sampleConsumer.address,
                ZERO_METHOD_SIG
            )
        ).to.eql([allowlistPolicy.address, balanceChangePolicy.address]);
    });

});
