// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract FakeUSDC is ERC20 {
    // symbol: USDC
    // name: USD Coin
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol){
        
    }

    // USDC가 공짜?!?!??!?!?!??ㅋㅋ
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function burn(address account, uint256 amount) public {
        _burn(account, amount);
    }
}

//0xe059aA96255990826D0d62c62462Feea47AF82a7