const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('Allowlist Policy', function () {
    let owner, addr2;
    let firewall, sampleConsumer, sampleConsumerIface;

    beforeEach(async function () {
        [owner, addr2] = await ethers.getSigners();
        const FirewallFactory = await ethers.getContractFactory('Firewall');
        const SampleConsumerFactory = await ethers.getContractFactory(
            'SampleConsumer'
        );
        firewall = await FirewallFactory.deploy();
        sampleConsumer = await SampleConsumerFactory.deploy(firewall.address);
        sampleConsumerIface = SampleConsumerFactory.interface;
    });

    it('Firewall allowlist', async function () {
        const AllowlistPolicy = await ethers.getContractFactory(
            'AllowlistPolicy'
        );
        const allowlistPolicy = await AllowlistPolicy.deploy();
        await allowlistPolicy.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes('POLICY_ADMIN_ROLE')), owner.address);
        await firewall.setPolicyStatus(allowlistPolicy.address, true);
        await firewall.addPolicy(
            sampleConsumer.address,
            sampleConsumerIface.getSighash('deposit()'),
            allowlistPolicy.address
        );
        await expect(
            allowlistPolicy
                .connect(addr2)
                .setConsumerAllowlist(
                    sampleConsumer.address,
                    [owner.address],
                    true
                )
        ).to.be.revertedWith(`AccessControl: account ${addr2.address.toLowerCase()} is missing role 0xace7350211ab645c1937904136ede4855ac3aa1eabb4970e1a51a335d2e19920`);
        await allowlistPolicy.setConsumerAllowlist(
            sampleConsumer.address,
            [owner.address],
            true
        );
        await expect(
            sampleConsumer
                .connect(addr2)
                .deposit({ value: ethers.utils.parseEther('1') })
        ).to.be.revertedWith('AllowlistPolicy: Sender not allowed');
        await expect(
            sampleConsumer
                .connect(owner)
                .deposit({ value: ethers.utils.parseEther('1') })
        ).to.not.be.reverted;
    });

    describe('dryrun', () => {
        beforeEach(async () => {
            await firewall.setConsumerDryrunStatus(sampleConsumer.address, true);
        });

        it('Firewall allowlist', async function () {
            const AllowlistPolicy = await ethers.getContractFactory(
                'AllowlistPolicy'
            );
            const allowlistPolicy = await AllowlistPolicy.deploy();
            await allowlistPolicy.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes('POLICY_ADMIN_ROLE')), owner.address);
            await firewall.setPolicyStatus(allowlistPolicy.address, true);
            await firewall.addPolicy(
                sampleConsumer.address,
                sampleConsumerIface.getSighash('deposit()'),
                allowlistPolicy.address
            );
            let tx = allowlistPolicy
                    .connect(addr2)
                    .setConsumerAllowlist(
                        sampleConsumer.address,
                        [owner.address],
                        true
                    );
            await expect(tx).to.be.revertedWith(`AccessControl: account ${addr2.address.toLowerCase()} is missing role 0xace7350211ab645c1937904136ede4855ac3aa1eabb4970e1a51a335d2e19920`);
            await allowlistPolicy.setConsumerAllowlist(
                sampleConsumer.address,
                [owner.address],
                true
            );
            tx = sampleConsumer
                    .connect(addr2)
                    .deposit({ value: ethers.utils.parseEther('1') });
            await expect(tx).to.not.be.reverted;
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPreSuccess');
            await expect(tx).to.emit(firewall, 'DryrunPolicyPreError');
            await expect(tx).to.emit(firewall, 'DryrunPolicyPostSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPostError');
            tx = sampleConsumer
                    .connect(owner)
                    .deposit({ value: ethers.utils.parseEther('1') });
            await expect(tx).to.not.be.reverted;
            await expect(tx).to.emit(firewall, 'DryrunPolicyPreSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPreError');
            await expect(tx).to.emit(firewall, 'DryrunPolicyPostSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPostError');
        });
    });
});
