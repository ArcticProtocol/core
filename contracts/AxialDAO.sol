// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";
import "./ProjectTracker.sol";

contract AxialDAO is Ownable, AutomationCompatibleInterface, KeeperCompatible {
    using Address for address;

    // Proposal struct
    struct Proposal {
        uint256 id;
        address creator;
        string projectId;
        string goal;
        uint256 fundingRequired;
        uint256 fundingReceived;
        uint256 startTime;
        uint256 endTime;
        bool votingExpired;
        bool approved;
        uint256 yesVotes;
        uint256 noVotes;
        mapping(address => bool) voted;
    }

    struct ProposalResponse {
        uint256 id;
        address creator;
        string projectId;
        string goal;
        uint256 fundingRequired;
        uint256 fundingReceived;
        uint256 startTime;
        uint256 endTime;
        bool votingExpired;
        bool approved;
        uint256 yesVotes;
        uint256 noVotes;
    }

    // Other contract references
    ProjectTracker private projectTrackerContract;

    // Proposal variables
    uint256 public proposalCounter;
    mapping(uint256 => Proposal) public proposals;

    // DAO treasury
    uint256 public daoTreasury;

    constructor(address _projectTrackerAddress) {
        projectTrackerContract = ProjectTracker(_projectTrackerAddress);
        proposalCounter = 0;
        daoTreasury = 0;
    }

    // Function to create a new proposal
    function createProposal(
        string memory _goal,
        uint256 _fundingRequired,
        uint256 _duration,
        string memory projectId
    ) public {
        require(_duration > 0, "Duration must be greater than zero");
        require(
            _fundingRequired > 0,
            "Funding required must be greater than zero"
        );

        uint256 endTime = block.timestamp + _duration;

        Proposal storage newProposal = proposals[proposalCounter];

        newProposal.id = proposalCounter;
        newProposal.projectId = projectId;
        newProposal.creator = msg.sender;
        newProposal.goal = _goal;
        newProposal.fundingRequired = _fundingRequired;
        newProposal.fundingReceived = 0;
        newProposal.startTime = block.timestamp;
        newProposal.endTime = endTime;
        newProposal.votingExpired = false;
        newProposal.approved = false;
        newProposal.yesVotes = 0;
        newProposal.noVotes = 0;

        proposalCounter++;
    }

    // Function to vote on a proposal
    function vote(uint256 _proposalId, bool _approve) public {
        require(_proposalId < proposalCounter, "Invalid proposal ID");
        Proposal storage proposal = proposals[_proposalId];
        require(proposal.votingExpired == false, "Proposal Voting has Expired");
        require(
            proposal.voted[msg.sender] == false,
            "Address has already voted"
        );

        if (_approve) {
            proposal.yesVotes++;
        } else {
            proposal.noVotes++;
        }

        proposal.voted[msg.sender] = true;
    }

    // Function to expire a proposal and trigger approval or rejection
    function expireProposalVoting(uint256 _proposalId) internal returns (bool) {
        Proposal storage proposal = proposals[_proposalId];
        if (
            _proposalId > proposalCounter ||
            proposal.votingExpired == true ||
            block.timestamp <= proposal.endTime
        ) {
            return false;
        }

        proposal.votingExpired = true;
        proposal.approved = proposal.yesVotes > proposal.noVotes;

        return true;
    }

    function getProposalById(
        uint256 _proposalId
    ) external view returns (ProposalResponse memory) {
        Proposal storage proposal = proposals[_proposalId];
        ProposalResponse memory response = ProposalResponse({
            id: proposal.id,
            projectId: proposal.projectId,
            creator: proposal.creator,
            goal: proposal.goal,
            fundingRequired: proposal.fundingRequired,
            fundingReceived: proposal.fundingReceived,
            startTime: proposal.startTime,
            endTime: proposal.endTime,
            votingExpired: proposal.votingExpired,
            approved: proposal.approved,
            yesVotes: proposal.yesVotes,
            noVotes: proposal.noVotes
        });

        return response;
    }

    // Function to check if a proposal has votingExpired
    function checkProjectFundingElligible(
        uint256 _proposalId
    ) internal view returns (bool) {
        Proposal storage _proposal = proposals[_proposalId];
        return
            _proposal.votingExpired &&
            (_proposal.fundingRequired - _proposal.fundingReceived > 0);
    }

    // Function to check if a proposal is approved
    function checkApproved(uint256 _proposalId) external view returns (bool) {
        return proposals[_proposalId].approved;
    }

    // Chainlink Keeper method: checkUpkeep
    function checkUpkeep(
        bytes calldata /*checkData*/
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory /*performData*/)
    {
        uint256 proposalId = 0;
        for (uint256 i = 0; i < proposalCounter; i++) {
            if (checkProjectFundingElligible(i)) {
                proposalId = i;
                upkeepNeeded = true;
                break;
            }
        }
        return (upkeepNeeded, abi.encode(proposalId));
    }

    // Chainlink Keeper method: performUpkeep
    function performUpkeep(bytes calldata performData) external override {
        uint256 proposalId = abi.decode(performData, (uint256));
        Proposal storage proposal = proposals[proposalId];
        require(
            block.timestamp >= proposal.endTime,
            "Proposal has not yet votingExpired"
        );

        proposal.approved = proposal.yesVotes > proposal.noVotes;

        if (
            proposal.approved &&
            ((proposal.fundingRequired - proposal.fundingReceived > 0))
        ) {
            // Expire the voting proposal as a first step
            if (!proposal.votingExpired) {
                expireProposalVoting(proposalId);
            }

            if (daoTreasury >= proposal.fundingRequired) {
                projectTrackerContract.fundProject(
                    proposal.projectId,
                    proposal.fundingRequired
                );
                daoTreasury -= proposal.fundingRequired;
                proposal.fundingReceived += proposal.fundingRequired;
            } else {
                // Funding goal not met, wait until sufficient funds are available
            }
        }
    }
}
