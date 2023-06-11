// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract AxialDAOMembership is ERC721URIStorage {
    address public axialMarketContract;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    modifier onlyOwner() {
        require(
            msg.sender == axialMarketContract,
            "Only the AxialDAO contract can call this function"
        );
        _;
    }

    constructor(
        address _axialMarketContract
    ) ERC721("AxialDAOMembership", "ADAO") {
        axialMarketContract = _axialMarketContract;
    }

    function mintMembership(
        address to,
        string memory tokenURI
    ) external onlyOwner {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();

        _safeMint(to, newItemId);
        _setTokenURI(newItemId, tokenURI);
    }
}
