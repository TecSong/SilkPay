// SPDX-License-Identifier: MIT

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
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SilkPayV1 is Pausable {
    // **************************** //
    // *    Contract variables    * //
    // **************************** //

    uint8 constant AMOUNT_OF_CHOICES = 2;
    uint8 constant SENDER_WINS = 1;
    uint8 constant RECIPIENT_WINS = 2;
    uint16 public constant MIN_LOCK_TIME = 7200;
    bytes32 constant ZEROBYTES32 = bytes32(0x00);

    address public owner;
    uint256 public gracePeriod;
    Arbitrator public arbitrator;

    PaymentUtils.Payment[] public payments;
    mapping(uint256 => uint256) public disputeIDtoPaymentId;
    mapping(uint256 => uint256) public PaymentIdtoDisputeId;

    enum BillStatus {
        unpaid,
        paid
    }

    struct splitBill {
        uint256 total_amount;
        address[] payees;
        uint256[] shares;
        BillStatus status;

    }
    mapping(uint256 => splitBill) public paymentBillMap;

    event PaymentCreated(
        uint256 indexed PaymentID,
        address indexed sender,
        bool targeted,
        address recipient,
        bytes32 merkleTreeRoot,
        uint256 amount,
        uint256 lockTime
    );

    event RecipientSpecify(
        uint256 indexed PaymentID,
        address indexed recipient
    );
    event PayFinished(
        uint256 indexed PaymentID,
        address indexed sender,
        address indexed recipient,
        uint256 amount
    );
    event Refund(
        uint256 indexed PaymentID,
        address indexed sender,
        uint256 amount
    );
    event Evidence(
        address indexed arbitrator,
        uint256 indexed PaymentID,
        address indexed submitter,
        string _evidence
    );
    event Dispute(
        address indexed arbitrator,
        uint256 indexed dispute_id,
        uint256 indexed PaymentID
    );
    event SettleFee(
        address sender,
        uint senderFee,
        address recipient,
        uint recipientFee
    );
    event OpenSplitBill(
        uint payment_id,
        address recipient,
        uint amount
    );

    constructor(Arbitrator _arbitrator, uint256 _gracePeriod) {
        arbitrator = _arbitrator;
        gracePeriod = _gracePeriod;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function createPayment(
        uint256 lockTime,
        bool targeted,
        address recipient,
        bytes32 merkleTreeRoot
    ) public payable whenNotPaused returns (uint256 PaymentID) {
        if (targeted) {
            require(recipient != address(0));
            require(merkleTreeRoot == ZEROBYTES32);
        } else {
            require(recipient == address(0));
            require(merkleTreeRoot != ZEROBYTES32);
        }
        // require(lockTime >= MIN_LOCK_TIME, "lock time should greater or equal to 7200 seconds");
        require(msg.value > 0, "amount should not be zero");
        payments.push(
            PaymentUtils.Payment(
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
            )
        );
        emit PaymentCreated(
            payments.length - 1,
            msg.sender,
            targeted,
            recipient,
            merkleTreeRoot,
            msg.value,
            lockTime
        );

        return payments.length - 1;
    }

    function createPaymentInErc20(
        uint256 lockTime,
        bool targeted,
        address recipient,
        bytes32 merkleTreeRoot,
        address erc20ContractAddress,
        uint256 amount
    ) public whenNotPaused returns (uint256 PaymentID) {
        if (targeted) {
            require(recipient != address(0));
            require(merkleTreeRoot == ZEROBYTES32);
        } else {
            require(recipient == address(0));
            require(merkleTreeRoot != ZEROBYTES32);
        }
        // require(lockTime >= MIN_LOCK_TIME, "lock time should greater or equal to 7200 seconds");
        require(amount > 0, "amount should not be zero");
        // Transfer value from the ERC20 trader to this contract.
        IERC20 erc20Contract = IERC20(erc20ContractAddress);
        require(amount <= erc20Contract.allowance(msg.sender, address(this)));
        require(erc20Contract.transferFrom(msg.sender, address(this), amount));
        payments.push(
            PaymentUtils.Payment(
                uint8(PaymentUtils.PaymentType.PrePay),
                msg.sender,
                erc20ContractAddress,
                amount,
                targeted,
                recipient,
                merkleTreeRoot,
                lockTime,
                block.timestamp,
                PaymentUtils.PaymentStatus.Locking
            )
        );
        emit PaymentCreated(
            payments.length - 1,
            msg.sender,
            targeted,
            recipient,
            merkleTreeRoot,
            amount,
            lockTime
        );

        return payments.length - 1;
    }

    function _verifyRecipient(
        PaymentUtils.Payment storage payment,
        bytes32[] memory proof,
        address recipient
    ) internal view returns (bool) {
        require(proof.length > 0, "proof should not be empty");
        require(payment.merkleTreeRoot != ZEROBYTES32);

        bytes32 leafHash = keccak256(abi.encodePacked(recipient));
        return MerkleProof.verify(proof, payment.merkleTreeRoot, leafHash);
    }

    /**
     * @dev Verify whether the recipient address is in the recipient merkletree of a certain payment
     *
     */
    function verifyRecipient(
        uint256 PaymentID,
        bytes32[] memory proof,
        address recipient
    ) public view returns (bool) {
        PaymentUtils.Payment storage payment = payments[PaymentID];
        return _verifyRecipient(payment, proof, recipient);
    }

    function specifyRecipient(
        uint256 PaymentID,
        bytes32[] memory proof,
        address recipient
    ) public {
        require(proof.length > 0, "proof should not be empty");
        PaymentUtils.Payment storage payment = payments[PaymentID];
        require(!payment.targeted, "recipient is specified");
        require(msg.sender == payment.sender, "The caller must be the sender");
        require(
            block.timestamp <= payment.startTime + payment.lockTime,
            "not in the lock-up period"
        );
        require(
            verifyRecipient(PaymentID, proof, recipient),
            "recipient is not included in the payment"
        );

        payment.targeted = true;
        payment.recipient = recipient;

        emit RecipientSpecify(PaymentID, recipient);
    }

    function pay(uint256 PaymentID) public whenNotPaused {
        PaymentUtils.Payment storage payment = payments[PaymentID];
        require(payment.status == PaymentUtils.PaymentStatus.Locking);
        require(msg.sender == payment.sender, "The caller must be the sender");
        require(
            block.timestamp <= payment.startTime + payment.lockTime,
            "not in the lock-up period"
        );
        require(payment.targeted == true, "no recipient specified");

        uint256 amount = payment.amount;
        payment.status = PaymentUtils.PaymentStatus.Paid;
        payment.amount = 0;

        splitBill storage _splitBill = paymentBillMap[PaymentID];
        if (_splitBill.total_amount > 0) {
            released(payment, _splitBill);
        } else {
            if (payment.paymentToken != address(0)) {
                IERC20 erc20Contract = IERC20(payment.paymentToken);
                require(erc20Contract.transfer(payment.recipient, amount));
            } else {
                payable(payment.recipient).transfer(amount);
            }
        }

        emit PayFinished(PaymentID, msg.sender, payment.recipient, amount);
    }

    function _raiseDispute(
        PaymentUtils.Payment storage payment
    ) internal returns (uint256) {
        require(
            payment.status == PaymentUtils.PaymentStatus.Locking,
            "status should be locking"
        );
        uint256 borderline = payment.startTime + payment.lockTime;
        require(
            block.timestamp > borderline &&
                block.timestamp <= (borderline + gracePeriod),
            "not during grace period"
        );

        uint256 _arbitrationCost = arbitrator.getArbtrationFee(payment.amount);
        require(msg.value >= _arbitrationCost, "arbitration fee is not enough");
        uint256 dispute_id = arbitrator.createDispute{value: _arbitrationCost}(
            AMOUNT_OF_CHOICES
        );
        payment.status = PaymentUtils.PaymentStatus.Appealing;
        return dispute_id;
    }

    /**
     * @dev called when sender specified the recipient
     * @param PaymentID payment id
     */
    function raiseDisputeByRecipient(
        uint256 PaymentID
    ) public payable whenNotPaused returns (uint256 dispute_id) {
        PaymentUtils.Payment storage payment = payments[PaymentID];
        require(payment.targeted && msg.sender == payment.recipient);

        dispute_id = _raiseDispute(payment);
        disputeIDtoPaymentId[dispute_id] = PaymentID;
        PaymentIdtoDisputeId[PaymentID] = dispute_id;
        emit Dispute(address(arbitrator), dispute_id, PaymentID);
    }

    /**
     * @dev called when sender have not choosed recipient yet
     * @param PaymentID payment id
     */
    function raiseDisputeByParticipant(
        uint256 PaymentID,
        bytes32[] memory proof
    ) public payable whenNotPaused returns (uint256 dispute_id) {
        PaymentUtils.Payment storage payment = payments[PaymentID];
        require(!payment.targeted);
        require(verifyRecipient(PaymentID, proof, msg.sender));

        dispute_id = _raiseDispute(payment);
        disputeIDtoPaymentId[dispute_id] = PaymentID;
        PaymentIdtoDisputeId[PaymentID] = dispute_id;
        emit Dispute(address(arbitrator), dispute_id, PaymentID);
    }

    function onlyTargeted(PaymentUtils.Payment storage payment) internal view {
        require(payment.targeted, "only targeted");
    }

    function onlySender(PaymentUtils.Payment storage payment) internal view {
        require(msg.sender == payment.sender, "The caller must be the sender");
    }

    function onlyRecipient(PaymentUtils.Payment storage payment) internal view {
        require(
            msg.sender == payment.recipient,
            "The caller must be the recipient"
        );
    }

    function onlyParticipant(
        PaymentUtils.Payment storage payment,
        bytes32[] memory proof
    ) internal view {
        require(
            !payment.targeted && payment.merkleTreeRoot != ZEROBYTES32,
            "only not targeted"
        );
        require(
            _verifyRecipient(payment, proof, msg.sender),
            "The caller should be participant"
        );
    }

    function onlyDisputing(PaymentUtils.Payment storage payment) internal view {
        require(
            payment.status == PaymentUtils.PaymentStatus.Appealing,
            "only in a dispute"
        );
    }

    function submitEvidenceBySender(
        uint256 PaymentID,
        string calldata _evidence
    ) external {
        PaymentUtils.Payment storage payment = payments[PaymentID];
        onlyDisputing(payment);
        onlySender(payment);
        _submitEvidence(PaymentID, _evidence);
    }

    function submitEvidenceByRecipient(
        uint256 PaymentID,
        string calldata _evidence
    ) external {
        PaymentUtils.Payment storage payment = payments[PaymentID];
        onlyDisputing(payment);
        onlyTargeted(payment);
        onlyRecipient(payment);
        _submitEvidence(PaymentID, _evidence);
    }

    function submitEvidenceByParticipant(
        uint256 PaymentID,
        string calldata _evidence,
        bytes32[] memory proof
    ) external {
        PaymentUtils.Payment storage payment = payments[PaymentID];
        onlyDisputing(payment);
        onlyParticipant(payment, proof);
        _submitEvidence(PaymentID, _evidence);
    }

    /** @dev Submit a reference to evidence. EVENT.
     *  @param PaymentID The index of a payment.
     *  @param _evidence A link to an evidence using its URI.
     */
    function _submitEvidence(
        uint256 PaymentID,
        string calldata _evidence
    ) internal {
        // uint256 DisputeID = PaymentId2DisputeId[PaymentID];

        emit Evidence(address(arbitrator), PaymentID, msg.sender, _evidence);
    }

    function rule(uint256 _disputeId, uint256 _ruling) external {
        require(
            msg.sender == address(arbitrator),
            "The caller must be the arbitrator."
        );
        uint256 PaymentId = disputeIDtoPaymentId[_disputeId];

        settleFee(PaymentId, _ruling);
    }

    /**
     * @dev settle payment fee after ruling
     * @param payment_id the payment id
     * @param _ruling the ruling of disupte
     */
    function settleFee(
        uint256 payment_id,
        uint256 _ruling
    ) internal {
        PaymentUtils.Payment storage payment = payments[payment_id];
        splitBill storage _splitBill = paymentBillMap[payment_id];
        bool haveSplitBill = _splitBill.total_amount > 0;

        if (_ruling == SENDER_WINS) {
            ethOrErc20Transfer(payment, payment.sender, payment.amount);
            emit SettleFee(
                payment.sender,
                payment.amount,
                payment.recipient,
                0
            );
        } else if (_ruling == RECIPIENT_WINS) {
            // payable(payment.recipient).transfer(payment.amount);
            if (haveSplitBill) {
                released(payment, _splitBill);
            } else {
                ethOrErc20Transfer(payment, payment.recipient, payment.amount);
            }

            emit SettleFee(
                payment.sender,
                0,
                payment.recipient,
                payment.amount
            );
        } else {
            uint256 split_amount = payment.amount / 2;
            if (haveSplitBill) {
                payment.amount = split_amount;
                released(payment, _splitBill);
                payment.amount = split_amount * 2;
            } else {
                ethOrErc20Transfer(payment, payment.recipient, split_amount);
                ethOrErc20Transfer(payment, payment.sender, split_amount);
            }
            // payable(payment.recipient).transfer(split_amount);
            // payable(payment.sender).transfer(split_amount);

            emit SettleFee(
                payment.sender,
                split_amount,
                payment.recipient,
                split_amount
            );
        }

        payment.amount = 0;
        payment.status = PaymentUtils.PaymentStatus.Executed;
    }

    /**
     * @dev refund to the sender of the payment
     */
    function refund(uint256 PaymentID) public whenNotPaused {
        PaymentUtils.Payment storage payment = payments[PaymentID];
        require(msg.sender == payment.sender);
        require(payment.status == PaymentUtils.PaymentStatus.Locking);
        uint256 borderline = payment.startTime + payment.lockTime;
        // can only refund after the grace period ends
        require(block.timestamp > (borderline + gracePeriod));

        uint256 amount = payment.amount;
        payment.amount = 0;
        payment.status = PaymentUtils.PaymentStatus.Refund;
        if (payment.paymentToken == address(0)) {
            payable(payment.sender).transfer(amount);
        } else {
            IERC20 erc20Contract = IERC20(payment.paymentToken);
            require(erc20Contract.transfer(payment.sender, amount));
        }

        emit Refund(PaymentID, msg.sender, amount);
    }

    function openSplitBill(uint256 PaymentID, address[] memory _payees, uint256[] memory _shares) external {
        PaymentUtils.Payment storage payment = payments[PaymentID];
        require(payment.status == PaymentUtils.PaymentStatus.Locking);
        onlyTargeted(payment);
        onlyRecipient(payment);

        require(_payees.length == _shares.length);
        uint256 total;
        for (uint i = 0; i < _shares.length; i++) {
            require(_shares[i] > 0 && _shares[i] < 100);
            total += _shares[i];
        }
        require(total == 100);

        paymentBillMap[PaymentID] = splitBill(
            payment.amount,
            _payees,
            _shares,
            BillStatus.unpaid
        );

        emit OpenSplitBill(PaymentID, msg.sender, payment.amount);

    }

    function ethOrErc20Transfer(PaymentUtils.Payment storage payment, address recepient, uint _amount) internal {
        bool isERC20 = payment.paymentToken != address(0);
        IERC20 erc20Contract;
        if (isERC20) erc20Contract = IERC20(payment.paymentToken);

        if (isERC20) {
            require(erc20Contract.transfer(recepient, _amount));
        } else {
            payable(recepient).transfer(_amount);
        }
    }


    function released(PaymentUtils.Payment storage payment, splitBill storage _splitBill) internal {
        require(_splitBill.status == BillStatus.unpaid);

        bool isERC20 = payment.paymentToken != address(0);
        IERC20 erc20Contract;
        if (isERC20) erc20Contract = IERC20(payment.paymentToken);

        for (uint i = 0; i < _splitBill.payees.length; i++) {
            uint _amount = payment.amount * _splitBill.shares[i] / 100;

            if (isERC20) {
                require(erc20Contract.transfer(payment.recipient, _amount));
            } else {
                payable(payment.recipient).transfer(_amount);
            }
        }

        _splitBill.status = BillStatus.paid;
    } 

    function getPaymentIDsBySender(
        address _sender
    ) public view returns (uint256, uint256[] memory) {
        uint count = 0;
        for (uint256 i = 0; i < payments.length; i++) {
            if (payments[i].sender == _sender) {
                count++;
            }
        }

        uint256[] memory paymentIDs = new uint256[](count);
        count = 0;

        for (uint j = 0; j < payments.length; j++) {
            if (payments[j].sender == _sender) {
                paymentIDs[count++] = j;
            }
        }

        return (count, paymentIDs);
    }

    function getPaymentIDsByRecipient(
        address _recipient
    ) public view returns (uint256, uint256[] memory) {
        uint count = 0;
        for (uint256 i = 0; i < payments.length; i++) {
            if (payments[i].recipient == _recipient) {
                count++;
            }
        }

        uint256[] memory paymentIDs = new uint256[](count);
        count = 0;

        for (uint j = 0; j < payments.length; j++) {
            if (payments[j].recipient == _recipient) {
                paymentIDs[count++] = j;
            }
        }

        return (count, paymentIDs);
    }
}
