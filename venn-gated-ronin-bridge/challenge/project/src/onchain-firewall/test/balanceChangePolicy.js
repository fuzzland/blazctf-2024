const { expect } = require('chai');
const { ethers } = require('hardhat');

const ETH_ADDRESS = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';

describe('Balance Change Policy', () => {
    let owner, addr1, addr2;
    let firewall, sampleConsumer, sampleConsumerIface, balanceChangePolicy, testToken;

    beforeEach(async () => {
        [owner, addr1, addr2] = await ethers.getSigners();
        const FirewallFactory = await ethers.getContractFactory('Firewall');
        const SampleConsumerFactory = await ethers.getContractFactory(
            'SampleConsumer'
        );
        const BalanceChangePolicy = await ethers.getContractFactory(
            'BalanceChangePolicy'
        );
        const SampleToken = await ethers.getContractFactory('SampleToken');

        firewall = await FirewallFactory.deploy();
        testToken = await SampleToken.deploy();
        balanceChangePolicy = await BalanceChangePolicy.deploy(firewall.address);
        sampleConsumer = await SampleConsumerFactory.deploy(firewall.address);
        sampleConsumerIface = SampleConsumerFactory.interface;

        await balanceChangePolicy.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes('POLICY_ADMIN_ROLE')), owner.address);
        await balanceChangePolicy.setConsumersStatuses([sampleConsumer.address], [true]);
        await firewall.setPolicyStatus(balanceChangePolicy.address, true);
        await firewall.addGlobalPolicy(sampleConsumer.address, balanceChangePolicy.address);
        await testToken.transfer(addr1.address, ethers.utils.parseEther('100'));
        await testToken.connect(addr1).approve(sampleConsumer.address, ethers.utils.parseEther('100'));
    });

    it('Firewall Balance Change policy managing tokens', async () => {
        let consumerTokens;
        await balanceChangePolicy.setConsumerMaxBalanceChange(
            sampleConsumer.address,
            ETH_ADDRESS,
            ethers.utils.parseEther('1'),
        );
        consumerTokens = await balanceChangePolicy.getConsumerTokens(sampleConsumer.address);
        expect(consumerTokens).to.eql([ETH_ADDRESS]);
        await balanceChangePolicy.setConsumerMaxBalanceChange(
            sampleConsumer.address,
            ETH_ADDRESS,
            ethers.utils.parseEther('2'),
        );
        consumerTokens = await balanceChangePolicy.getConsumerTokens(sampleConsumer.address);
        expect(consumerTokens).to.eql([ETH_ADDRESS]);
        await balanceChangePolicy.removeToken(
            sampleConsumer.address,
            ETH_ADDRESS,
        );
        consumerTokens = await balanceChangePolicy.getConsumerTokens(sampleConsumer.address);
        expect(consumerTokens).to.eql([]);
        await balanceChangePolicy.setConsumerMaxBalanceChange(
            sampleConsumer.address,
            ETH_ADDRESS,
            ethers.utils.parseEther('1'),
        );
        consumerTokens = await balanceChangePolicy.getConsumerTokens(sampleConsumer.address);
        expect(consumerTokens).to.eql([ETH_ADDRESS]);
        await balanceChangePolicy.setConsumerMaxBalanceChange(
            sampleConsumer.address,
            testToken.address,
            ethers.utils.parseEther('2'),
        );
        consumerTokens = await balanceChangePolicy.getConsumerTokens(sampleConsumer.address);
        expect(consumerTokens).to.eql([ETH_ADDRESS, testToken.address]);
        await balanceChangePolicy.setConsumerMaxBalanceChange(
            sampleConsumer.address,
            addr2.address,
            ethers.utils.parseEther('2'),
        );
        consumerTokens = await balanceChangePolicy.getConsumerTokens(sampleConsumer.address);
        expect(consumerTokens).to.eql([ETH_ADDRESS, testToken.address, addr2.address]);
        await balanceChangePolicy.removeToken(
            sampleConsumer.address,
            testToken.address,
        );
        consumerTokens = await balanceChangePolicy.getConsumerTokens(sampleConsumer.address);
        expect(consumerTokens).to.eql([ETH_ADDRESS, addr2.address]);
        await balanceChangePolicy.setConsumerMaxBalanceChange(
            sampleConsumer.address,
            testToken.address,
            ethers.utils.parseEther('1'),
        );
        consumerTokens = await balanceChangePolicy.getConsumerTokens(sampleConsumer.address);
        expect(consumerTokens).to.eql([ETH_ADDRESS, addr2.address, testToken.address]);
        await balanceChangePolicy.removeToken(
            sampleConsumer.address,
            testToken.address,
        );
        consumerTokens = await balanceChangePolicy.getConsumerTokens(sampleConsumer.address);
        expect(consumerTokens).to.eql([ETH_ADDRESS, addr2.address]);
    });

    describe('run', () => {
        it('Firewall Balance Change policy unapproved call above limit fails (eth)', async () => {
            await balanceChangePolicy.setConsumerMaxBalanceChange(
                sampleConsumer.address,
                ETH_ADDRESS,
                ethers.utils.parseEther('1'),
            );
            const tx = sampleConsumer
                    .connect(addr2)
                    .deposit({ value: ethers.utils.parseEther('1.01') });
            await expect(tx).to.be.revertedWith('BalanceChangePolicy: Balance change exceeds limit');
        });
    
        it('Firewall Balance Change policy unapproved call above limit fails (token)', async () => {
            await balanceChangePolicy.setConsumerMaxBalanceChange(
                sampleConsumer.address,
                testToken.address,
                ethers.utils.parseEther('1'),
            );
            const tx = sampleConsumer
                    .connect(addr1)
                    .depositToken(testToken.address, ethers.utils.parseEther('1.01'));
            await expect(tx).to.be.revertedWith('BalanceChangePolicy: Balance change exceeds limit');
        });
    
        it('Firewall Balance Change Or Approved calls with signature policy unapproved call above limit fails (token+eth)', async () => {
            await balanceChangePolicy.setConsumerMaxBalanceChange(
                sampleConsumer.address,
                testToken.address,
                ethers.utils.parseEther('1'),
            );
            await balanceChangePolicy.setConsumerMaxBalanceChange(
                sampleConsumer.address,
                ETH_ADDRESS,
                ethers.utils.parseEther('1'),
            );
            let tx = sampleConsumer
                    .connect(addr2)
                    .deposit({ value: ethers.utils.parseEther('1.01') });
            await expect(tx).to.be.revertedWith('BalanceChangePolicy: Balance change exceeds limit');
            tx = sampleConsumer
                    .connect(addr1)
                    .depositToken(testToken.address, ethers.utils.parseEther('1.01'));
            await expect(tx).to.be.revertedWith('BalanceChangePolicy: Balance change exceeds limit');
        });
    
        it('Firewall Balance Change policy unapproved call below limit passes (eth)', async () => {
            await balanceChangePolicy.setConsumerMaxBalanceChange(
                sampleConsumer.address,
                ETH_ADDRESS,
                ethers.utils.parseEther('1'),
            );
            const tx = sampleConsumer
                    .connect(addr2)
                    .deposit({ value: ethers.utils.parseEther('1') });
            await expect(tx).to.not.be.reverted;
        });
    
        it('Firewall Balance Change policy unapproved call below limit passes (token)', async () => {
            await balanceChangePolicy.setConsumerMaxBalanceChange(
                sampleConsumer.address,
                testToken.address,
                ethers.utils.parseEther('1'),
            );
            const tx = sampleConsumer
                    .connect(addr1)
                    .depositToken(testToken.address, ethers.utils.parseEther('1'));
            await expect(tx).to.not.be.reverted;
        });
    
        it('Firewall Balance Change policy unapproved call below limit passes (eth+token)', async () => {
            await balanceChangePolicy.setConsumerMaxBalanceChange(
                sampleConsumer.address,
                ETH_ADDRESS,
                ethers.utils.parseEther('1'),
            );
            await balanceChangePolicy.setConsumerMaxBalanceChange(
                sampleConsumer.address,
                testToken.address,
                ethers.utils.parseEther('1'),
            );
            let tx = sampleConsumer
                    .connect(addr1)
                    .depositToken(testToken.address, ethers.utils.parseEther('1'));
            await expect(tx).to.not.be.reverted;
            tx = sampleConsumer
                    .connect(addr1)
                    .deposit({ value: ethers.utils.parseEther('1') });
            await expect(tx).to.not.be.reverted;
        });
    });

    describe('dryrun', () => {
        beforeEach(async () => {
            await firewall.setConsumerDryrunStatus(sampleConsumer.address, true);
        });

        it('Firewall Balance Change policy unapproved call above limit not fails (eth)', async () => {
            await balanceChangePolicy.setConsumerMaxBalanceChange(
                sampleConsumer.address,
                ETH_ADDRESS,
                ethers.utils.parseEther('1'),
            );
            const tx = sampleConsumer
                    .connect(addr2)
                    .deposit({ value: ethers.utils.parseEther('1.01') });
            await expect(tx).to.not.be.reverted;
            await expect(tx).to.emit(firewall, 'DryrunPolicyPreSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPreError');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPostSuccess');
            await expect(tx).to.emit(firewall, 'DryrunPolicyPostError');
        });
    
        it('Firewall Balance Change policy unapproved call above limit not fails (token)', async () => {
            await balanceChangePolicy.setConsumerMaxBalanceChange(
                sampleConsumer.address,
                testToken.address,
                ethers.utils.parseEther('1'),
            );
            const tx = sampleConsumer
                    .connect(addr1)
                    .depositToken(testToken.address, ethers.utils.parseEther('1.01'));
            await expect(tx).to.not.be.reverted;
            await expect(tx).to.emit(firewall, 'DryrunPolicyPreSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPreError');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPostSuccess');
            await expect(tx).to.emit(firewall, 'DryrunPolicyPostError');
        });
    
        it('Firewall Balance Change Or Approved calls with signature policy unapproved call above limit not fails (token+eth)', async () => {
            await balanceChangePolicy.setConsumerMaxBalanceChange(
                sampleConsumer.address,
                testToken.address,
                ethers.utils.parseEther('1'),
            );
            await balanceChangePolicy.setConsumerMaxBalanceChange(
                sampleConsumer.address,
                ETH_ADDRESS,
                ethers.utils.parseEther('1'),
            );
            let tx = sampleConsumer
                    .connect(addr2)
                    .deposit({ value: ethers.utils.parseEther('1.01') });
            await expect(tx).to.not.be.reverted;
            await expect(tx).to.emit(firewall, 'DryrunPolicyPreSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPreError');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPostSuccess');
            await expect(tx).to.emit(firewall, 'DryrunPolicyPostError');
            tx = sampleConsumer
                    .connect(addr1)
                    .depositToken(testToken.address, ethers.utils.parseEther('1.01'));
            await expect(tx).to.not.be.reverted;
            await expect(tx).to.emit(firewall, 'DryrunPolicyPreSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPreError');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPostSuccess');
            await expect(tx).to.emit(firewall, 'DryrunPolicyPostError');
        });
    
        it('Firewall Balance Change policy unapproved call below limit passes (eth)', async () => {
            await balanceChangePolicy.setConsumerMaxBalanceChange(
                sampleConsumer.address,
                ETH_ADDRESS,
                ethers.utils.parseEther('1')
            );
            const tx = sampleConsumer
                    .connect(addr2)
                    .deposit({ value: ethers.utils.parseEther('1') });
            await expect(tx).to.not.be.reverted;
            await expect(tx).to.emit(firewall, 'DryrunPolicyPreSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPreError');
            await expect(tx).to.emit(firewall, 'DryrunPolicyPostSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPostError');
        });
    
        it('Firewall Balance Change policy unapproved call below limit passes (token)', async () => {
            await balanceChangePolicy.setConsumerMaxBalanceChange(
                sampleConsumer.address,
                testToken.address,
                ethers.utils.parseEther('1')
            );
            const tx = sampleConsumer
                    .connect(addr1)
                    .depositToken(testToken.address, ethers.utils.parseEther('1'));
            await expect(tx).to.not.be.reverted;
            await expect(tx).to.emit(firewall, 'DryrunPolicyPreSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPreError');
            await expect(tx).to.emit(firewall, 'DryrunPolicyPostSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPostError');
        });
    
        it('Firewall Balance Change policy unapproved call below limit passes (eth+token)', async () => {
            await balanceChangePolicy.setConsumerMaxBalanceChange(
                sampleConsumer.address,
                ETH_ADDRESS,
                ethers.utils.parseEther('1')
            );
            await balanceChangePolicy.setConsumerMaxBalanceChange(
                sampleConsumer.address,
                testToken.address,
                ethers.utils.parseEther('1')
            );
            let tx = sampleConsumer
                    .connect(addr1)
                    .depositToken(testToken.address, ethers.utils.parseEther('1'));
            await expect(tx).to.not.be.reverted;
            await expect(tx).to.emit(firewall, 'DryrunPolicyPreSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPreError');
            await expect(tx).to.emit(firewall, 'DryrunPolicyPostSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPostError');
            tx = sampleConsumer
                    .connect(addr1)
                    .deposit({ value: ethers.utils.parseEther('1') });
            await expect(tx).to.not.be.reverted;
            await expect(tx).to.emit(firewall, 'DryrunPolicyPreSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPreError');
            await expect(tx).to.emit(firewall, 'DryrunPolicyPostSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPostError');
        });
    });
});
