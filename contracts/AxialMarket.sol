// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";

contract AxialMarket is AutomationCompatibleInterface {
    enum CreditType {
        Ocean,
        Clean,
        Plastic
    }

    mapping(address => uint256) private userOffsets;
    uint256 private totalOffsets;
    uint256 marketReserveFund = 0;

    // Array to track admin addresses
    address[] public admins;

      // Modifier to check if the caller is an admin
    modifier onlyAdmin() {
        bool isAdmin = false;
        for (uint256 i = 0; i < admins.length; i++) {
            if (admins[i] == msg.sender) {
                isAdmin = true;
                break;
            }
        }
        require(isAdmin, "Only admins can call this function");
        _;
    }


    ERC20Burnable private oceanToken;
    ERC20Burnable private cleanToken;
    ERC20Burnable private plasticToken;

    address payable private axialDAO;

    constructor(
        address _oceanToken,
        address _cleanToken,
        address _plasticToken
    ) {
        oceanToken = ERC20Burnable(_oceanToken);
        cleanToken = ERC20Burnable(_cleanToken);
        plasticToken = ERC20Burnable(_plasticToken);
    }

    function updateAxialDAOAddress(
        address payable daoAddress
    ) public  onlyAdmin returns (bool) {
        axialDAO = daoAddress;
        return true;
    }

    function buyCreditTokens(
        CreditType creditType,
        uint256 amount
    ) public payable {
        require(msg.value == amount, "Transaction Amount should match the value of token");

        if (creditType == CreditType.Ocean) {
            oceanToken.transferFrom(address(this), msg.sender,  amount);
        } else if (creditType == CreditType.Clean) {
            cleanToken.transferFrom(address(this), msg.sender,  amount);
        } else if (creditType == CreditType.Plastic) {
            plasticToken.transferFrom(address(this), msg.sender,  amount);
        }

        userOffsets[msg.sender] += amount;
        totalOffsets += amount;
        marketReserveFund += msg.value;
    }

    function offsetTokens(
        uint256 amount,
        CreditType creditType
    ) public payable {
        require(userOffsets[msg.sender] >= amount, "Insufficient offsets");

        if (creditType == CreditType.Ocean) {
            require(
                oceanToken.balanceOf(msg.sender) >= amount,
                "Insufficient token balance"
            );
            oceanToken.burnFrom(msg.sender, amount);
        } else if (creditType == CreditType.Clean) {
            require(
                cleanToken.balanceOf(msg.sender) >= amount,
                "Insufficient token balance"
            );
            cleanToken.burnFrom(msg.sender, amount);
        } else if (creditType == CreditType.Plastic) {
            require(
                plasticToken.balanceOf(msg.sender) >= amount,
                "Insufficient token balance"
            );
            plasticToken.burnFrom(msg.sender, amount);
        }

        userOffsets[msg.sender] -= amount;
        totalOffsets -= amount;
    }

    function getUserOffsets(address user) public view returns (uint256) {
        return userOffsets[user];
    }

    function getTotalOffsets() public view returns (uint256) {
        return totalOffsets;
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
        if (marketReserveFund > 0) {
            upkeepNeeded = true;
        }
        return (upkeepNeeded, abi.encode(marketReserveFund));
    }

    // Chainlink Keeper method: performUpkeep
    function performUpkeep(bytes calldata performData) external override {
        uint256 marketFund = abi.decode(performData, (uint256));
        require(marketFund > 0, "Funds needs to be greater than 0 to trasnfer");

        axialDAO.transfer(marketFund);
    }
}
