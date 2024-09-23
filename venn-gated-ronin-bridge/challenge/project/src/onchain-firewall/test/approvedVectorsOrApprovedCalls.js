const { expect } = require('chai');
const { ethers } = require('hardhat');
const { approveVectors } = require('./utils/utils');

describe('Approved Vectors Or Approved Calls Policy', function () {
    let owner, addr1, addr2;
    let firewall, sampleConsumer, sampleContractUser, sampleConsumerIface;
    let approvedVectorsPolicy, approvedCallsPolicy, combinedPoliciesPolicy;

    beforeEach(async function () {
        [owner, addr1, addr2] = await ethers.getSigners();
        const FirewallFactory = await ethers.getContractFactory('Firewall');
        const SampleConsumerFactory = await ethers.getContractFactory(
            'SampleConsumer'
        );
        const SampleContractUserFactory = await ethers.getContractFactory(
            'SampleContractUser'
        );
        const CombinedPoliciesPolicy = await ethers.getContractFactory(
            'CombinedPoliciesPolicy'
        );
        const ApprovedCallsPolicy = await ethers.getContractFactory(
            'ApprovedCallsPolicy'
        );
        const ApprovedVectorsPolicy = await ethers.getContractFactory(
            'ApprovedVectorsPolicy'
        );
        firewall = await FirewallFactory.deploy();
        sampleContractUser = await SampleContractUserFactory.deploy();
        combinedPoliciesPolicy = await CombinedPoliciesPolicy.deploy(firewall.address);
        await combinedPoliciesPolicy.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes('POLICY_ADMIN_ROLE')), owner.address);

        sampleConsumer = await SampleConsumerFactory.deploy(firewall.address);
        sampleConsumerIface = SampleConsumerFactory.interface;

        approvedCallsPolicy = await ApprovedCallsPolicy.deploy(firewall.address);
        await approvedCallsPolicy.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes('SIGNER_ROLE')), owner.address);
        await approvedCallsPolicy.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes('POLICY_ADMIN_ROLE')), owner.address);
        await approvedCallsPolicy.setExecutorStatus(combinedPoliciesPolicy.address, true);

        approvedVectorsPolicy = await ApprovedVectorsPolicy.deploy(firewall.address);
        await approvedVectorsPolicy.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes('POLICY_ADMIN_ROLE')), owner.address);
        await approvedVectorsPolicy.setConsumersStatuses([sampleConsumer.address], [true]);
        await approvedVectorsPolicy.setExecutorStatus(combinedPoliciesPolicy.address, true);

        await firewall.setPolicyStatus(combinedPoliciesPolicy.address, true);
        await firewall.addGlobalPolicy(
            sampleConsumer.address,
            combinedPoliciesPolicy.address
        );

        await combinedPoliciesPolicy.setConsumersStatuses([sampleConsumer.address], [true]);
        await combinedPoliciesPolicy.setAllowedCombinations(
            [approvedCallsPolicy.address, approvedVectorsPolicy.address],
            [[true, true], [true, false], [false, true]]
        );
    });

    it('gas comparison test', async function () {
        await firewall.removeGlobalPolicy(
            sampleConsumer.address,
            combinedPoliciesPolicy.address
        );
        await sampleConsumer.deposit({ value: ethers.utils.parseEther('1') });
        await sampleConsumer.withdraw(ethers.utils.parseEther('1'));
    });

    it('firewall approved vectors, all length 1 vectors pass, all others fail', async function () {
        await approveVectors(
            [
                [sampleConsumerIface.getSighash('deposit()')],
                [sampleConsumerIface.getSighash('withdraw(uint256)')]
            ],
            approvedVectorsPolicy
        );
        await expect(
            sampleContractUser.connect(addr1).deposit(
                sampleConsumer.address,
                { value: ethers.utils.parseEther("1") }
            )
        ).to.not.be.reverted;
        await expect(
            sampleContractUser.connect(addr1).withdraw(
                sampleConsumer.address,
                ethers.utils.parseEther("1"),
            )
        ).to.not.be.reverted;
        await expect(
            sampleContractUser.connect(addr1).depositAndWithdraw(
                sampleConsumer.address,
                { value: ethers.utils.parseEther("1") }
            )
        ).to.be.revertedWith("CombinedPoliciesPolicy: Disallowed combination");
        await expect(
            sampleContractUser.connect(addr1).depositAndWithdrawAndDeposit(
                sampleConsumer.address,
                { value: ethers.utils.parseEther("1") }
            )
        ).to.be.revertedWith("CombinedPoliciesPolicy: Disallowed combination");
    });

    it('Firewall Approved vectors, only approved vectors pass', async function () {
        const depositAndWithdrawVector = [ sampleConsumerIface.getSighash('deposit()'), sampleConsumerIface.getSighash('withdraw(uint256)') ];
        const depositAndWithdrawAndDepositVector = [
                sampleConsumerIface.getSighash('deposit()'),
                sampleConsumerIface.getSighash('withdraw(uint256)'),
                sampleConsumerIface.getSighash('deposit()'),
        ];
        await approveVectors([depositAndWithdrawVector], approvedVectorsPolicy);
        await expect(
            sampleContractUser.connect(addr1).depositAndWithdraw(
                sampleConsumer.address,
                { value: ethers.utils.parseEther("1") }
            )
        ).to.not.be.reverted;
        await expect(
            sampleContractUser.connect(addr1).depositAndWithdrawAndDeposit(
                sampleConsumer.address,
                { value: ethers.utils.parseEther("1") }
            )
        ).to.be.revertedWith("CombinedPoliciesPolicy: Disallowed combination");
        await approveVectors([depositAndWithdrawAndDepositVector], approvedVectorsPolicy);
        await expect(
            sampleContractUser.connect(addr1).depositAndWithdrawAndDeposit(
                sampleConsumer.address,
                { value: ethers.utils.parseEther("1") }
            )
        ).to.not.be.reverted;
    });


});
