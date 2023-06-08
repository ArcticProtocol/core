// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract AxialCleanToken is ERC20Burnable {
    address public minter;

    constructor() ERC20("Axial Clean Energy Token", "ACT") {
        minter = msg.sender;
        _mint(_msgSender(), 1000000 * (10 ** decimals()));
    }

    function setAllowance(address spender, uint256 amount) public {
        this.approve(spender, amount);
    }

    function mint(address account, uint256 amount) public {
        require(msg.sender == minter, "Only the minter can mint tokens");
        _mint(account, amount);
    }
}
