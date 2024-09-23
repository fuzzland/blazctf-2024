const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('Private Invariant Policy', function () {
    let addr1, addr2;
    let firewall, sampleInvariantConsumer, sampleInvariantConsumerIface;
    let sampleInvariantPolicy;

    beforeEach(async function () {
        [addr1, addr2] = await ethers.getSigners();
        const FirewallFactory = await ethers.getContractFactory('Firewall');
        const SampleInvariantConsumerFactory = await ethers.getContractFactory(
            'SampleInvariantConsumer'
        );
        const PrivateInvariantsPolicyFactory = await ethers.getContractFactory(
            'SamplePrivateInvariantsPolicy'
        );
        firewall = await FirewallFactory.deploy();
        sampleInvariantConsumer = await SampleInvariantConsumerFactory.deploy(firewall.address);
        sampleInvariantPolicy = await PrivateInvariantsPolicyFactory.deploy();
        sampleInvariantConsumerIface = SampleInvariantConsumerFactory.interface;
        await firewall.setPolicyStatus(sampleInvariantPolicy.address, true);
    });

    it('Basic invariants 1', async function () {
        await firewall.setPrivateInvariantsPolicy(
            sampleInvariantConsumer.address,
            [sampleInvariantConsumerIface.getSighash('setValue(uint256)')],
            [sampleInvariantPolicy.address]
        );
        await sampleInvariantPolicy.setSighashInvariantStorageSlots(
            sampleInvariantConsumer.address,
            sampleInvariantConsumerIface.getSighash('setValue(uint256)'),
            [ethers.utils.hexZeroPad('0x0', 32)]
        );
        await expect(
            sampleInvariantConsumer
                .connect(addr2)
                .setValue(
                    1
                )
        ).to.not.be.reverted;
        await expect(
            sampleInvariantConsumer
                .connect(addr2)
                .setValue(
                    0
                )
        ).to.be.revertedWith("INVARIANT1");
        await expect(
            sampleInvariantConsumer
                .connect(addr2)
                .setValue(
                    50
                )
        ).to.not.be.reverted;
    });

    it('Basic invariants 1 dryrun', async function () {
        await firewall.setConsumerDryrunStatus(sampleInvariantConsumer.address, true);
        await firewall.setPrivateInvariantsPolicy(
            sampleInvariantConsumer.address,
            [sampleInvariantConsumerIface.getSighash('setValue(uint256)')],
            [sampleInvariantPolicy.address]
        );
        await sampleInvariantPolicy.setSighashInvariantStorageSlots(
            sampleInvariantConsumer.address,
            sampleInvariantConsumerIface.getSighash('setValue(uint256)'),
            [ethers.utils.hexZeroPad('0x0', 32)]
        );
        let tx = sampleInvariantConsumer.connect(addr2).setValue(1);
        await expect(tx).to.not.be.reverted;
        await expect(tx).to.emit(firewall, 'DryrunInvariantPolicyPreSuccess');
        await expect(tx).to.not.emit(firewall, 'DryrunInvariantPolicyPreError');
        await expect(tx).to.emit(firewall, 'DryrunInvariantPolicyPostSuccess');
        await expect(tx).to.not.emit(firewall, 'DryrunInvariantPolicyPostError');
        tx = sampleInvariantConsumer.connect(addr2).setValue(0);
        await expect(tx).to.not.be.reverted;
        await expect(tx).to.emit(firewall, 'DryrunInvariantPolicyPreSuccess');
        await expect(tx).to.not.emit(firewall, 'DryrunInvariantPolicyPreError');
        await expect(tx).to.not.emit(firewall, 'DryrunInvariantPolicyPostSuccess');
        await expect(tx).to.emit(firewall, 'DryrunInvariantPolicyPostError');
        tx = sampleInvariantConsumer.connect(addr2).setValue(50);
        await expect(tx).to.not.be.reverted;
        await expect(tx).to.emit(firewall, 'DryrunInvariantPolicyPreSuccess');
        await expect(tx).to.not.emit(firewall, 'DryrunInvariantPolicyPreError');
        await expect(tx).to.emit(firewall, 'DryrunInvariantPolicyPostSuccess');
        await expect(tx).to.not.emit(firewall, 'DryrunInvariantPolicyPostError');
    });

    it('Basic invariants 2', async function () {
        await firewall.setPrivateInvariantsPolicy(
            sampleInvariantConsumer.address,
            [sampleInvariantConsumerIface.getSighash('setMultipleValues(uint256,uint256)')],
            [sampleInvariantPolicy.address]
        );
        await sampleInvariantPolicy.setSighashInvariantStorageSlots(
            sampleInvariantConsumer.address,
            sampleInvariantConsumerIface.getSighash('setMultipleValues(uint256,uint256)'),
            [ethers.utils.hexZeroPad('0x1', 32), ethers.utils.hexZeroPad('0x2', 32)]
        );
        await expect(
            sampleInvariantConsumer
                .connect(addr2)
                .setMultipleValues(1, 1)
        ).to.not.be.reverted;
        await expect(
            sampleInvariantConsumer
                .connect(addr2)
                .setMultipleValues(1, 52)
        ).to.be.revertedWith("INVARIANT2");
        await expect(
            sampleInvariantConsumer
                .connect(addr2)
                .setMultipleValues(1, 51)
        ).to.not.be.reverted;
        await expect(
            sampleInvariantConsumer
                .connect(addr2)
                .setMultipleValues(1, 500)
        ).to.be.revertedWith("INVARIANT2");
    });

    it('Basic invariants 2 dryrun', async function () {
        await firewall.setConsumerDryrunStatus(sampleInvariantConsumer.address, true);
        await firewall.setPrivateInvariantsPolicy(
            sampleInvariantConsumer.address,
            [sampleInvariantConsumerIface.getSighash('setMultipleValues(uint256,uint256)')],
            [sampleInvariantPolicy.address]
        );
        await sampleInvariantPolicy.setSighashInvariantStorageSlots(
            sampleInvariantConsumer.address,
            sampleInvariantConsumerIface.getSighash('setMultipleValues(uint256,uint256)'),
            [ethers.utils.hexZeroPad('0x1', 32), ethers.utils.hexZeroPad('0x2', 32)]
        );
        let tx = sampleInvariantConsumer.connect(addr2).setMultipleValues(1, 1);
        await expect(tx).to.not.be.reverted;
        await expect(tx).to.emit(firewall, 'DryrunInvariantPolicyPreSuccess');
        await expect(tx).to.not.emit(firewall, 'DryrunInvariantPolicyPreError');
        await expect(tx).to.emit(firewall, 'DryrunInvariantPolicyPostSuccess');
        await expect(tx).to.not.emit(firewall, 'DryrunInvariantPolicyPostError');
        tx = sampleInvariantConsumer.connect(addr2).setMultipleValues(1, 52);
        await expect(tx).to.not.be.reverted;
        await expect(tx).to.emit(firewall, 'DryrunInvariantPolicyPreSuccess');
        await expect(tx).to.not.emit(firewall, 'DryrunInvariantPolicyPreError');
        await expect(tx).to.not.emit(firewall, 'DryrunInvariantPolicyPostSuccess');
        await expect(tx).to.emit(firewall, 'DryrunInvariantPolicyPostError');
        tx = sampleInvariantConsumer.connect(addr2).setMultipleValues(1, 51);
        await expect(tx).to.not.be.reverted;
        await expect(tx).to.emit(firewall, 'DryrunInvariantPolicyPreSuccess');
        await expect(tx).to.not.emit(firewall, 'DryrunInvariantPolicyPreError');
        await expect(tx).to.emit(firewall, 'DryrunInvariantPolicyPostSuccess');
        await expect(tx).to.not.emit(firewall, 'DryrunInvariantPolicyPostError');
        tx = sampleInvariantConsumer.connect(addr2).setMultipleValues(1, 500);
        await expect(tx).to.not.be.reverted;
        await expect(tx).to.emit(firewall, 'DryrunInvariantPolicyPreSuccess');
        await expect(tx).to.not.emit(firewall, 'DryrunInvariantPolicyPreError');
        await expect(tx).to.not.emit(firewall, 'DryrunInvariantPolicyPostSuccess');
        await expect(tx).to.emit(firewall, 'DryrunInvariantPolicyPostError');
    });

});
