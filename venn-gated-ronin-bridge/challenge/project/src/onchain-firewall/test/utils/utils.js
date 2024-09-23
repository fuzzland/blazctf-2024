const ethers = require('ethers');
const { solidityKeccak256 } = ethers.utils;

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

const EIP712_SAFE_TX_TYPE = {
    // "SafeTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 nonce)"
    SafeTx: [
        { type: "address", name: "to" },
        { type: "uint256", name: "value" },
        { type: "bytes", name: "data" },
        { type: "uint8", name: "operation" },
        { type: "uint256", name: "safeTxGas" },
        { type: "uint256", name: "baseGas" },
        { type: "uint256", name: "gasPrice" },
        { type: "address", name: "gasToken" },
        { type: "address", name: "refundReceiver" },
        { type: "uint256", name: "nonce" },
    ],
};

const buildSignatureBytes = (signatures) => {
    const SIGNATURE_LENGTH_BYTES = 65;
    signatures.sort((left, right) => left.signer.toLowerCase().localeCompare(right.signer.toLowerCase()));

    let signatureBytes = "0x";
    let dynamicBytes = "";
    for (const sig of signatures) {
        if (sig.dynamic) {
            const dynamicPartPosition = (signatures.length * SIGNATURE_LENGTH_BYTES + dynamicBytes.length / 2)
                .toString(16)
                .padStart(64, "0");
            const dynamicPartLength = (sig.data.slice(2).length / 2).toString(16).padStart(64, "0");
            const staticSignature = `${sig.signer.slice(2).padStart(64, "0")}${dynamicPartPosition}00`;
            const dynamicPartWithLength = `${dynamicPartLength}${sig.data.slice(2)}`;

            signatureBytes += staticSignature;
            dynamicBytes += dynamicPartWithLength;
        } else {
            signatureBytes += sig.data.slice(2);
        }
    }

    return signatureBytes + dynamicBytes;
};

const safeSignTypedData = async (
    signer,
    safe,
    safeTx,
    chainId,
) => {
    if (!chainId && !signer.provider) throw Error("Provider required to retrieve chainId");
    const cid = chainId || (await signer.provider.getNetwork()).chainId;
    const signerAddress = await signer.getAddress();
    return {
        signer: signerAddress,
        data: await signer._signTypedData({ verifyingContract: safe.address, chainId: cid }, EIP712_SAFE_TX_TYPE, safeTx),
    };
};

const getSafeExecTxArgs = async (safe, tx, signers) => {
    const safeTx = {
        to: tx.to,
        value: tx.value || 0,
        data: tx.data || "0x",
        operation: tx.operation || 0,
        safeTxGas: tx.safeTxGas || 0,
        baseGas: tx.baseGas || 0,
        gasPrice: tx.gasPrice || 0,
        gasToken: tx.gasToken || ZERO_ADDRESS,
        refundReceiver: tx.refundReceiver || ZERO_ADDRESS,
        nonce: tx.nonce || (await safe.nonce()),
    }
    const sigs = await Promise.all(signers.map((signer) => safeSignTypedData(signer, safe, safeTx)));
    const signatureBytes = buildSignatureBytes(sigs);
    return {
        ...safeTx,
        signatures: signatureBytes,
    };
};

const execSafeTx = async (safe, tx, signers) => {
    const safeTx = {
        to: tx.to,
        value: tx.value || 0,
        data: tx.data || "0x",
        operation: tx.operation || 0,
        safeTxGas: tx.safeTxGas || 0,
        baseGas: tx.baseGas || 0,
        gasPrice: tx.gasPrice || 0,
        gasToken: tx.gasToken || ZERO_ADDRESS,
        refundReceiver: tx.refundReceiver || ZERO_ADDRESS,
        nonce: tx.nonce || (await safe.nonce()),
    }
    const sigs = await Promise.all(signers.map((signer) => safeSignTypedData(signer, safe, safeTx)));
    const signatureBytes = buildSignatureBytes(sigs);
    return safe.execTransaction(
        safeTx.to,
        safeTx.value,
        safeTx.data,
        safeTx.operation,
        safeTx.safeTxGas,
        safeTx.baseGas,
        safeTx.gasPrice,
        safeTx.gasToken,
        safeTx.refundReceiver,
        signatureBytes
    )
};

async function approveVectors(sequences, approvedVectorsPolicy) {
    for (const sequence of sequences) {
        const vectorHashes = await getAllVectorHashesForSequence(sequence);
        for (const vectorHash of vectorHashes) {
          await approvedVectorsPolicy.setVectorHashStatus(vectorHash, true);
        }
      }
}

// sequence is array of sighashes Array<byte4>
async function getAllVectorHashesForSequence(sequence) {
    const vectorHashes = new Set(); // Should all be unique anyways...
    let lastVectorHash = `0x${'0'.repeat(64)}`;
    for (const sighash of sequence) {
        // if (!lastVectorHash) { lastVectorHash = solidityKeccak256(['bytes4'], [sighash]);
        //     vectorHashes.add(lastVectorHash); // I don't think we need this if we allow all length 1 sequences
        //     continue;
        // }
        lastVectorHash = solidityKeccak256(['bytes32', 'bytes4'], [lastVectorHash, sighash]);
        vectorHashes.add(lastVectorHash);
    }
    return Array.from(vectorHashes);
}

module.exports = {
    getSafeExecTxArgs,
    execSafeTx,
    approveVectors
}
