// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

import "../src/Dov.sol";
import {RoundData, RoundStrikeData, WritePosition} from "../src/DovStruct.sol";

contract Functions is Test{
    Dov public dov;
    DovReceiptERC20 public implementation;

    // USDC 주소
    ERC20 public USDC = ERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);

    // 옵션 매도자 주소
    address public writer1 = address(0x1);
    address public writer2 = address(0x2);
    address public writer3 = address(0x3);

    // 옵션 매수자 주소 
    address public buyer1 = address(0x11);
    address public buyer2 = address(0x12);
    address public buyer3 = address(0x13);

    // admin 주소
    address public admin = address(this);

    string public underlyingSymbol = "ETH";
    string public collateralSymbol = "USDC";


    function setUp() public {
        dov = new Dov(
            "Dov Weekly ETH Put Option",
            "DOV-WEEK-ETH-PUT",
            underlyingSymbol,
            collateralSymbol,
            address(USDC)
        );

        vm.deal(address(writer1), 100000 ether);
        vm.deal(address(writer2), 100000 ether);
        vm.deal(address(writer3), 100000 ether);
        
        vm.deal(address(buyer1), 100000 ether);
        vm.deal(address(buyer2), 100000 ether);
        vm.deal(address(buyer3), 100000 ether);
        
        deal(address(USDC), address(writer1), 100000 * 1e6);
        deal(address(USDC), address(writer2), 100000 * 1e6);
        deal(address(USDC), address(writer3), 100000 * 1e6);
        
        deal(address(USDC), address(buyer1), 100000 * 1e6);
        deal(address(USDC), address(buyer2), 100000 * 1e6);
        deal(address(USDC), address(buyer3), 100000 * 1e6);
    }
    function _bootstrap() internal {
        uint256[] memory strikes = new uint256[](4);
        strikes[0] = 1600 * 1e18;
        strikes[1] = 1540 * 1e18;
        strikes[2] = 1500 * 1e18;
        strikes[3] = 1460 * 1e18;

        uint256 expiry = block.timestamp + 604800;

        string memory expirySymbol = "05OCT23";

        dov.bootstrap(strikes, expiry, expirySymbol);
    }

    function _updateOptionPrice() internal {
        uint256[] memory optionPrices = new uint256[](4);
        optionPrices[0] = 5464 * 1e16;
        optionPrices[1] = 3708 * 1e16;
        optionPrices[2] = 2993 * 1e16;
        optionPrices[3] = 2358 * 1e16;

        dov.updateOptionPrice(optionPrices);
        uint round = 1;
        uint price1 = dov.getRoundStrikeData(round, 0).optionPrice;
        uint price2 = dov.getRoundStrikeData(round, 1).optionPrice;
        uint price3 = dov.getRoundStrikeData(round, 2).optionPrice;
        uint price4 = dov.getRoundStrikeData(round, 3).optionPrice;

        assertEq(optionPrices[0], price1, "ERROR: option Price set");
        assertEq(optionPrices[1], price2, "ERROR: option Price set");
        assertEq(optionPrices[2], price3, "ERROR: option Price set");
        assertEq(optionPrices[3], price4, "ERROR: option Price set");
    }

    function _roundSetting() internal {
        _bootstrap();
        _updateOptionPrice();
    }
    
    function _deposit(address addr, uint amount) internal returns (uint tokenId){
        vm.startPrank(address(addr), address(addr));
        USDC.approve(address(dov), USDC.balanceOf(address(addr)));
        tokenId = dov.deposit(0, amount, address(addr));
        vm.stopPrank();
    }
    
    function _purchase(address addr, uint amount, uint strikeIndex1) internal returns (uint premium) {
        vm.startPrank(address(addr), address(addr));
        USDC.approve(address(dov), USDC.balanceOf(address(addr)));
        premium = dov.purchase(strikeIndex1, amount * 1e18, address(addr));
        vm.stopPrank();
    }

    function _round1() internal {
        _roundSetting();
        _deposit(address(writer1), 1600 * 10 * 1e18);
        _deposit(address(writer2), 1600 * 20 * 1e18);
        _deposit(address(writer3), 1600 * 30 * 1e18);
        _purchase(address(buyer1), 1, 0);
        _purchase(address(buyer2), 2, 0);
        _purchase(address(buyer3), 10, 0);
    }

    function _expireRound(uint settlementPrice) internal {
        _round1();
        uint expiry = dov.getRoundData(1).expiry;    
        // 만기날로 이동
        vm.warp(expiry + 1);
        dov.expire(settlementPrice);
    }

    function _withdraw(address addr, uint tokenId) internal returns(uint writerPnl) {
        vm.startPrank(address(addr), address(addr));
        writerPnl = dov.withdraw(tokenId, addr);
        vm.stopPrank();
    }


    function _settle(address addr) internal returns(uint pnl) {
        vm.startPrank(address(addr), address(addr));
        DovReceiptERC20 strikeToken = DovReceiptERC20(dov.getRoundStrikeData(1, 0).purchaseReceipt);
        uint balance = strikeToken.balanceOf(address(addr));
        strikeToken.approve(address(dov), balance);
        pnl = dov.settle(0, balance, 1, address(addr));
        vm.stopPrank();
    }

    function _settleExpectRevert(address addr) internal returns(uint pnl) {
        vm.startPrank(address(addr), address(addr));
        DovReceiptERC20 strikeToken = DovReceiptERC20(dov.getRoundStrikeData(1, 0).purchaseReceipt);
        uint balance = strikeToken.balanceOf(address(addr));
        strikeToken.approve(address(dov), balance);
        vm.expectRevert();
        pnl = dov.settle(0, balance, 1, address(addr));
        vm.stopPrank();
    }
}
