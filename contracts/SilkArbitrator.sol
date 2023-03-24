pragma solidity ^0.8.7;

import "./Arbitrator.sol";


contract SilkArbitrator is Arbitrator {

    struct Vote {
        address account; // The address of the juror.
        bytes32 commit; // The commit of the juror. For courts with hidden votes.
        uint choice; // The choice of the juror.
        bool voted; // True if the vote has been cast or revealed, false otherwise.
    }

    struct VoteCounter {
        // The choice with the most votes. Note that in the case of a tie, it is the choice that reached the tied number of votes first.
        uint winningChoice;
        mapping(uint => uint) counts; // The sum of votes for each choice in the form `counts[choice]`.
        bool tied; // True if there is a tie, false otherwise.
    }

    enum Period {
      evidence, // Evidence can be submitted. This is also when drawing has to take place.
      commit, // Jurors commit a hashed vote. This is skipped for courts without hidden votes.
      vote, // Jurors reveal/cast their vote depending on whether the court has hidden votes or not.
      execution // Tokens are redistributed and the ruling is executed.
    }

    struct Dispute {
        Arbitrable arbitrated;  // The contract requiring arbitration.
        uint numberOfChoices;   // The amount of possible choices.
        Period period; // The current period of the dispute.
        uint lastPeriodChange; // The last time the period was changed.
        Vote[] votes;        
        uint totalFeesForJurors; //The total juror fees paid for current dispute.
        uint fees;              // The total amount of fees collected by the arbitrator.
        uint ruling;            // The current ruling.
        DisputeStatus status;   // The status of the dispute.
        bool ruled; // True if the ruling has been executed, false otherwise.
    }

    Dispute[] public disputes;
    mapping(uint => VoteCounter) public DisputeId2VoteCounter;

    address public owner;
    uint256[3] public timesPerPeriod;
    uint16 public arbitrationFeeRatio;
    uint16 constant PERCENTAGE_BASE = 100;
    uint16 public MIN_ARBITRATION_FEE_RATIO = 5;
    uint16 public constant MIN_VOTES = 3; // The global default minimum number of votes in a dispute.

    constructor (
        uint16 _arbitrationFeeRatio,
        uint256[3] memory _timesPerPeriod
    ) {
        require(_arbitrationFeeRatio <= PERCENTAGE_BASE && _arbitrationFeeRatio >= MIN_ARBITRATION_FEE_RATIO);
        arbitrationFeeRatio = _arbitrationFeeRatio;
        timesPerPeriod = _timesPerPeriod;
        owner = msg.sender;

        // padding 
        Dispute storage dispute = disputes[0];
        dispute.arbitrated = Arbitrable(msg.sender);
        dispute.period = Period.evidence;
        dispute.votes[0].account = address(0);
        dispute.status = DisputeStatus.Waiting;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    modifier onlyDuringPeriod(uint _disputeID, Period _period) {
        require(disputes[_disputeID].period == _period); 
        _;
    }

    event NewPeriod(uint indexed _disputeID, Period _period);
    
    function setFeeRatio(uint16 _arbitrationFeeRatio) external onlyOwner {
        require(_arbitrationFeeRatio <= PERCENTAGE_BASE && _arbitrationFeeRatio >= MIN_ARBITRATION_FEE_RATIO);
        arbitrationFeeRatio = _arbitrationFeeRatio;
    }

    function getArbtrationFee(uint amount) public view override returns (uint256) {
        return amount * arbitrationFeeRatio / PERCENTAGE_BASE;
    }

    function createDispute(uint _numberOfChoices) public override payable returns(uint disputeID) {
        disputeID = disputes.length;
        Dispute storage dispute = disputes[disputeID];
        dispute.arbitrated = Arbitrable(msg.sender);
        dispute.numberOfChoices = _numberOfChoices;
        dispute.period = Period.evidence;
        dispute.lastPeriodChange = block.timestamp;
        // As many votes that can be afforded by the provided funds.
        // DisputeId2VoteCounter[dispute.voteCounters.length++].tied = true; // TODO

        emit DisputeCreation(disputeID, Arbitrable(msg.sender));
    }

    function currentRuling(uint _disputeID) public view override returns(uint ruling){
        // TODO
    }

    function disputeStatus(uint _disputeID) public view override returns(DisputeStatus status) {
        // TODO
    }


    /** @dev Passes the period of a specified dispute.
     *  @param _disputeID The ID of the dispute.
     */
    function passPeriod(uint _disputeID) external {
        Dispute storage dispute = disputes[_disputeID];
        if (dispute.period == Period.evidence) {
            require(
                dispute.votes.length > 1 || block.timestamp - dispute.lastPeriodChange >= timesPerPeriod[uint(dispute.period)],
                "The evidence period time has not passed yet and it is not an appeal."
            );
            dispute.period = Period.commit;
        } else if (dispute.period == Period.commit) {
            require(
                block.timestamp - dispute.lastPeriodChange >= timesPerPeriod[uint(dispute.period)],
                "The commit period time has not passed yet and not every juror has committed yet."
            );
            dispute.period = Period.vote;
        } else if (dispute.period == Period.vote) {
            require(
                block.timestamp - dispute.lastPeriodChange >= timesPerPeriod[uint(dispute.period)],
                "The vote period time has not passed yet and not every juror has voted yet."
            );
            dispute.period = Period.execution;
            // emit AppealPossible(_disputeID, dispute.arbitrated);
        } else if (dispute.period == Period.execution) {
            revert("The dispute is already in the last period.");
        }

        dispute.lastPeriodChange = block.timestamp;
        emit NewPeriod(_disputeID, dispute.period);
    }
}