const { expect } = require('chai');
const { ethers } = require('hardhat');
const { approveVectors } = require('./utils/utils');

describe('Approved Vectors Policy', () => {
    let owner, addr1, addr2;
    let firewall, sampleConsumer, sampleContractUser, sampleConsumerIface, approvedVectorsPolicy;

    beforeEach(async () => {
        [owner, addr1, addr2] = await ethers.getSigners();
        const FirewallFactory = await ethers.getContractFactory('Firewall');
        const SampleConsumerFactory = await ethers.getContractFactory(
            'SampleConsumer'
        );
        const SampleContractUserFactory = await ethers.getContractFactory(
            'SampleContractUser'
        );
        const ApprovedVectorsPolicy = await ethers.getContractFactory(
            'ApprovedVectorsPolicy'
        );
        firewall = await FirewallFactory.deploy();
        sampleContractUser = await SampleContractUserFactory.deploy();
        approvedVectorsPolicy = await ApprovedVectorsPolicy.deploy(firewall.address);
        sampleConsumer = await SampleConsumerFactory.deploy(firewall.address);
        sampleConsumerIface = SampleConsumerFactory.interface;
        await approvedVectorsPolicy.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes('POLICY_ADMIN_ROLE')), owner.address);
        await approvedVectorsPolicy.setConsumersStatuses([sampleConsumer.address], [true]);
        await firewall.setPolicyStatus(approvedVectorsPolicy.address, true);
        await firewall.addGlobalPolicy(
            sampleConsumer.address,
            approvedVectorsPolicy.address
        );
    });

    it('gas comparison test', async () => {
        await firewall.removeGlobalPolicy(
            sampleConsumer.address,
            approvedVectorsPolicy.address
        );
        await sampleConsumer.deposit({ value: ethers.utils.parseEther('1') });
        await sampleConsumer.withdraw(ethers.utils.parseEther('1'));
    });

    describe('run', () => {
        it('Firewall Approved vectors, all length 1 vectors pass, all others fail', async () => {
            await approveVectors(
                [
                    [sampleConsumerIface.getSighash('deposit()')],
                    [sampleConsumerIface.getSighash('withdraw(uint256)')]
                ],
                approvedVectorsPolicy
            );
            let tx = sampleContractUser.connect(addr1).deposit(
                    sampleConsumer.address,
                    { value: ethers.utils.parseEther("1") }
                );
            await expect(tx).to.not.be.reverted;
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPreSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPreError');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPostSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPostError');
            tx = sampleContractUser.connect(addr1).withdraw(
                    sampleConsumer.address,
                    ethers.utils.parseEther("1"),
                ); 
            await expect(tx).to.not.be.reverted;
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPreSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPreError');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPostSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPostError');
            tx = sampleContractUser.connect(addr1).depositAndWithdraw(
                    sampleConsumer.address,
                    { value: ethers.utils.parseEther("1") }
                ); 
            await expect(tx).to.be.revertedWith("ApprovedVectorsPolicy: Unapproved Vector");
            tx = sampleContractUser.connect(addr1).depositAndWithdrawAndDeposit(
                    sampleConsumer.address,
                    { value: ethers.utils.parseEther("1") }
                ); 
            await expect(tx).to.be.revertedWith("ApprovedVectorsPolicy: Unapproved Vector");
        });
    
        it('Firewall Approved vectors, only approved vectors pass', async () => {
            const depositAndWithdrawVector = [
                sampleConsumerIface.getSighash('deposit()'), sampleConsumerIface.getSighash('withdraw(uint256)')
            ];
            const depositAndWithdrawAndDepositVector = [
                    sampleConsumerIface.getSighash('deposit()'),
                    sampleConsumerIface.getSighash('withdraw(uint256)'),
                    sampleConsumerIface.getSighash('deposit()'),
            ];
            await approveVectors([depositAndWithdrawVector], approvedVectorsPolicy);
            let tx = sampleContractUser.connect(addr1).depositAndWithdraw(
                    sampleConsumer.address,
                    { value: ethers.utils.parseEther("1") }
                );
            await expect(tx).to.not.be.reverted;
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPreSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPreError');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPostSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPostError');
            tx = sampleContractUser.connect(addr1).depositAndWithdrawAndDeposit(
                    sampleConsumer.address,
                    { value: ethers.utils.parseEther("1") }
                );
            await expect(tx).to.be.revertedWith("ApprovedVectorsPolicy: Unapproved Vector");
            await approveVectors([depositAndWithdrawAndDepositVector], approvedVectorsPolicy);
            tx = sampleContractUser.connect(addr1).depositAndWithdrawAndDeposit(
                    sampleConsumer.address,
                    { value: ethers.utils.parseEther("1") }
                );
            await expect(tx).to.not.be.reverted;
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPreSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPreError');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPostSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPostError');
        });
    });

    describe('dryrun', () => {
        beforeEach(async () => {
            await firewall.setConsumerDryrunStatus(sampleConsumer.address, true);
        });

        it('Firewall Approved vectors, all length 1 vectors pass, all others not fail', async () => {
            await approveVectors(
                [
                    [sampleConsumerIface.getSighash('deposit()')],
                    [sampleConsumerIface.getSighash('withdraw(uint256)')]
                ],
                approvedVectorsPolicy
            );
            let tx = sampleContractUser.connect(addr1).deposit(
                    sampleConsumer.address,
                    { value: ethers.utils.parseEther("1") }
                );
            await expect(tx).to.not.be.reverted;
            await expect(tx).to.emit(firewall, 'DryrunPolicyPreSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPreError');
            await expect(tx).to.emit(firewall, 'DryrunPolicyPostSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPostError');
            tx = sampleContractUser.connect(addr1).withdraw(
                    sampleConsumer.address,
                    ethers.utils.parseEther("1"),
                ); 
            await expect(tx).to.not.be.reverted;
            await expect(tx).to.emit(firewall, 'DryrunPolicyPreSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPreError');
            await expect(tx).to.emit(firewall, 'DryrunPolicyPostSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPostError');
            tx = sampleContractUser.connect(addr1).depositAndWithdraw(
                    sampleConsumer.address,
                    { value: ethers.utils.parseEther("1") }
                ); 
            await expect(tx).to.not.be.reverted;
            await expect(tx).to.emit(firewall, 'DryrunPolicyPreSuccess'); // Emitted by the last withdraw subcall.
            await expect(tx).to.emit(firewall, 'DryrunPolicyPreError');
            await expect(tx).to.emit(firewall, 'DryrunPolicyPostSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPostError');
            tx = sampleContractUser.connect(addr1).depositAndWithdrawAndDeposit(
                    sampleConsumer.address,
                    { value: ethers.utils.parseEther("1") }
                ); 
            await expect(tx).to.not.be.reverted;
            await expect(tx).to.emit(firewall, 'DryrunPolicyPreSuccess'); // Emitted by the last withdraw subcall.
            await expect(tx).to.emit(firewall, 'DryrunPolicyPreError');
            await expect(tx).to.emit(firewall, 'DryrunPolicyPostSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPostError');
        });
    
        it('Firewall Approved vectors, only approved vectors pass', async () => {
            const depositAndWithdrawVector = [
                sampleConsumerIface.getSighash('deposit()'), sampleConsumerIface.getSighash('withdraw(uint256)')
            ];
            const depositAndWithdrawAndDepositVector = [
                    sampleConsumerIface.getSighash('deposit()'),
                    sampleConsumerIface.getSighash('withdraw(uint256)'),
                    sampleConsumerIface.getSighash('deposit()'),
            ];
            await approveVectors([depositAndWithdrawVector], approvedVectorsPolicy);
            let tx = sampleContractUser.connect(addr1).depositAndWithdraw(
                    sampleConsumer.address,
                    { value: ethers.utils.parseEther("1") }
                );
            await expect(tx).to.not.be.reverted;
            await expect(tx).to.emit(firewall, 'DryrunPolicyPreSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPreError');
            await expect(tx).to.emit(firewall, 'DryrunPolicyPostSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPostError');
            tx = sampleContractUser.connect(addr1).depositAndWithdrawAndDeposit(
                    sampleConsumer.address,
                    { value: ethers.utils.parseEther("1") }
                );
            await expect(tx).to.not.be.reverted;
            await expect(tx).to.emit(firewall, 'DryrunPolicyPreSuccess'); // Emitted by the last deposit subcall.
            await expect(tx).to.emit(firewall, 'DryrunPolicyPreError');
            await expect(tx).to.emit(firewall, 'DryrunPolicyPostSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPostError');
            await approveVectors([depositAndWithdrawAndDepositVector], approvedVectorsPolicy);
            tx = sampleContractUser.connect(addr1).depositAndWithdrawAndDeposit(
                    sampleConsumer.address,
                    { value: ethers.utils.parseEther("1") }
                );
            await expect(tx).to.not.be.reverted;
            await expect(tx).to.emit(firewall, 'DryrunPolicyPreSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPreError');
            await expect(tx).to.emit(firewall, 'DryrunPolicyPostSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPostError');
        });
    });
});
