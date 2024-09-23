const { expect } = require('chai');
const { ethers } = require('hardhat');
const { approveVectors } = require('./utils/utils');

const ETH_ADDRESS = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';

describe('Combined Policies Policy', function () {
    let owner, addr1, addr2;
    let firewall, sampleConsumer, sampleConsumerInternals, sampleConsumerInternalsIface, sampleConsumerIface,
        combinedPoliciesPolicy, balanceChangePolicy, allowlistPolicy, forbiddenMethodsPolicy, approvedVectorsPolicy;

    beforeEach(async function () {
        [owner, addr1, addr2] = await ethers.getSigners();
        const FirewallFactory = await ethers.getContractFactory('Firewall');
        const SampleConsumerFactory = await ethers.getContractFactory(
            'SampleConsumer'
        );
        const SampleConsumerInternalsFactory = await ethers.getContractFactory(
            'SampleConsumerInternals'
        );
        const CombinedPoliciesPolicy = await ethers.getContractFactory(
            'CombinedPoliciesPolicy'
        );
        const BalanceChangePolicy = await ethers.getContractFactory(
            'BalanceChangePolicy'
        );
        const AllowlistPolicy = await ethers.getContractFactory(
            'AllowlistPolicy'
        );
        const ForbiddenMethodsPolicy = await ethers.getContractFactory(
            'ForbiddenMethodsPolicy'
        );
        const ApprovedVectorsPolicy = await ethers.getContractFactory(
            'ApprovedVectorsPolicy'
        );
        firewall = await FirewallFactory.deploy();
        sampleConsumer = await SampleConsumerFactory.deploy(firewall.address);
        sampleConsumerInternals = await SampleConsumerInternalsFactory.deploy(firewall.address);
        sampleConsumerIface = SampleConsumerFactory.interface;
        sampleConsumerInternalsIface = SampleConsumerInternalsFactory.interface;
        combinedPoliciesPolicy = await CombinedPoliciesPolicy.deploy(firewall.address);
        balanceChangePolicy = await BalanceChangePolicy.deploy(firewall.address);
        allowlistPolicy = await AllowlistPolicy.deploy();
        forbiddenMethodsPolicy = await ForbiddenMethodsPolicy.deploy();
        approvedVectorsPolicy = await ApprovedVectorsPolicy.deploy(firewall.address);

        await combinedPoliciesPolicy.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes('POLICY_ADMIN_ROLE')), owner.address);
        await approvedVectorsPolicy.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes('POLICY_ADMIN_ROLE')), owner.address);
        await forbiddenMethodsPolicy.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes('POLICY_ADMIN_ROLE')), owner.address);
        await balanceChangePolicy.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes('POLICY_ADMIN_ROLE')), owner.address);
        await allowlistPolicy.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes('POLICY_ADMIN_ROLE')), owner.address);

        await balanceChangePolicy.setExecutorStatus(combinedPoliciesPolicy.address, true);
        await approvedVectorsPolicy.setExecutorStatus(combinedPoliciesPolicy.address, true);

        await combinedPoliciesPolicy.setConsumersStatuses([sampleConsumer.address, sampleConsumerInternals.address], [true, true]);
        await approvedVectorsPolicy.setConsumersStatuses([sampleConsumer.address, sampleConsumerInternals.address], [true, true]);
        await balanceChangePolicy.setConsumersStatuses([sampleConsumer.address, sampleConsumerInternals.address], [true, true]);

        await firewall.setPolicyStatus(combinedPoliciesPolicy.address, true);
        await firewall.addGlobalPolicy(sampleConsumer.address, combinedPoliciesPolicy.address);
        await firewall.addGlobalPolicy(sampleConsumerInternals.address, combinedPoliciesPolicy.address);
    });

    it('Combined Policies balance change or allowlist with internals', async function () {
        await balanceChangePolicy.setConsumerMaxBalanceChange(
            sampleConsumerInternals.address,
            ETH_ADDRESS,
            ethers.utils.parseEther('1')
        );
        await allowlistPolicy.setConsumerAllowlist(
            sampleConsumerInternals.address,
            [addr1.address],
            true,
        );
        await combinedPoliciesPolicy.setAllowedCombinations(
            [balanceChangePolicy.address, allowlistPolicy.address],
            [[true, true], [true, false], [false, true]]
        );
        await expect(
            sampleConsumerInternals
                .connect(addr2)
                .deposit({ value: ethers.utils.parseEther('1.000001') })
        ).to.be.revertedWith(
            'CombinedPoliciesPolicy: Disallowed combination'
        );
        await expect(
            sampleConsumerInternals
                .connect(addr1)
                .deposit({ value: ethers.utils.parseEther('1') })
        ).to.not.be.reverted;
        await expect(
            sampleConsumerInternals
                .connect(addr2)
                .deposit({ value: ethers.utils.parseEther('1') })
        ).to.not.be.reverted;
        await expect(
            sampleConsumerInternals
                .connect(addr1)
                .deposit({ value: ethers.utils.parseEther('1.000001') })
        ).to.not.be.reverted;
    });

    it('Combined Policies balance change or allowlist', async function () {
        await balanceChangePolicy.setConsumerMaxBalanceChange(
            sampleConsumer.address,
            ETH_ADDRESS,
            ethers.utils.parseEther('1')
        );
        await allowlistPolicy.setConsumerAllowlist(
            sampleConsumer.address,
            [addr1.address],
            true,
        );
        await combinedPoliciesPolicy.setAllowedCombinations(
            [balanceChangePolicy.address, allowlistPolicy.address],
            [[true, true], [true, false], [false, true]]
        );
        await expect(
            sampleConsumer
                .connect(addr2)
                .deposit({ value: ethers.utils.parseEther('1.000001') })
        ).to.be.revertedWith(
            'CombinedPoliciesPolicy: Disallowed combination'
        );
        await expect(
            sampleConsumer
                .connect(addr1)
                .deposit({ value: ethers.utils.parseEther('1') })
        ).to.not.be.reverted;
        await expect(
            sampleConsumer
                .connect(addr2)
                .deposit({ value: ethers.utils.parseEther('1') })
        ).to.not.be.reverted;
        await expect(
            sampleConsumer
                .connect(addr1)
                .deposit({ value: ethers.utils.parseEther('1.000001') })
        ).to.not.be.reverted;
    });

    it('Combined Policies approved vector or forbidden policy', async function () {
        const withdrawManySighash = sampleConsumerInternalsIface.getSighash('withdrawMany(uint256,uint256)');
        const withdrawSighash = sampleConsumerInternalsIface.getSighash('withdraw(uint256)');
        const withdrawInternalSighash = '0xac6a2b5d';
        await forbiddenMethodsPolicy.setConsumerForbiddenMethod(
            sampleConsumerInternals.address,
            sampleConsumerInternalsIface.getSighash('withdrawMany(uint256,uint256)'),
            true,
        );
        const approvedVectors = [
            [withdrawManySighash, withdrawInternalSighash, withdrawInternalSighash],
            [withdrawSighash, withdrawInternalSighash],
        ];
        await approveVectors(approvedVectors, approvedVectorsPolicy);
        await combinedPoliciesPolicy.setAllowedCombinations(
            [forbiddenMethodsPolicy.address, approvedVectorsPolicy.address],
            [[true, true], [true, false], [false, true]]
        );
        await expect(
            sampleConsumerInternals
                .connect(addr1)
                .deposit({ value: ethers.utils.parseEther('1.000001') })
        ).to.not.be.reverted;
        await expect(
            sampleConsumerInternals
                .connect(addr1)
                .withdraw(ethers.utils.parseEther('1'))
        ).to.not.be.reverted;
        await expect(
            sampleConsumerInternals
                .connect(addr2)
                .deposit({ value: ethers.utils.parseEther('100') })
        ).to.not.be.reverted;
        await expect(
            sampleConsumerInternals
                .connect(addr2)
                .withdrawMany(ethers.utils.parseEther('1'), 1)
        ).to.not.be.reverted;
        await expect(
            sampleConsumerInternals
                .connect(addr2)
                .withdrawMany(ethers.utils.parseEther('1'), 2)
        ).to.not.be.reverted;
        await expect(
            sampleConsumerInternals
                .connect(addr2)
                .withdrawMany(ethers.utils.parseEther('1'), 3)
        ).to.be.revertedWith(
            'CombinedPoliciesPolicy: Disallowed combination'
        );
    });
});
