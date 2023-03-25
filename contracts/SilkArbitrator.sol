// SPDX-License-Identifier: MIT

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
        uint fees;              // The total amount of fees collected by the arbitrator.
        uint ruling;            // The current ruling.
        DisputeStatus status;   // The status of the dispute.
        bool ruled; // True if the ruling has been executed, false otherwise.
    }

    Dispute[] public disputes;
    mapping(uint => VoteCounter) public DisputeId2VoteCounter;

    address public owner;
    uint256[4] public timesPerPeriod;
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
        dispute.fees = msg.value;
        dispute.lastPeriodChange = block.timestamp;

        emit DisputeCreation(disputeID, Arbitrable(msg.sender));
    }

        /** @dev Sets the caller's choices for the specified vote.
     *  @param _disputeID The ID of the dispute.
     *  @param _voteID The ID of the vote.
     *  @param _choice The choice.
     *  @param _salt The salt for the commit if the votes were hidden.
     */
    function castVote(uint _disputeID, uint _voteID, uint _choice, uint _salt) external onlyDuringPeriod(_disputeID, Period.vote) {
        Dispute storage dispute = disputes[_disputeID];
        require(_voteID < dispute.votes.length);
        require(_choice <= dispute.numberOfChoices && _choice > 0, "The choice has to be less than or equal to the number of choices for the dispute.");
        require(dispute.votes[_voteID].account == msg.sender, "The caller has to own the vote.");
        require(dispute.votes[_voteID].commit == keccak256(abi.encodePacked(_choice, _salt)), "The commit must match the choice");
        require(!dispute.votes[_voteID].voted, "Vote already cast.");

        // Save the votes.
        dispute.votes[_voteID].choice = _choice;
        dispute.votes[_voteID].voted = true;
        

        // Update voteCounter.
        VoteCounter storage voteCounter = DisputeId2VoteCounter[_disputeID];
        voteCounter.counts[_choice] += 1;

        // update winningChoice
        if (_choice == voteCounter.winningChoice) { // Voted for the winning choice.
            if (voteCounter.tied) voteCounter.tied = false; // Potentially broke tie.
        } else { // Voted for another choice.
            if (voteCounter.counts[_choice] == voteCounter.counts[voteCounter.winningChoice]) { // Tie.
                if (!voteCounter.tied) voteCounter.tied = true;
            } else if (voteCounter.counts[_choice] > voteCounter.counts[voteCounter.winningChoice]) { // New winner.
                voteCounter.winningChoice = _choice;
                voteCounter.tied = false;
            }
        }
    }

    /** @dev Executes a specified dispute's ruling. UNTRUSTED.
     *  @param _disputeID The ID of the dispute.
     */
    function executeRuling(uint _disputeID) external onlyDuringPeriod(_disputeID, Period.execution) {
        Dispute storage dispute = disputes[_disputeID];
        require(!dispute.ruled, "Ruling already executed.");
        dispute.ruled = true;
        VoteCounter storage vote_counter = DisputeId2VoteCounter[_disputeID];
        uint winningChoice = vote_counter.tied ? 0 : vote_counter.winningChoice;
        uint winningCount = vote_counter.counts[winningChoice];
        dispute.arbitrated.rule(_disputeID, winningChoice);
        settleArbitrationFee(dispute, winningCount, winningChoice);
    }

    /** @dev Settlement of arbitration fees to the winning juror.
     *  @param dispute the dispute.
     */
    function settleArbitrationFee(Dispute storage dispute, uint winningCount, uint winningChoice) internal {
        uint ArbitrationFee = dispute.fees;
        uint voteNumber = dispute.votes.length;
        uint splitFee = ArbitrationFee / winningCount;
        for (uint j=0;j<voteNumber;j++) {
            Vote storage vote = dispute.votes[j];
            if (vote.voted && vote.choice == winningChoice) {
                payable(vote.account).transfer(splitFee);
            }
        }
    }

    /** @dev Gets the current ruling of a specified dispute.
     *  @param _disputeID The ID of the dispute.
     *  @return ruling The current ruling.
     */
    function currentRuling(uint _disputeID) public view override returns(uint ruling){
        require(_disputeID>0 && _disputeID <= disputes.length);
        VoteCounter storage vote_counter = DisputeId2VoteCounter[_disputeID];
        ruling = vote_counter.tied ? 0 : vote_counter.winningChoice;
    }

    /** @dev Gets the status of a specified dispute.
     *  @param _disputeID The ID of the dispute.
     *  @return status The status.
     */
    function disputeStatus(uint _disputeID) public view override returns(DisputeStatus status) {
        Dispute storage dispute = disputes[_disputeID];
        if (dispute.period < Period.vote) status = DisputeStatus.Waiting;
        else if (dispute.period < Period.execution) status = DisputeStatus.Arbitration;
        else status = DisputeStatus.Solved;
    }

    function getVotedCount(uint _disputeID) public view returns (uint) {
        Dispute storage dispute = disputes[_disputeID];
        uint voted_count = 0;
        for (uint j=0;j<dispute.votes.length;j++) {
            Vote storage vote = dispute.votes[j];
            if (vote.voted) {
                voted_count++;
            }
        }
        return voted_count;
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
            require(dispute.votes.length >= MIN_VOTES, "The minimum number of votes has not been met");
            require(
                block.timestamp - dispute.lastPeriodChange >= timesPerPeriod[uint(dispute.period)],
                "The commit period time has not passed yet and not every juror has committed yet."
            );
            dispute.period = Period.vote;
        } else if (dispute.period == Period.vote) {
            uint votedCount = getVotedCount(_disputeID);
            require(votedCount >= MIN_VOTES, "The minimum number of voted votes has not been met");
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