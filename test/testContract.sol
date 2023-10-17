// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

import "../src/Dov.sol";
import {RoundData, RoundStrikeData, WritePosition} from "../src/DovStruct.sol";

contract testContract is Test{
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
        
        // 10,000,000 USDC
        deal(address(USDC), address(writer1), 10000000 * 1e6);
        deal(address(USDC), address(writer2), 10000000 * 1e6);
        deal(address(USDC), address(writer3), 10000000 * 1e6);
        
        deal(address(USDC), address(buyer1), 10000000 * 1e6);
        deal(address(USDC), address(buyer2), 10000000 * 1e6);
        deal(address(USDC), address(buyer3), 10000000 * 1e6);
    }

    function testCreation() external{
        console.log("Receipt proxy target:", dov.receiptImplementation());
        console.log("dov optoin vault:", address(dov));
        console.log("underlyingSymbol:", dov.underlyingSymbol());
        console.log("collateralSymbol:", dov.collateralSymbol());
        console.log("DEFAULT ADMIN TRUE:", dov.hasRole(0x00, address(this)));

        assertEq(underlyingSymbol, dov.underlyingSymbol(), "underlying symbol not match");
        assertEq(collateralSymbol, dov.collateralSymbol(), "collateral symbol not match");
        assertTrue(dov.hasRole(0x00, address(this)), "Non admin");
    }

    // current eth: 1649$
    function testBootstrap() external {
        uint256[] memory strikes = new uint256[](4);
        strikes[0] = 1600 * 1e18;
        strikes[1] = 1540 * 1e18;
        strikes[2] = 1500 * 1e18;
        strikes[3] = 1460 * 1e18;

        uint256 expiry = block.timestamp + 604800;

        string memory expirySymbol = "05OCT23";

        dov.bootstrap(strikes, expiry, expirySymbol);

        uint round = dov.currentRound();
        RoundData memory roundData = dov.getRoundData(round);
        RoundStrikeData memory roundStrikeData = dov.getRoundStrikeData(round, 1);
        console.log("current round:", round);
        console.log("round startTime:", roundData.startTime);
        console.log("round expiry:", roundData.expiry);

        assertEq(round, 1, "round not set");
        assertEq(roundData.startTime, block.timestamp, "start Time not same");
        assertEq(roundData.expiry, block.timestamp + 604800, "expiry Time not same");

        strikes = roundData.strikes;
        emit log_named_decimal_uint("strikes[0]", strikes[0], 18);
        emit log_named_decimal_uint("strikes[1]", strikes[1], 18);
        emit log_named_decimal_uint("strikes[2]", strikes[2], 18);
        emit log_named_decimal_uint("strikes[3]", strikes[3], 18);

        address purchaseReceipt = roundStrikeData.purchaseReceipt;
        console.log("round 1, strike 1 purchase receipt:", purchaseReceipt);
        assertFalse(purchaseReceipt == address(0x0), "purchase receipt contract not initialized");
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

    function testDeposit() external {
        _roundSetting();
        
        emit log_named_decimal_uint("Before Deposit writer1's balance:", USDC.balanceOf(address(writer1)), 6);
        uint tokenId = _deposit(address(writer1), 100 * 1e18);
        emit log_named_decimal_uint("After Deposit writer1's balance:", USDC.balanceOf(address(writer1)), 6);

        WritePosition memory writePosition = dov.getWritePosition(tokenId);
        console.log("writePosition.round:", writePosition.round);
        emit log_named_decimal_uint("writePosition.strike:", writePosition.strike, 18);
        emit log_named_decimal_uint("writePosition.collateralAmount:", writePosition.collateralAmount, 18);

        assertEq(writePosition.round, 1, "ERROR: WritePosition round");
        assertEq(writePosition.strike, 1600 * 1e18  , "ERROR: WritePosition strike");
        assertEq(writePosition.collateralAmount, 100 * 1e18, "ERROR: WritePosition collateralAmount");
    }
    
    function _purchase(address addr, uint amount) internal returns (uint premium) {
        vm.startPrank(address(addr), address(addr));
        USDC.approve(address(dov), USDC.balanceOf(address(addr)));
        premium = dov.purchase(0, amount * 1e18, address(addr));
        vm.stopPrank();
    }

    function testPurchase() external {
        _roundSetting();
        _deposit(address(writer1), 1600 * 10 * 1e18);
        _deposit(address(writer2), 1600 * 20 * 1e18);
        _deposit(address(writer3), 1600 * 30 * 1e18);

        uint premium;
        premium = _purchase(address(buyer1), 1);
        emit log_named_decimal_uint("paied premium:", premium, 18);
        assertEq(premium, 5464 * 1e16 * 1, "ERROR: premium not match");
        premium = _purchase(address(buyer2), 2);
        emit log_named_decimal_uint("paied premium:", premium, 18);
        assertEq(premium, 5464 * 1e16 * 2, "ERROR: premium not match");
        premium = _purchase(address(buyer3), 10);
        emit log_named_decimal_uint("paied premium:", premium, 18);
        assertEq(premium, 5464 * 1e16 * 10, "ERROR: premium not match");

        address purchaseReceipt = dov.getRoundStrikeData(1, 0).purchaseReceipt;

        uint bal1 = ERC20(purchaseReceipt).balanceOf(buyer1);
        uint bal2 = ERC20(purchaseReceipt).balanceOf(buyer2);
        uint bal3 = ERC20(purchaseReceipt).balanceOf(buyer3);

        emit log_named_decimal_uint("buyer1's receipt", bal1, 18);
        emit log_named_decimal_uint("buyer2's receipt", bal2, 18);
        emit log_named_decimal_uint("buyer3's receipt", bal3, 18);

        assertEq(bal1, 1 * 1e18, "receipt doesn't match");
        assertEq(bal2, 2 * 1e18, "receipt doesn't match");
        assertEq(bal3, 10 * 1e18, "receipt doesn't match");
    }

    function _round1() internal {
        _roundSetting();
        _deposit(address(writer1), 1600 * 10 * 1e18);
        _deposit(address(writer2), 1600 * 20 * 1e18);
        _deposit(address(writer3), 1600 * 30 * 1e18);
        _purchase(address(buyer1), 1);
        _purchase(address(buyer2), 2);
        _purchase(address(buyer3), 10);
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

    function testWithdraw_1600() external {
        emit log_named_decimal_uint("before writer1's balance", USDC.balanceOf(address(writer1)), 6);
        emit log_named_decimal_uint("before writer2's balance", USDC.balanceOf(address(writer2)), 6);
        emit log_named_decimal_uint("before writer3's balance", USDC.balanceOf(address(writer3)), 6);

        _expireRound(1600 * 1e18);

        uint totalCollateral = dov.getRoundStrikeData(1, 0).totalCollateral;

        // writer1:writer2:writer3=1:2:3
        uint pnl = _withdraw(address(writer1), 0);
        assertTrue((totalCollateral / 6 / 1e12) == pnl, "pnl doesn't match");
        pnl = _withdraw(address(writer2), 1);
        assertTrue((totalCollateral * 2 / 6 / 1e12) == pnl, "pnl doesn't match");
        pnl = _withdraw(address(writer3), 2);
        assertTrue((totalCollateral * 3 / 6 / 1e12) == pnl, "pnl doesn't match");

        emit log_named_decimal_uint("after writer1's balance", USDC.balanceOf(address(writer1)), 6);
        emit log_named_decimal_uint("after writer2's balance", USDC.balanceOf(address(writer2)), 6);
        emit log_named_decimal_uint("after writer3's balance", USDC.balanceOf(address(writer3)), 6);
    }

    function testWithdraw_1400() external {
        emit log_named_decimal_uint("before writer1's balance", USDC.balanceOf(address(writer1)), 6);
        emit log_named_decimal_uint("before writer2's balance", USDC.balanceOf(address(writer2)), 6);
        emit log_named_decimal_uint("before writer3's balance", USDC.balanceOf(address(writer3)), 6);
        
        _expireRound(1400 * 1e18);
        uint totalCollateral = dov.getRoundStrikeData(1, 0).totalCollateral;
        
        // totalCollateral - buyerPnl
        // (1600 - 1400) * (1 + 2 + 10) = 200 * 13 = 2600$ 손해
        uint pnl = _withdraw(address(writer1), 0);
        assertTrue(((totalCollateral - 2600 * 1e18) / 6 / 1e12) == pnl, "pnl doesn't match");
        pnl = _withdraw(address(writer2), 1);
        assertTrue(((totalCollateral - 2600 * 1e18) * 2 / 6 / 1e12) == pnl, "pnl doesn't match");
        pnl = _withdraw(address(writer3), 2);
        assertTrue(((totalCollateral - 2600 * 1e18) * 3 / 6 / 1e12) == pnl, "pnl doesn't match");
        
        emit log_named_decimal_uint("after writer1's balance", USDC.balanceOf(address(writer1)), 6);
        emit log_named_decimal_uint("after writer2's balance", USDC.balanceOf(address(writer2)), 6);
        emit log_named_decimal_uint("after writer3's balance", USDC.balanceOf(address(writer3)), 6);
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

    function testSettle_1600() external {
        _expireRound(1601 * 1e18);
        _settleExpectRevert(address(buyer1));
        _settleExpectRevert(address(buyer2));
        _settleExpectRevert(address(buyer3));
    }

    function testSettle_1400() external {
        emit log_named_decimal_uint("before buyer1's balance", USDC.balanceOf(address(buyer1)), 6);
        emit log_named_decimal_uint("before buyer2's balance", USDC.balanceOf(address(buyer2)), 6);
        emit log_named_decimal_uint("before buyer3's balance", USDC.balanceOf(address(buyer3)), 6);
        
        _expireRound(1400 * 1e18);

        // pnl = (1600-1400) * amount
        uint pnl = _settle(address(buyer1));
        assertEq(pnl , 200 * 1 * 1e18, "pnl doesn't match");
        pnl =_settle(address(buyer2));
        assertEq(pnl, 200 * 2 * 1e18, "pnl doesn't match");
        pnl =_settle(address(buyer3));
        assertEq(pnl, 200 * 10 * 1e18, "pnl doesn't match");

        emit log_named_decimal_uint("after buyer1's balance", USDC.balanceOf(address(buyer1)), 6);
        emit log_named_decimal_uint("after buyer2's balance", USDC.balanceOf(address(buyer2)), 6);
        emit log_named_decimal_uint("after buyer3's balance", USDC.balanceOf(address(buyer3)), 6);
    }
}
