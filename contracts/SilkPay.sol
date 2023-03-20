/**
 *  @authors: [@TecSong]
 *  @reviewers: []
 *  @auditors: []
 *  @bounties: []
 *  @deployments: []
 *  @tools: []
 */

pragma solidity ^0.8.7;

import "./Arbitrator.sol";
// import "./Arbitrable.sol";
import "./PaymentUtils.sol";

contract SilkPay {
    // **************************** //
    // *    Contract variables    * //
    // **************************** //

    uint16 constant MIN_LOCK_TIME = 7200;
    Arbitrator public arbitrator;

    PaymentUtils.Payment[] payments;

    event PaymentCreated(
        uint256 indexed PaymentID, 
        address indexed sender, 
        bool targeted, 
        address recipient, 
        bytes32 merkleTreeRoot,
        uint256 amount,
        uint256 lockTime
    );

    event RecipientSpecify(uint256 indexed PaymentID, address indexed recipient);

    constructor (
        Arbitrator _arbitrator
    ) {
        arbitrator = _arbitrator;
    }

    function createPayment(
        uint256 lockTime,
        bool targeted, 
        address recipient,
        bytes32 merkleTreeRoot

    ) public payable returns (uint256 PaymentID) {
        require(lockTime >= MIN_LOCK_TIME, "lock time should greater or equal to 7200 seconds");
        require(msg.value > 0);
        payments.push(PaymentUtils.Payment(
            uint8(PaymentUtils.PaymentType.PrePay),
            msg.sender,
            address(0),
            msg.value,
            targeted,
            recipient,
            merkleTreeRoot,
            lockTime,
            block.timestamp,
            PaymentUtils.PaymentStatus.Locking
        ));
        emit PaymentCreated(payments.length - 1, msg.sender, targeted, recipient, merkleTreeRoot, msg.value, lockTime);

        return payments.length - 1;
    }

    /**
     * @dev Verify whether the recipient address is in the recipient merkletree of a certain payment
     * 
     */
    function verifyRecipient(uint256 PaymentID, bytes32[] memory proof, address recipient) public view returns (bool) {
        bytes32 leafHash = keccak256(abi.encode(recipient));
        PaymentUtils.Payment storage payment = payments[PaymentID];
        return verifyProof(proof, leafHash) == payment.merkleTreeRoot;
    }

    function verifyProof(bytes32[] memory proof, bytes32 leaf) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            computedHash = _hashPair(computedHash, proof[i]);
        }
        return computedHash;
    }

    // Sorted Pair Hash
    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    function specifyRecipient(uint256 PaymentID, bytes32[] memory proof, address recipient) public {
        PaymentUtils.Payment storage payment = payments[PaymentID];
        require(block.timestamp <= payment.startTime + payment.lockTime, "payment is not within the lock-up period");
        //验证指定的recipient是否在merkletree中
        require(verifyRecipient(PaymentID, proof, recipient), "recipient is not included in the payment");

        payment.targeted = true;
        payment.recipient = recipient;

        emit RecipientSpecify(PaymentID, recipient);
    }

}