pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Burnable.sol";

contract AxialMarket {
    enum CreditType {
        Ocean,
        Clean,
        Plastic
    }

    mapping(address => uint256) private userOffsets;
    uint256 private totalOffsets;
    uint256 marketReserveFund = 0;


    IERC20Burnable private oceanToken;
    IERC20Burnable private cleanToken;
    IERC20Burnable private plasticToken;

    address payable private axialDAO;

    constructor(
        address _oceanToken,
        address _cleanToken,
        address _plasticToken,
        address _axialDAOAddress
    ) {
        oceanToken = IERC20Burnable(_oceanToken);
        cleanToken = IERC20Burnable(_cleanToken);
        plasticToken = IERC20Burnable(_plasticToken);
    }

    function updateAxialDAOAddress(address daoAddress) public onlyAdmin returns (bool){
        axialDAO = _axialDAOAddress;
        return true;
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
    if(marketReserveFund > 0){
        upkeepNeeded = true;
    }
    return (upkeepNeeded, abi.encode(marketReserveFund));
}

// Chainlink Keeper method: performUpkeep
function performUpkeep(bytes calldata performData) external override {
    uint256 marketFund = abi.decode(performData, (uint256));
    require(marketFund > 0 , "Funds needs to be greater than 0 to trasnfer")

    axialDAO.transfer(marketFund);
}
