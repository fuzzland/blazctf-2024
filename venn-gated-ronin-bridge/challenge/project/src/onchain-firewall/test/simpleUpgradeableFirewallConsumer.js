const { expect } = require('chai');
const { parseEther } = require('ethers/lib/utils');
const { ethers } = require('hardhat');

const abiEncoder = new ethers.utils.AbiCoder();

describe('Firewall Simple Consumer Upgradeable', function () {
    let owner, addr1, addr2, firewallProxyAdmin;
    let firewall, approvedCallsPolicy, approvedCallsPolicyIFace, sampleConsumerImplementation, sampleConsumer, sampleConsumerIface, sampleConsumerNoStorageIface, sampleConsumerNoStorage;
    let firewallAdmin, firewallConsumerStorage, TransparentUpgradeableProxyFactory;

    function createDepositCallHash(
        consumerAddress,
        senderAddress,
        originAddress,
        value,
    ) {
        const depositPayload = sampleConsumerIface.encodeFunctionData('deposit()');
        const depositCallHash = ethers.utils.solidityKeccak256(
            ['address', 'address', 'address', 'bytes', 'uint256'],
            [
                consumerAddress,
                senderAddress,
                originAddress,
                depositPayload,
                value,
            ]
        );
        return depositCallHash;
    }

    beforeEach(async function () {
        [owner, addr1, addr2, firewallAdmin] = await ethers.getSigners();
        const FirewallFactory = await ethers.getContractFactory('Firewall');
        firewall = await FirewallFactory.deploy();
        const FirewallProxyAdminFactory = await ethers.getContractFactory('FirewallProxyAdmin');
        firewallProxyAdmin = await FirewallProxyAdminFactory.deploy();
        TransparentUpgradeableProxyFactory = await ethers.getContractFactory(
            'TransparentUpgradeableProxy'
        );
        const SampleSimpleConsumerUpgradeableFactory = await ethers.getContractFactory(
            'SampleSimpleConsumerUpgradeable'
        );
        const SampleSimpleConsumerUpgradeableNoStorageFactory = await ethers.getContractFactory(
            'SampleSimpleConsumerUpgradeableNoStorage'
        );
        const FirewallConsumerStorageFactory = await ethers.getContractFactory(
            'FirewallConsumerStorage'
        );
        const ApprovedCallsPolicyFactory = await ethers.getContractFactory(
            'ApprovedCallsPolicy'
        );
        approvedCallsPolicyIFace = ApprovedCallsPolicyFactory.interface;

        approvedCallsPolicy = await ApprovedCallsPolicyFactory.deploy(firewall.address);
        await approvedCallsPolicy.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes('SIGNER_ROLE')), owner.address);
        await approvedCallsPolicy.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes('POLICY_ADMIN_ROLE')), owner.address);
        await firewall.setPolicyStatus(approvedCallsPolicy.address, true);

        const sampleConsumerNoStorageImplementation = await SampleSimpleConsumerUpgradeableNoStorageFactory.deploy();
        sampleConsumerNoStorageIface = SampleSimpleConsumerUpgradeableNoStorageFactory.interface;
        const sampleConsumerNoStorageProxy = await TransparentUpgradeableProxyFactory.deploy(
            sampleConsumerNoStorageImplementation.address,
            firewallProxyAdmin.address,
            sampleConsumerNoStorageIface.encodeFunctionData('initialize'),
        );
        sampleConsumerNoStorage = await SampleSimpleConsumerUpgradeableNoStorageFactory.attach(sampleConsumerNoStorageProxy.address);

        sampleConsumerImplementation = await SampleSimpleConsumerUpgradeableFactory.deploy();
        sampleConsumerIface = SampleSimpleConsumerUpgradeableFactory.interface;
        firewallConsumerStorage = await FirewallConsumerStorageFactory.deploy(firewall.address, firewallAdmin.address);
        const sampleConsumerProxy = await TransparentUpgradeableProxyFactory.deploy(
            sampleConsumerImplementation.address,
            firewallProxyAdmin.address,
            sampleConsumerIface.encodeFunctionData('initialize', [firewallConsumerStorage.address]),
        );
        sampleConsumer = await SampleSimpleConsumerUpgradeableFactory.attach(sampleConsumerProxy.address);
        await firewallConsumerStorage.connect(firewallAdmin).setVennPolicy(approvedCallsPolicy.address);
        await approvedCallsPolicy.setConsumersStatuses([sampleConsumer.address], [true]);
    });

    it('Firewall sample simple upgradeable consumer change firewall', async function () {
        await expect(
            firewallConsumerStorage
                .connect(addr2)
                .setFirewall(addr1.address)
        ).to.be.revertedWith('FirewallConsumer: not firewall admin');
        const firewallAddressBefore = await firewallConsumerStorage.getFirewall();
        expect(firewallAddressBefore).to.equal(firewall.address);
        await firewallConsumerStorage.connect(firewallAdmin).setFirewall(addr1.address);
        const firewallAddressAfter = await firewallConsumerStorage.getFirewall();
        expect(firewallAddressAfter).to.equal(addr1.address);
    });

    it('Firewall sample simple upgradeable consumer change firewall admin', async function () {
        await expect(
            firewallConsumerStorage
                .connect(addr2)
                .setFirewallAdmin(addr1.address)
        ).to.be.revertedWith('FirewallConsumer: not firewall admin');
        const firewallAdminAddressInStorageBefore = await firewallConsumerStorage.getFirewallAdmin();
        const firewallAdminAddressBefore = await sampleConsumer.firewallAdmin();
        expect(firewallAdminAddressInStorageBefore).to.equal(firewallAdmin.address);
        expect(firewallAdminAddressBefore).to.equal(firewallAdmin.address);
        await firewallConsumerStorage.connect(firewallAdmin).setFirewallAdmin(addr1.address);
        await firewallConsumerStorage.connect(addr1).acceptFirewallAdmin();
        const firewallAdminAddressInStorageAfter = await firewallConsumerStorage.getFirewallAdmin();
        const firewallAdminAddressAfter = await sampleConsumer.firewallAdmin();
        expect(firewallAdminAddressInStorageAfter).to.equal(addr1.address);
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

    it('Consumer without consumer storage - not firewall admin try to setFirewallConsumerStorage', async () => {
        await expect(
            sampleConsumerNoStorage.connect(addr1).setFirewallConsumerStorage(firewallConsumerStorage.address)
        ).to.be.revertedWith('FirewallConsumer: not firewall admin');
    });

    it('Consumer without consumer storage - firewall admin setFirewallConsumerStorage', async () => {
        await expect(
            sampleConsumerNoStorage.connect(owner).setFirewallConsumerStorage(firewallConsumerStorage.address)
        ).to.not.be.reverted;
    });

    it('Consumer without consumer storage - initialized firewall admin try to setFirewallConsumerStorage after it was already called', async () => {
        sampleConsumerNoStorage.connect(owner).setFirewallConsumerStorage(firewallConsumerStorage.address);
        await expect(
            sampleConsumerNoStorage.connect(owner).setFirewallConsumerStorage(firewallConsumerStorage.address)
        ).to.be.revertedWith('FirewallConsumer: not firewall admin');

        await expect(await sampleConsumerNoStorage.connect(owner).firewallAdmin()).to.equal(firewallAdmin.address);
    });

    it('Consumer without consumer storage - call should not fail without storage initialized', async () => {
        await expect(
            sampleConsumerNoStorage
                .connect(addr2)
                .deposit({ value: ethers.utils.parseEther('1') })
        ).to.not.be.reverted;
    });

    it('Consumer without consumer storage - call should not fail with storage initialized but firewall not initialized', async () => {
        await sampleConsumerNoStorage.connect(owner).setFirewallConsumerStorage(firewallConsumerStorage.address);
        await expect(
            sampleConsumerNoStorage
                .connect(addr2)
                .deposit({ value: ethers.utils.parseEther('1') })
        ).to.not.be.reverted;
    });

    it('Consumer without consumer storage - call should fail with storage initialized and firewall initialized', async () => {
        await sampleConsumerNoStorage.connect(owner).setFirewallConsumerStorage(firewallConsumerStorage.address);
        await firewallConsumerStorage.connect(firewallAdmin).setFirewall(firewall.address);
        await firewallConsumerStorage.connect(firewallAdmin).setVennPolicy(approvedCallsPolicy.address);
        await approvedCallsPolicy.setConsumersStatuses([sampleConsumerNoStorage.address], [true]);
        await firewall.connect(firewallAdmin).addPolicy(
            sampleConsumerNoStorage.address,
            sampleConsumerNoStorageIface.getSighash('deposit()'),
            approvedCallsPolicy.address
        );

        const depositAmount = ethers.utils.parseEther('1');
        await expect(
            sampleConsumerNoStorage
                .connect(addr2)
                .deposit({ value: depositAmount })
        ).to.be.revertedWith('ApprovedCallsPolicy: call hashes empty');

        const actualBalance = await sampleConsumerNoStorage.connect(addr1).deposits(addr1.address);
        await expect(actualBalance).to.equal(ethers.utils.parseEther('0'));
    });

    it('Consumer without consumer storage - call should not fail with storage initialized and firewall initialized and approved', async () => {
        await sampleConsumerNoStorage.connect(owner).setFirewallConsumerStorage(firewallConsumerStorage.address);
        await firewallConsumerStorage.connect(firewallAdmin).setFirewall(firewall.address);
        await firewallConsumerStorage.connect(firewallAdmin).setVennPolicy(approvedCallsPolicy.address);
        await approvedCallsPolicy.setConsumersStatuses([sampleConsumerNoStorage.address], [true]);
        await firewall.connect(firewallAdmin).addPolicy(
            sampleConsumerNoStorage.address,
            sampleConsumerNoStorageIface.getSighash('deposit()'),
            approvedCallsPolicy.address
        );
        const depositAmount = ethers.utils.parseEther('1');
        const depositCallHash = createDepositCallHash(
            sampleConsumerNoStorage.address,
            addr1.address,
            addr1.address,
            depositAmount
        );
        
        const packed = ethers.utils.solidityPack(
            ['bytes32[]', 'uint256', 'address', 'uint256', 'address', 'uint256'],
            [
                [depositCallHash],
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

        const approvedCallsPayload = approvedCallsPolicyIFace.encodeFunctionData(
            'approveCallsViaSignature(bytes32[],uint256,address,uint256,bytes)',
            [[depositCallHash], ethers.utils.parseEther('1'), addr1.address, 0, signature]
        );
        const depositData = sampleConsumerNoStorage.interface.encodeFunctionData('deposit');

        await expect(
            sampleConsumerNoStorage.connect(addr1).safeFunctionCall(
                0,
                approvedCallsPayload,
                depositData,
                { value: depositAmount }
            )
        ).to.not.be.reverted;

        const actualBalance = await sampleConsumerNoStorage.connect(addr1).deposits(addr1.address);
        await expect(actualBalance).to.equal(depositAmount);
    });

    it('Consumer without consumer storage and without firewall admin - deploy should fail', async () => {
        await expect(
            TransparentUpgradeableProxyFactory.deploy(
                sampleConsumerImplementation.address,
                firewallProxyAdmin.address,
                sampleConsumerIface.encodeFunctionData('initialize', ['0x0000000000000000000000000000000000000000'])
            )
        ).to.be.reverted;
    });
});