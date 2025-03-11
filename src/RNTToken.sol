// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RNTToken is ERC20Permit, Ownable {
    constructor(address ido, address stake) 
        ERC20("RNT Token", "RNT") 
        ERC20Permit("RNT Token") 
        Ownable(stake) 
    {
        _mint(ido, 1_000_000 * 10**18);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}