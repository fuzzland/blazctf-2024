// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract BodyGuard {
    bytes public constant DIGEST_SEED = hex"80840397b652018080";
    address public treasury;
    uint8 lastNonce = 0;
    uint8 minVotes = 0;
    mapping(address => bool) public guardians;

    struct Proposal {
        uint32 expiredAt;
        uint24 gas;
        uint8 nonce;
        bytes data;
    }

    constructor(address treasury_, address[] memory guardians_) {
        require(treasury == address(0), "Already initialized");
        treasury = treasury_;
        for (uint256 i = 0; i < guardians_.length; i++) {
            guardians[guardians_[i]] = true;
        }

        minVotes = uint8(guardians_.length);
    }

    function propose(Proposal memory proposal, bytes[] memory signatures) external {
        require(proposal.expiredAt > block.timestamp, "Expired");
        require(proposal.nonce > lastNonce, "Invalid nonce");

        uint256 minVotes_ = minVotes;
        if (guardians[msg.sender]) {
            minVotes_--;
        }

        require(minVotes_ <= signatures.length, "Not enough signatures");
        require(validateSignatures(hashProposal(proposal), signatures), "Invalid signatures");

        lastNonce = proposal.nonce;

        uint256 gasToUse = proposal.gas;
        if (gasleft() < gasToUse) {
            gasToUse = gasleft();
        }

        (bool success,) = treasury.call{gas: gasToUse * 9 / 10}(proposal.data);
        if (!success) {
            revert("Execution failed");
        }
    }

    function hashProposal(Proposal memory proposal) public view returns (bytes32) {
        return keccak256(
            abi.encodePacked(proposal.expiredAt, proposal.gas, proposal.data, proposal.nonce, treasury, DIGEST_SEED)
        );
    }

    function validateSignatures(bytes32 digest, bytes[] memory signaturesSortedBySigners) public view returns (bool) {
        bytes32 lastSignHash = bytes32(0); // ensure that the signers are not duplicated

        for (uint256 i = 0; i < signaturesSortedBySigners.length; i++) {
            address signer = recoverSigner(digest, signaturesSortedBySigners[i]);
            require(guardians[signer], "Not a guardian");

            bytes32 signHash = keccak256(signaturesSortedBySigners[i]);
            if (signHash <= lastSignHash) {
                return false;
            }

            lastSignHash = signHash;
        }

        return true;
    }

    function recoverSigner(bytes32 digest, bytes memory signature) public pure returns (address) {
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }
        return ecrecover(digest, v, r, s);
    }
}

contract CartelTreasury {
    uint256 public constant MIN_TIME_BETWEEN_SALARY = 1 minutes;

    address public bodyGuard;
    mapping(address => uint256) public lastTimeSalaryPaid;

    function initialize(address bodyGuard_) external {
        require(bodyGuard == address(0), "Already initialized");
        bodyGuard = bodyGuard_;
    }

    modifier guarded() {
        require(bodyGuard == address(0) || bodyGuard == msg.sender, "Who?");
        _;
    }

    function doom() external guarded {
        payable(msg.sender).transfer(address(this).balance);
    }

    /// Dismiss the bodyguard
    function gistCartelDismiss() external guarded {
        bodyGuard = address(0);
    }

    /// Payout the salary to the caller every 1 minute
    function salary() external {
        require(block.timestamp - lastTimeSalaryPaid[msg.sender] >= MIN_TIME_BETWEEN_SALARY, "Too soon");
        lastTimeSalaryPaid[msg.sender] = block.timestamp;
        payable(msg.sender).transfer(0.0001 ether);
    }

    receive() external payable {}
}
