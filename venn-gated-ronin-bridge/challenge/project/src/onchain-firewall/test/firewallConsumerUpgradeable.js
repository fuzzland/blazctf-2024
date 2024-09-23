const { expect } = require('chai');
const { parseEther } = require('ethers/lib/utils');
const { ethers } = require('hardhat');

const ETH_ADDRESS = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';

describe('Firewall Consumer Upgradeable', function () {
    let owner, addr1, addr2, firewallProxyAdmin, firewallAdmin;
    let firewall, approvedCallsPolicy, sampleConsumer, sampleConsumerIface;

    beforeEach(async function () {
        [owner, addr1, addr2, firewallAdmin] = await ethers.getSigners();
        const FirewallFactory = await ethers.getContractFactory('Firewall');
        firewall = await FirewallFactory.deploy();
        const FirewallProxyAdminFactory = await ethers.getContractFactory('FirewallProxyAdmin');
        firewallProxyAdmin = await FirewallProxyAdminFactory.deploy();
        const FirewallTransparentUpgradeableProxyFactory = await ethers.getContractFactory(
            'FirewallTransparentUpgradeableProxy'
        );
        const SampleConsumerUpgradeableFactory = await ethers.getContractFactory(
            'SampleConsumerUpgradeable'
        );
        const ApprovedCallsPolicy = await ethers.getContractFactory(
            'ApprovedCallsPolicy'
        );
        approvedCallsPolicy = await ApprovedCallsPolicy.deploy(firewall.address);
        await approvedCallsPolicy.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes('SIGNER_ROLE')), owner.address);
        await approvedCallsPolicy.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes('POLICY_ADMIN_ROLE')), owner.address);
        await firewall.setPolicyStatus(approvedCallsPolicy.address, true);
        const sampleConsumerImplementation = await SampleConsumerUpgradeableFactory.deploy();
        sampleConsumerIface = SampleConsumerUpgradeableFactory.interface;
        const sampleConsumerProxy = await FirewallTransparentUpgradeableProxyFactory.deploy(
            sampleConsumerImplementation.address,
            firewallProxyAdmin.address,
            sampleConsumerIface.encodeFunctionData('initialize', []),
            firewall.address,
            firewallAdmin.address,
        );
        sampleConsumer = await SampleConsumerUpgradeableFactory.attach(sampleConsumerProxy.address);
        await approvedCallsPolicy.setConsumersStatuses([sampleConsumer.address], [true]);
    });

    it('Firewall Proxy change firewall', async function () {
        await expect(
            firewallProxyAdmin
                .connect(addr2)
                .changeFirewall(sampleConsumer.address, addr1.address)
        ).to.be.revertedWith('Ownable: caller is not the owner');
        const firewallAddressBefore = await firewallProxyAdmin.getProxyFirewall(sampleConsumer.address);
        expect(firewallAddressBefore).to.equal(firewall.address);
        await firewallProxyAdmin.changeFirewall(sampleConsumer.address, addr1.address);
        const firewallAddressAfter = await firewallProxyAdmin.getProxyFirewall(sampleConsumer.address);
        expect(firewallAddressAfter).to.equal(addr1.address);
    });

    it('Firewall Proxy change firewall admin', async function () {
        await expect(
            firewallProxyAdmin
                .connect(addr2)
                .changeFirewallAdmin(sampleConsumer.address, addr1.address)
        ).to.be.revertedWith('Ownable: caller is not the owner');
        const firewallAdminAddressBefore = await firewallProxyAdmin.getProxyFirewallAdmin(sampleConsumer.address);
        expect(firewallAdminAddressBefore).to.equal(firewallAdmin.address);
        await firewallProxyAdmin.changeFirewallAdmin(sampleConsumer.address, addr1.address);
        const firewallAdminAddressAfter = await firewallProxyAdmin.getProxyFirewallAdmin(sampleConsumer.address);
        expect(firewallAdminAddressAfter).to.equal(addr1.address);
    });

    it('Firewall Approved calls policy unapproved call fails', async function () {
        await firewall.connect(firewallAdmin).addPolicy(
            sampleConsumer.address,
            sampleConsumerIface.getSighash('deposit()'),
            approvedCallsPolicy.address
        );
        await expect(
            sampleConsumer
                .connect(addr2)
                .deposit({ value: ethers.utils.parseEther('1') })
        ).to.be.revertedWith('ApprovedCallsPolicy: call hashes empty');
    });

    it('Firewall Approved calls policy admin functions', async function () {
        await firewall.connect(firewallAdmin).addPolicy(
            sampleConsumer.address,
            sampleConsumerIface.getSighash('setOwner(address)'),
            approvedCallsPolicy.address
        );
        const setOwnerPayload = sampleConsumerIface.encodeFunctionData(
            'setOwner(address)',
            [owner.address]
        );
        const callHash = ethers.utils.solidityKeccak256(
            ['address', 'address', 'address', 'bytes', 'uint256'],
            [
                sampleConsumer.address,
                owner.address,
                owner.address,
                setOwnerPayload,
                0,
            ]
        );
        await approvedCallsPolicy.approveCalls(
            [callHash],
            parseEther('1'),
            owner.address,
        );
        await expect(sampleConsumer.connect(owner).setOwner(owner.address)).to
            .not.be.reverted;
        await expect(
            sampleConsumer.connect(owner).setOwner(owner.address)
        ).to.be.revertedWith('ApprovedCallsPolicy: call hashes empty');
        const nextCallHash = ethers.utils.solidityKeccak256(
            ['address', 'address', 'address', 'bytes', 'uint256'],
            [
                sampleConsumer.address,
                owner.address,
                owner.address,
                setOwnerPayload,
                1,
            ]
        );
        await approvedCallsPolicy.approveCalls(
            [nextCallHash],
            parseEther('1'),
            owner.address,
        );
        await expect(
            sampleConsumer.connect(owner).setOwner(owner.address)
        ).to.be.revertedWith('ApprovedCallsPolicy: invalid call hash');
    });

    it('Firewall Approved calls bundle policy onlyOwner functions', async function () {
        const ApprovedCallsPolicy = await ethers.getContractFactory(
            'ApprovedCallsPolicy'
        );
        const approvedCallsPolicy =
            await ApprovedCallsPolicy.deploy(firewall.address);
        await expect(
            approvedCallsPolicy.connect(addr1).approveCalls(
                [`0x${'00'.repeat(32)}`],
                parseEther('1'),
                owner.address
            )
        ).to.be.revertedWith(`AccessControl: account ${addr1.address.toLowerCase()} is missing role 0xe2f4eaae4a9751e85a3e4a7b9587827a877f29914755229b07a7b2da98285f70`);
    });

    it('Firewall Approved calls bundle policy unapproved call fails', async function () {
        const ApprovedCallsPolicy = await ethers.getContractFactory('ApprovedCallsPolicy');
        const approvedCallsPolicy = await ApprovedCallsPolicy.deploy(firewall.address);
        await approvedCallsPolicy.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes('SIGNER_ROLE')), owner.address);
        await approvedCallsPolicy.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes('POLICY_ADMIN_ROLE')), owner.address);
        await approvedCallsPolicy.setConsumersStatuses([sampleConsumer.address], [true]);
        await firewall.setPolicyStatus(approvedCallsPolicy.address, true);
        await firewall.connect(firewallAdmin).addPolicy(
            sampleConsumer.address,
            sampleConsumerIface.getSighash('deposit()'),
            approvedCallsPolicy.address
        );
        await expect(
            sampleConsumer
                .connect(addr2)
                .deposit({ value: ethers.utils.parseEther('1') })
        ).to.be.revertedWith('ApprovedCallsPolicy: call hashes empty');
    });

    it('Firewall Approved calls bundle policy multiple approved calls', async function () {
        const SampleContractUser = await ethers.getContractFactory(
            'SampleContractUser'
        );
        const sampleContractUser = await SampleContractUser.deploy();
        await firewall.connect(firewallAdmin).addPolicy(
            sampleConsumer.address,
            sampleConsumerIface.getSighash('deposit()'),
            approvedCallsPolicy.address
        );

        const depositPayload = sampleConsumerIface.encodeFunctionData('deposit()');
        const withdrawPayload = sampleConsumerIface.encodeFunctionData('withdraw(uint256)', [ethers.utils.parseEther('1')]);

        const depositCallHash = ethers.utils.solidityKeccak256(
            ['address', 'address', 'address', 'bytes', 'uint256'],
            [
                sampleConsumer.address,
                sampleContractUser.address,
                owner.address,
                depositPayload,
                ethers.utils.parseEther('1'),
            ]
        );
        const withdrawCallHash = ethers.utils.solidityKeccak256(
            ['address', 'address', 'address', 'bytes', 'uint256'],
            [
                sampleConsumer.address,
                sampleContractUser.address,
                owner.address,
                withdrawPayload,
                ethers.utils.parseEther('0'),
            ]
        );
        // We pass the calls in reverse order because the bundle policy pops the last element
        await approvedCallsPolicy.approveCalls(
            [withdrawCallHash, depositCallHash],
            parseEther('1'),
            owner.address,
        );

        await expect(
            sampleContractUser
                .connect(owner)
                .depositAndWithdraw(sampleConsumer.address, { value: ethers.utils.parseEther('1') })
        ).to.not.be.reverted;
    });

    it('Firewall Approved calls bundle policy wrong call order fails', async function () {
        const SampleContractUser = await ethers.getContractFactory(
            'SampleContractUser'
        );
        const sampleContractUser = await SampleContractUser.deploy();
        await firewall.connect(firewallAdmin).addPolicy(
            sampleConsumer.address,
            sampleConsumerIface.getSighash('deposit()'),
            approvedCallsPolicy.address
        );

        const depositPayload = sampleConsumerIface.encodeFunctionData('deposit()');
        const withdrawPayload = sampleConsumerIface.encodeFunctionData('withdraw(uint256)', [ethers.utils.parseEther('1')]);
        // +2 instead of +1 because we need to call 'approveCalls'
        const executionBlock = (await ethers.provider.getBlockNumber()) + 2;

        const depositCallHash = ethers.utils.solidityKeccak256(
            ['address', 'address', 'address', 'bytes', 'uint256', 'uint256'],
            [
                sampleConsumer.address,
                sampleContractUser.address,
                owner.address,
                depositPayload,
                ethers.utils.parseEther('1'),
                executionBlock,
            ]
        );
        const withdrawCallHash = ethers.utils.solidityKeccak256(
            ['address', 'address', 'address', 'bytes', 'uint256', 'uint256'],
            [
                sampleConsumer.address,
                sampleContractUser.address,
                owner.address,
                withdrawPayload,
                ethers.utils.parseEther('0'),
                executionBlock,
            ]
        );
        await approvedCallsPolicy.approveCalls(
            [depositCallHash, withdrawCallHash],
            parseEther('1'),
            owner.address,
        );

        await expect(
            sampleContractUser
                .connect(owner)
                .depositAndWithdraw(sampleConsumer.address, { value: ethers.utils.parseEther('1') })
        ).to.be.revertedWith('ApprovedCallsPolicy: invalid call hash');
    });

    it('Firewall Approved calls bundle policy admin functions', async function () {
        await firewall.connect(firewallAdmin).addPolicy(
            sampleConsumer.address,
            sampleConsumerIface.getSighash('setOwner(address)'),
            approvedCallsPolicy.address
        );
        const setOwnerPayload = sampleConsumerIface.encodeFunctionData(
            'setOwner(address)',
            [owner.address]
        );
        const callHash = ethers.utils.solidityKeccak256(
            ['address', 'address', 'address', 'bytes', 'uint256'],
            [
                sampleConsumer.address,
                owner.address,
                owner.address,
                setOwnerPayload,
                0,
            ]
        );
        await approvedCallsPolicy.approveCalls(
            [callHash],
            parseEther('1'),
            owner.address,
        );
        await expect(sampleConsumer.connect(owner).setOwner(owner.address)).to
            .not.be.reverted;
        await expect(
            sampleConsumer.connect(owner).setOwner(owner.address)
        ).to.be.revertedWith('ApprovedCallsPolicy: call hashes empty');
        const nextCallHash = ethers.utils.solidityKeccak256(
            ['address', 'address', 'address', 'bytes', 'uint256'],
            [
                sampleConsumer.address,
                owner.address,
                addr1.address,
                setOwnerPayload,
                0,
            ]
        );
        await approvedCallsPolicy.approveCalls(
            [nextCallHash],
            parseEther('1'),
            owner.address,
        );
        await expect(
            sampleConsumer.connect(owner).setOwner(owner.address)
        ).to.be.revertedWith('ApprovedCallsPolicy: invalid call hash');
    });

    it('Firewall balance change', async function () {
        const BalanceChangePolicy = await ethers.getContractFactory(
            'BalanceChangePolicy'
        );
        const balanceChangePolicy = await BalanceChangePolicy.deploy(firewall.address);
        await balanceChangePolicy.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes('POLICY_ADMIN_ROLE')), owner.address);
        await balanceChangePolicy.setConsumersStatuses([sampleConsumer.address], [true]);
        await firewall.setPolicyStatus(balanceChangePolicy.address, true);
        await firewall.connect(firewallAdmin).addPolicy(
            sampleConsumer.address,
            sampleConsumerIface.getSighash('deposit()'),
            balanceChangePolicy.address
        );
        await firewall.connect(firewallAdmin).addPolicy(
            sampleConsumer.address,
            sampleConsumerIface.getSighash('withdraw(uint256)'),
            balanceChangePolicy.address
        );
        await expect(
            balanceChangePolicy.connect(addr1).setConsumerMaxBalanceChange(
                sampleConsumer.address,
                ETH_ADDRESS,
                ethers.utils.parseEther('25')
        )
        ).to.be.revertedWith(`AccessControl: account ${addr1.address.toLowerCase()} is missing role 0xace7350211ab645c1937904136ede4855ac3aa1eabb4970e1a51a335d2e19920`);
        await balanceChangePolicy.setConsumerMaxBalanceChange(
            sampleConsumer.address,
            ETH_ADDRESS,
            ethers.utils.parseEther('25')
        );
        await expect(
            sampleConsumer
                .connect(addr2)
                .deposit({ value: ethers.utils.parseEther('25.000001') })
        ).to.be.revertedWith(
            'BalanceChangePolicy: Balance change exceeds limit'
        );
        await expect(
            sampleConsumer
                .connect(addr2)
                .deposit({ value: ethers.utils.parseEther('25') })
        ).to.not.be.reverted;
        await expect(
            sampleConsumer
                .connect(addr2)
                .deposit({ value: ethers.utils.parseEther('1') })
        ).to.not.be.reverted;
        await expect(
            sampleConsumer
                .connect(addr2)
                .withdraw(ethers.utils.parseEther('25.0000001'))
        ).to.be.revertedWith(
            'BalanceChangePolicy: Balance change exceeds limit'
        );
        await expect(
            sampleConsumer
                .connect(addr2)
                .withdraw(ethers.utils.parseEther('25'))
        ).to.not.be.reverted;
    });
});
