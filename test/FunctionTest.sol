// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

import "../src/Dov.sol";
import "./functions.sol";
import {RoundData, RoundStrikeData, WritePosition} from "../src/DovStruct.sol";

contract FunctionTest is Test, Functions{



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

    function testPurchase() external {
        _roundSetting();
        _deposit(address(writer1), 1600 * 10 * 1e18);
        _deposit(address(writer2), 1600 * 20 * 1e18);
        _deposit(address(writer3), 1600 * 30 * 1e18);

        uint premium;
        premium = _purchase(address(buyer1), 1, 0);
        emit log_named_decimal_uint("paied premium:", premium, 18);
        assertEq(premium, 5464 * 1e16 * 1, "ERROR: premium not match");
        premium = _purchase(address(buyer2), 2, 0);
        emit log_named_decimal_uint("paied premium:", premium, 18);
        assertEq(premium, 5464 * 1e16 * 2, "ERROR: premium not match");
        premium = _purchase(address(buyer3), 10, 0);
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