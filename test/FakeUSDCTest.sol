// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

import "../src/FakeUSDC.sol";
contract Functions is Test{

    FakeUSDC public USDC;
    constructor() {
        USDC = new FakeUSDC("USDC", "USD Coin");
    }
    function testMint() external {
        USDC.mint(address(this), 100 * 1e6);
        assertEq(USDC.balanceOf(address(this)), 100 * 1e6, "mint fail");
        console.log(USDC.balanceOf(address(this)));
    }
}