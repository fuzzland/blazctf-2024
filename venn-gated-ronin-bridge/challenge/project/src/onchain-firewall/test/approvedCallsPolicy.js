const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('Approved Calls Policy', () => {
    let owner, addr1, addr2;
    let firewall, sampleConsumer, sampleConsumerIface, sampleContractUser;
    let approvedCallsPolicy, approvedCallsPolicyIface;
    
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

    function createWithdrawCallHash(
        consumerAddress,
        senderAddress,
        originAddress,
        value,
    ) {
        const withdrawPayload = sampleConsumerIface.encodeFunctionData('withdraw(uint256)', [value]);
        const withdrawCallHash = ethers.utils.solidityKeccak256(
            ['address', 'address', 'address', 'bytes', 'uint256'],
            [
                consumerAddress,
                senderAddress,
                originAddress,
                withdrawPayload,
                ethers.utils.parseEther('0'),
            ]
        );
        return withdrawCallHash;
    }

    async function createSignature(
        signer,
        callHashes,
        expiration,
        origin,
        nonce,
        policyAddress,
    ) {
        const packed = ethers.utils.solidityPack(
            ['bytes32[]', 'uint256', 'address', 'uint256', 'address', 'uint256'],
            [
                callHashes,
                expiration,
                origin,
                nonce,
                policyAddress,
                31337, // hardhat chainid
            ]
        );
        const messageHash = ethers.utils.solidityKeccak256(
            ['bytes'], [packed]
        );
        const messageHashBytes = ethers.utils.arrayify(messageHash)
        const signature = await signer.signMessage(messageHashBytes);
        return signature;
    }

    beforeEach(async () => {
        [owner, addr1, addr2] = await ethers.getSigners();
        const FirewallFactory = await ethers.getContractFactory('Firewall');
        const SampleConsumerFactory = await ethers.getContractFactory(
            'SampleConsumer'
        );
        const SampleContractUser = await ethers.getContractFactory(
            'SampleContractUser'
        );
        const ApprovedCallsPolicy = await ethers.getContractFactory(
            'ApprovedCallsPolicy'
        );

        firewall = await FirewallFactory.deploy();

        approvedCallsPolicy = await ApprovedCallsPolicy.deploy(firewall.address);
        sampleConsumer = await SampleConsumerFactory.deploy(firewall.address);
        sampleContractUser = await SampleContractUser.deploy();
        sampleConsumerIface = SampleConsumerFactory.interface;
        approvedCallsPolicyIface = ApprovedCallsPolicy.interface;
        sampleContractUser = await SampleContractUser.deploy();

        await approvedCallsPolicy.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes('SIGNER_ROLE')), owner.address);
        await approvedCallsPolicy.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes('POLICY_ADMIN_ROLE')), owner.address);
        await approvedCallsPolicy.setConsumersStatuses([sampleConsumer.address], [true]);
        await firewall.setPolicyStatus(approvedCallsPolicy.address, true);
        await firewall.addGlobalPolicy(
            sampleConsumer.address,
            approvedCallsPolicy.address
        );
    });

    it('gas comparison test', async function () {
        await firewall.removeGlobalPolicy(
            sampleConsumer.address,
            approvedCallsPolicy.address
        );
        await sampleConsumer.deposit({ value: ethers.utils.parseEther('1') });
        await sampleConsumer.withdraw(ethers.utils.parseEther('1'));
    });

    it('Firewall Approved calls with signature policy only signer functions', async () => {
        await expect(
            approvedCallsPolicy.connect(addr1).approveCalls(
                [`0x${'00'.repeat(32)}`],
                0,
                addr2.address,
            )
        ).to.be.revertedWith(`AccessControl: account ${addr1.address.toLowerCase()} is missing role 0xe2f4eaae4a9751e85a3e4a7b9587827a877f29914755229b07a7b2da98285f70`);
    });

    describe('run', () => {
        it('Firewall Approved calls with signature policy unapproved call fails', async () => {
            await firewall.addPolicy(
                sampleConsumer.address,
                sampleConsumerIface.getSighash('deposit()'),
                approvedCallsPolicy.address
            );
            const tx = sampleConsumer
                    .connect(addr2)
                    .deposit({ value: ethers.utils.parseEther('1') });
            await expect(tx).to.be.revertedWith('ApprovedCallsPolicy: call hashes empty');
        });

        it('Firewall Approved calls with signature policy approved calls', async () => {
            const depositCallHash = createDepositCallHash(
                sampleConsumer.address,
                sampleContractUser.address,
                addr1.address,
                ethers.utils.parseEther('1'),
            );
            const withdrawCallHash = createWithdrawCallHash(
                sampleConsumer.address,
                sampleContractUser.address,
                addr1.address,
                ethers.utils.parseEther('1'),
            );
            const signature = await createSignature(
                owner,
                [withdrawCallHash, depositCallHash],
                ethers.utils.parseEther('1'), // expiration, yuge numba
                addr1.address,
                0,
                approvedCallsPolicy.address,
            );
            // We pass the calls in reverse order because the bundle policy pops the last element
            await approvedCallsPolicy.approveCallsViaSignature(
                [withdrawCallHash, depositCallHash],
                ethers.utils.parseEther('1'),
                addr1.address,
                0,
                signature,
            );
    
            let tx = sampleContractUser
                    .connect(addr1)
                    .depositAndWithdraw(sampleConsumer.address, { value: ethers.utils.parseEther('1') });
            await expect(tx).to.not.be.reverted;
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPreSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPreError');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPostSuccess');
            await expect(tx).to.not.emit(firewall, 'DryrunPolicyPostError');
        });
    });

    it('Firewall safeFunctionCall cannot call unapproved vennPolicy', async function () {
        const depositPayload = sampleConsumerIface.encodeFunctionData('deposit()');
        const depositCallHash = ethers.utils.solidityKeccak256(
            ['address', 'address', 'address', 'bytes', 'uint256'],
            [
                sampleConsumer.address,
                addr1.address,
                addr1.address,
                depositPayload,
                ethers.utils.parseEther('1'),
            ]
        );
        const signature = await createSignature(
            owner,
            [depositCallHash],
            ethers.utils.parseEther('1'), // expiration, yuge numba
            addr1.address,
            0,
            approvedCallsPolicy.address,
        );
        const approvePayload = approvedCallsPolicyIface.encodeFunctionData(
            'approveCallsViaSignature',
            [
                [depositCallHash],
                ethers.utils.parseEther('1'),
                addr1.address,
                0,
                signature
            ]
        );

        await expect(
            sampleConsumer
                .connect(addr1)
                .safeFunctionCall(approvedCallsPolicy.address, approvePayload, depositPayload, { value: ethers.utils.parseEther('1') })
        ).to.be.revertedWith("FirewallConsumer: Not approved Venn policy");
    });


    it('Firewall safeFunctionCall cannot call approved then unapproved vennPolicy', async function () {
        await sampleConsumer.setApprovedVennPolicy(approvedCallsPolicy.address, true);
        await sampleConsumer.setApprovedVennPolicy(approvedCallsPolicy.address, false);
        const depositPayload = sampleConsumerIface.encodeFunctionData('deposit()');
        const depositCallHash = ethers.utils.solidityKeccak256(
            ['address', 'address', 'address', 'bytes', 'uint256'],
            [
                sampleConsumer.address,
                addr1.address,
                addr1.address,
                depositPayload,
                ethers.utils.parseEther('1'),
            ]
        );
        const signature = await createSignature(
            owner,
            [depositCallHash],
            ethers.utils.parseEther('1'), // expiration, yuge numba
            addr1.address,
            0,
            approvedCallsPolicy.address,
        );
        const approvePayload = approvedCallsPolicyIface.encodeFunctionData(
            'approveCallsViaSignature',
            [
                [depositCallHash],
                ethers.utils.parseEther('1'),
                addr1.address,
                0,
                signature
            ]
        );

        await expect(
            sampleConsumer
                .connect(addr1)
                .safeFunctionCall(approvedCallsPolicy.address, approvePayload, depositPayload, { value: ethers.utils.parseEther('1') })
        ).to.be.revertedWith("FirewallConsumer: Not approved Venn policy");
    });

    it('Firewall safeFunctionCall cannot call approved then unapproved vennPolicy, but can when approved vennPolicies', async function () {
        await sampleConsumer.setApprovedVennPolicy(approvedCallsPolicy.address, true);
        await sampleConsumer.setApprovedVennPolicy(approvedCallsPolicy.address, false);
        const depositPayload = sampleConsumerIface.encodeFunctionData('deposit()');
        const depositCallHash = ethers.utils.solidityKeccak256(
            ['address', 'address', 'address', 'bytes', 'uint256'],
            [
                sampleConsumer.address,
                addr1.address,
                addr1.address,
                depositPayload,
                ethers.utils.parseEther('1'),
            ]
        );
        const signature = await createSignature(
            owner,
            [depositCallHash],
            ethers.utils.parseEther('1'), // expiration, yuge numba
            addr1.address,
            0,
            approvedCallsPolicy.address,
        );
        const approvePayload = approvedCallsPolicyIface.encodeFunctionData(
            'approveCallsViaSignature',
            [
                [depositCallHash],
                ethers.utils.parseEther('1'),
                addr1.address,
                0,
                signature
            ]
        );

        await expect(
            sampleConsumer
                .connect(addr1)
                .safeFunctionCall(approvedCallsPolicy.address, approvePayload, depositPayload, { value: ethers.utils.parseEther('1') })
        ).to.be.revertedWith("FirewallConsumer: Not approved Venn policy");
        await sampleConsumer.setApprovedVennPolicy(approvedCallsPolicy.address, true);
        await expect(
            sampleConsumer
                .connect(addr1)
                .safeFunctionCall(approvedCallsPolicy.address, approvePayload, depositPayload, { value: ethers.utils.parseEther('1') })
        ).to.not.be.reverted;
    });


    it('Firewall Approved calls with signature + safeFunctionCall', async function () {
        await sampleConsumer.setApprovedVennPolicy(approvedCallsPolicy.address, true);
        const depositPayload = sampleConsumerIface.encodeFunctionData('deposit()');
        const depositCallHash = ethers.utils.solidityKeccak256(
            ['address', 'address', 'address', 'bytes', 'uint256'],
            [
                sampleConsumer.address,
                addr1.address,
                addr1.address,
                depositPayload,
                ethers.utils.parseEther('1'),
            ]
        );
        const signature = await createSignature(
            owner,
            [depositCallHash],
            ethers.utils.parseEther('1'), // expiration, yuge numba
            addr1.address,
            0,
            approvedCallsPolicy.address,
        );
        const approvePayload = approvedCallsPolicyIface.encodeFunctionData(
            'approveCallsViaSignature',
            [
                [depositCallHash],
                ethers.utils.parseEther('1'),
                addr1.address,
                0,
                signature
            ]
        );

        await expect(
            sampleConsumer
                .connect(addr1)
                .safeFunctionCall(approvedCallsPolicy.address, approvePayload, depositPayload, { value: ethers.utils.parseEther('1') })
        ).to.not.be.reverted;
    });

});
