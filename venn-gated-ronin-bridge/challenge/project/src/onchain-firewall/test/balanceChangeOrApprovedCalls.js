const { expect } = require('chai');
const { ethers } = require('hardhat');

const ETH_ADDRESS = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';

describe('Balance Change Or Approved Calls Policy (CPP)', function () {
    let owner, addr1, addr2;
    let firewall, sampleConsumer, sampleConsumerIface, combinedPoliciesPolicy, balanceChangePolicy, approvedCallsPolicy, testToken;

    beforeEach(async function () {
        [owner, addr1, addr2] = await ethers.getSigners();
        const FirewallFactory = await ethers.getContractFactory('Firewall');
        const SampleConsumerFactory = await ethers.getContractFactory(
            'SampleConsumer'
        );
        const CombinedPoliciesPolicy = await ethers.getContractFactory(
            'CombinedPoliciesPolicy'
        );
        const BalanceChangePolicy = await ethers.getContractFactory(
            'BalanceChangePolicy'
        );
        const ApprovedCallsPolicy = await ethers.getContractFactory(
            'ApprovedCallsPolicy'
        );
        const SampleToken = await ethers.getContractFactory('SampleToken');
        firewall = await FirewallFactory.deploy();
        testToken = await SampleToken.deploy();
        sampleConsumer = await SampleConsumerFactory.deploy(firewall.address);
        sampleConsumerIface = SampleConsumerFactory.interface;

        combinedPoliciesPolicy = await CombinedPoliciesPolicy.deploy(firewall.address);
        balanceChangePolicy = await BalanceChangePolicy.deploy(firewall.address);
        approvedCallsPolicy = await ApprovedCallsPolicy.deploy(firewall.address);

        await combinedPoliciesPolicy.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes('POLICY_ADMIN_ROLE')), owner.address);
        await balanceChangePolicy.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes('POLICY_ADMIN_ROLE')), owner.address);
        await approvedCallsPolicy.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes('POLICY_ADMIN_ROLE')), owner.address);

        await balanceChangePolicy.setConsumersStatuses([sampleConsumer.address], [true]);
        await balanceChangePolicy.setExecutorStatus(combinedPoliciesPolicy.address, true);

        await approvedCallsPolicy.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes('SIGNER_ROLE')), owner.address);
        await approvedCallsPolicy.setExecutorStatus(combinedPoliciesPolicy.address, true);
        await approvedCallsPolicy.setConsumersStatuses([sampleConsumer.address], [true]);

        await combinedPoliciesPolicy.setConsumersStatuses([sampleConsumer.address], [true]);
        await combinedPoliciesPolicy.setAllowedCombinations(
            [balanceChangePolicy.address, approvedCallsPolicy.address],
            [[true, true], [true, false], [false, true]]
        );

        await firewall.setPolicyStatus(combinedPoliciesPolicy.address, true);
        await firewall.addGlobalPolicy(sampleConsumer.address, combinedPoliciesPolicy.address);
        await testToken.transfer(addr1.address, ethers.utils.parseEther('100'));
        await testToken.connect(addr1).approve(sampleConsumer.address, ethers.utils.parseEther('100'));
    });

    it('Firewall Balance Change Or Approved calls with signature policy only signer functions', async function () {
        await expect(
            approvedCallsPolicy.connect(addr1).approveCalls(
                [`0x${'00'.repeat(32)}`],
                0,
                addr2.address,
            )
        ).to.be.revertedWith(`AccessControl: account ${addr1.address.toLowerCase()} is missing role 0xe2f4eaae4a9751e85a3e4a7b9587827a877f29914755229b07a7b2da98285f70`);
    });

    it('Firewall Balance Change Or Approved calls with signature policy managing tokens', async function () {
        let consumerTokens;
        await balanceChangePolicy.setConsumerMaxBalanceChange(
            sampleConsumer.address,
            ETH_ADDRESS,
            ethers.utils.parseEther('1')
        );
        consumerTokens = await balanceChangePolicy.getConsumerTokens(sampleConsumer.address);
        expect(consumerTokens).to.eql([ETH_ADDRESS]);
        await balanceChangePolicy.setConsumerMaxBalanceChange(
            sampleConsumer.address,
            ETH_ADDRESS,
            ethers.utils.parseEther('2')
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
            ethers.utils.parseEther('1')
        );
        consumerTokens = await balanceChangePolicy.getConsumerTokens(sampleConsumer.address);
        expect(consumerTokens).to.eql([ETH_ADDRESS]);
        await balanceChangePolicy.setConsumerMaxBalanceChange(
            sampleConsumer.address,
            testToken.address,
            ethers.utils.parseEther('2')
        );
        consumerTokens = await balanceChangePolicy.getConsumerTokens(sampleConsumer.address);
        expect(consumerTokens).to.eql([ETH_ADDRESS, testToken.address]);
        await balanceChangePolicy.setConsumerMaxBalanceChange(
            sampleConsumer.address,
            addr2.address,
            ethers.utils.parseEther('2')
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
            ethers.utils.parseEther('1')
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

    it('Firewall Balance Change Or Approved calls with signature policy unapproved call above limit fails (eth)', async function () {
        await balanceChangePolicy.setConsumerMaxBalanceChange(
            sampleConsumer.address,
            ETH_ADDRESS,
            ethers.utils.parseEther('1')
        );
        await expect(
            sampleConsumer
                .connect(addr2)
                .deposit({ value: ethers.utils.parseEther('1.01') })
        ).to.be.revertedWith('CombinedPoliciesPolicy: Disallowed combination');
    });

    it('Firewall Balance Change Or Approved calls with signature policy unapproved call above limit fails (token)', async function () {
        await balanceChangePolicy.setConsumerMaxBalanceChange(
            sampleConsumer.address,
            testToken.address,
            ethers.utils.parseEther('1')
        );
        await expect(
            sampleConsumer
                .connect(addr1)
                .depositToken(testToken.address, ethers.utils.parseEther('1.01'))
        ).to.be.revertedWith('CombinedPoliciesPolicy: Disallowed combination');
    });

    it('Firewall Balance Change Or Approved calls with signature policy unapproved call above limit fails (token+eth)', async function () {
        await balanceChangePolicy.setConsumerMaxBalanceChange(
            sampleConsumer.address,
            testToken.address,
            ethers.utils.parseEther('1')
        );
        await balanceChangePolicy.setConsumerMaxBalanceChange(
            sampleConsumer.address,
            ETH_ADDRESS,
            ethers.utils.parseEther('1')
        );
        await expect(
            sampleConsumer
                .connect(addr2)
                .deposit({ value: ethers.utils.parseEther('1.01') })
        ).to.be.revertedWith('CombinedPoliciesPolicy: Disallowed combination');
        await expect(
            sampleConsumer
                .connect(addr1)
                .depositToken(testToken.address, ethers.utils.parseEther('1.01'))
        ).to.be.revertedWith('CombinedPoliciesPolicy: Disallowed combination');
    });

    it('Firewall Balance Change Or Approved calls with signature policy unapproved call below limit passes (eth)', async function () {
        await balanceChangePolicy.setConsumerMaxBalanceChange(
            sampleConsumer.address,
            ETH_ADDRESS,
            ethers.utils.parseEther('1')
        );
        await expect(
            sampleConsumer
                .connect(addr2)
                .deposit({ value: ethers.utils.parseEther('1') })
        ).to.not.be.reverted;
    });

    it('Firewall Balance Change Or Approved calls with signature policy unapproved call below limit passes (token)', async function () {
        await balanceChangePolicy.setConsumerMaxBalanceChange(
            sampleConsumer.address,
            testToken.address,
            ethers.utils.parseEther('1')
        );
        await expect(
            sampleConsumer
                .connect(addr1)
                .depositToken(testToken.address, ethers.utils.parseEther('1'))
        ).to.not.be.reverted;
    });

    it('Firewall Balance Change Or Approved calls with signature policy unapproved call below limit passes (eth+token)', async function () {
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
        await expect(
            sampleConsumer
                .connect(addr1)
                .depositToken(testToken.address, ethers.utils.parseEther('1'))
        ).to.not.be.reverted;
        await expect(
            sampleConsumer
                .connect(addr1)
                .deposit({ value: ethers.utils.parseEther('1') })
        ).to.not.be.reverted;
    });

    it('Firewall Approved calls with signature policy approved calls', async function () {
        await balanceChangePolicy.setConsumerMaxBalanceChange(
            sampleConsumer.address,
            ETH_ADDRESS,
            ethers.utils.parseEther('0.99')
        );
        const SampleContractUser = await ethers.getContractFactory(
            'SampleContractUser'
        );
        const sampleContractUser = await SampleContractUser.deploy();

        const depositPayload = sampleConsumerIface.encodeFunctionData('deposit()');
        const withdrawPayload = sampleConsumerIface.encodeFunctionData('withdraw(uint256)', [ethers.utils.parseEther('1')]);

        const depositCallHash = ethers.utils.solidityKeccak256(
            ['address', 'address', 'address', 'bytes', 'uint256'],
            [
                sampleConsumer.address,
                sampleContractUser.address,
                addr1.address,
                depositPayload,
                ethers.utils.parseEther('1'),
            ]
        );
        const withdrawCallHash = ethers.utils.solidityKeccak256(
            ['address', 'address', 'address', 'bytes', 'uint256'],
            [
                sampleConsumer.address,
                sampleContractUser.address,
                addr1.address,
                withdrawPayload,
                ethers.utils.parseEther('0'),
            ]
        );
        const packed = ethers.utils.solidityPack(
            ['bytes32[]', 'uint256', 'address', 'uint256', 'address', 'uint256'],
            [
                [withdrawCallHash, depositCallHash],
                ethers.utils.parseEther('1'), // expiration, yuge numba
                addr1.address,
                0,
                approvedCallsPolicy.address,
                31337, // hardhat chainid
            ]
        );
        const messageHash = ethers.utils.solidityKeccak256(
            ['bytes'], [packed]
        );
        const messageHashBytes = ethers.utils.arrayify(messageHash)
        const signature = await owner.signMessage(messageHashBytes);
        // We pass the calls in reverse order because the bundle policy pops the last element
        await approvedCallsPolicy.approveCallsViaSignature(
            [withdrawCallHash, depositCallHash],
            ethers.utils.parseEther('1'),
            addr1.address,
            0,
            signature
        );

        await expect(
            sampleContractUser
                .connect(addr1)
                .depositAndWithdraw(sampleConsumer.address, { value: ethers.utils.parseEther('1') })
        ).to.not.be.reverted;
    });

});
