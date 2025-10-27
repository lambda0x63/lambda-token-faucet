// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LambdaToken is ERC20 {
    constructor() ERC20("Lambda Token", "LMDA") {
        // Mint 1,000,000 tokens to the contract deployer
        _mint(msg.sender, 1_000_000 * 10**decimals());
    }
}