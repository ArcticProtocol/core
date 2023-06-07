pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Burnable.sol";

contract VoluntaryCarbonCreditMarket {
    enum CreditType {
        Ocean,
        Clean,
        Plastic
    }

    mapping(address => uint256) private userOffsets;
    uint256 private totalOffsets;

    IERC20Burnable private oceanToken;
    IERC20Burnable private cleanToken;
    IERC20Burnable private plasticToken;

    constructor(
        address _oceanToken,
        address _cleanToken,
        address _plasticToken
    ) {
        oceanToken = IERC20Burnable(_oceanToken);
        cleanToken = IERC20Burnable(_cleanToken);
        plasticToken = IERC20Burnable(_plasticToken);
    }

    function buyCreditTokens(
        CreditType creditType,
        uint256 amount
    ) public payable {
        if (creditType == CreditType.Ocean) {
            oceanToken.transferFrom(msg.sender, address(this), amount);
        } else if (creditType == CreditType.Clean) {
            cleanToken.transferFrom(msg.sender, address(this), amount);
        } else if (creditType == CreditType.Plastic) {
            plasticToken.transferFrom(msg.sender, address(this), amount);
        }

        userOffsets[msg.sender] += amount;
        totalOffsets += amount;
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
}
