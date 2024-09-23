const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('Admin Call Policy', () => {
    let owner, addr1, addr2;
    let firewall, adminCallPolicy, sampleConsumer, sampleConsumerIface;

    function createSetOwnerCallHash(
        consumerAddress,
        senderAddress,
        originAddress,
        newOwnerAddress,
        value,
    ) {
        const setOwnerPayload = sampleConsumerIface.encodeFunctionData(
            'setOwner(address)',
            [newOwnerAddress]
        );
        const callHash = ethers.utils.solidityKeccak256(
            ['address', 'address', 'address', 'bytes', 'uint256'],
            [
                consumerAddress,
                senderAddress,
                originAddress,
                setOwnerPayload,
                value,
            ]
        );
        return callHash;
    }

    beforeEach(async () => {
        [owner, addr1, addr2] = await ethers.getSigners();
        const FirewallFactory = await ethers.getContractFactory('Firewall');
        const SampleConsumerFactory = await ethers.getContractFactory(
            'SampleConsumer'
        );
        const AdminCallPolicy = await ethers.getContractFactory(
            'AdminCallPolicy'
        );
        firewall = await FirewallFactory.deploy();
        adminCallPolicy = await AdminCallPolicy.deploy(firewall.address);
        sampleConsumer = await SampleConsumerFactory.deploy(firewall.address);
        sampleConsumerIface = SampleConsumerFactory.interface;
        await firewall.setPolicyStatus(adminCallPolicy.address, true);
        await adminCallPolicy.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes('APPROVER_ROLE')), owner.address);
        await adminCallPolicy.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes('POLICY_ADMIN_ROLE')), owner.address);
        await adminCallPolicy.setConsumersStatuses([sampleConsumer.address], [true]);
    });

    it('Firewall Admin call policy onlyOwner functions', async function () {
        await expect(
            adminCallPolicy.connect(addr1).approveCall(
                `0x${'00'.repeat(32)}`
            )
        ).to.be.revertedWith(`AccessControl: account ${addr1.address.toLowerCase()} is missing role 0x408a36151f841709116a4e8aca4e0202874f7f54687dcb863b1ea4672dc9d8cf`);
        await expect(
            adminCallPolicy.connect(addr1).setExpirationTime(
                10000
            )
        ).to.be.revertedWith(`AccessControl: account ${addr1.address.toLowerCase()} is missing role 0x408a36151f841709116a4e8aca4e0202874f7f54687dcb863b1ea4672dc9d8cf`);
        await expect(
            adminCallPolicy.connect(owner).setExpirationTime(
                10000
            )
        ).to.not.be.reverted;
    });

    describe('run', () => {
        it('Firewall Admin call policy approved/unapproved calls', async function () {
            await firewall.addPolicy(
                sampleConsumer.address,
                sampleConsumerIface.getSighash('setOwner(address)'),
                adminCallPolicy.address
            );
            let tx = sampleConsumer
                    .connect(owner)
                    .setOwner(addr1.address);
            await expect(tx).to.be.revertedWith('AdminCallPolicy: Call not approved');
            
            const callHash = createSetOwnerCallHash(
                sampleConsumer.address,
                owner.address,
                owner.address,
                addr1.address,
                0,
            );
            await adminCallPolicy.approveCall(callHash);
            tx = sampleConsumer
                    .connect(owner)
                    .setOwner(addr1.address);
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
    
        it('Firewall Admin call policy approved/unapproved calls', async function () {
            await firewall.addPolicy(
                sampleConsumer.address,
                sampleConsumerIface.getSighash('setOwner(address)'),
                adminCallPolicy.address
            );
            let tx = sampleConsumer
                .connect(owner)
                .setOwner(addr1.address);
            await expect(tx).to.not.be.reverted;
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPreSuccess');
            await expect(tx).to.emit(firewall, 'DryrunPolicyPreError');
            await expect(tx).to.emit(firewall, 'DryrunPolicyPostSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPostError');
            
            const callHash = createSetOwnerCallHash(
                sampleConsumer.address,
                owner.address,
                owner.address,
                addr1.address,
                0,
            );
            await adminCallPolicy.approveCall(callHash);
            tx = sampleConsumer
                    .connect(owner)
                    .setOwner(addr1.address);
            await expect(tx).to.be.revertedWith('Ownable: caller is not the owner');
        });
    });
});
