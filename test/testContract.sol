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
        
        deal(address(USDC), address(writer1), 10000000 * 1e6);
        deal(address(USDC), address(writer2), 10000000 * 1e6);
        deal(address(USDC), address(writer3), 10000000 * 1e6);
        
        deal(address(USDC), address(buyer1), 10000000 * 1e6);
        deal(address(USDC), address(buyer2), 10000000 * 1e6);
        deal(address(USDC), address(buyer3), 10000000 * 1e6);
    }

    function testCreation() external{
        console.log("Receipt proxy target:",address(implementation));
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
        console.log("strikes[0]", strikes[0]);
        console.log("strikes[1]", strikes[1]);
        console.log("strikes[2]", strikes[2]);
        console.log("strikes[3]", strikes[3]);

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
        optionPrices[0] = 5464 * 1e4;
        optionPrices[1] = 3708 * 1e4;
        optionPrices[2] = 2993 * 1e4;
        optionPrices[3] = 2358 * 1e4;

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
        
        console.log("Before Deposit writer1's balance:", USDC.balanceOf(address(writer1)));
        uint tokenId = _deposit(address(writer1), 100 * 1e6);
        console.log("After Deposit writer1's balance:", USDC.balanceOf(address(writer1)));

        WritePosition memory writePosition = dov.getWritePosition(tokenId);
        console.log("writePosition.round:", writePosition.round);
        console.log("writePosition.strike:", writePosition.strike);
        console.log("writePosition.collateralAmount:", writePosition.collateralAmount);

        assertEq(writePosition.round, 1, "ERROR: WritePosition round");
        assertEq(writePosition.strike, 1600 * 1e18, "ERROR: WritePosition strike");
        assertEq(writePosition.collateralAmount, 100 * 1e6, "ERROR: WritePosition collateralAmount");
    }
    
    function _purchase(address addr, uint amount) internal returns (uint premium) {
        vm.startPrank(address(buyer1), address(buyer1));
        USDC.approve(address(dov), USDC.balanceOf(address(addr)));
        premium = dov.purchase(0, amount * 1e18, address(addr));
        vm.stopPrank();
    }

    function testPurchase() external {
        _roundSetting();
        _deposit(address(writer1), 1600 * 10 * 1e6);
        _deposit(address(writer2), 1600 * 20 * 1e6);
        _deposit(address(writer3), 1600 * 30 * 1e6);

        uint premium;
        premium = _purchase(address(buyer1), 1);
        console.log("paied premium:", premium);
        assertEq(premium, 5464 * 1e4 * 1, "ERROR: premium not match");
        premium = _purchase(address(buyer2), 2);
        console.log("paied premium:", premium);
        assertEq(premium, 5464 * 1e4 * 2, "ERROR: premium not match");
        premium = _purchase(address(buyer3), 10);
        console.log("paied premium:", premium);
        assertEq(premium, 5464 * 1e4 * 10, "ERROR: premium not match");

        address purchaseReceipt = dov.getRoundStrikeData(1, 0).purchaseReceipt;
        assertEq(premium, 5464 * 1e4 * 10, "ERROR: premium not match");
        assertEq(premium, 5464 * 1e4 * 10, "ERROR: premium not match");
        assertEq(premium, 5464 * 1e4 * 10, "ERROR: premium not match");

        uint bal1 = ERC20(purchaseReceipt).balanceOf(buyer1);
        uint bal2 = ERC20(purchaseReceipt).balanceOf(buyer2);
        uint bal3 = ERC20(purchaseReceipt).balanceOf(buyer3);

        console.log("buyer1's receipt:", bal1);
        console.log("buyer2's receipt:", bal2);
        console.log("buyer3's receipt:", bal3);

        assertEq(bal1, 1 * 1e18, "receipt doesn't match");
        assertEq(bal2, 2 * 1e18, "receipt doesn't match");
        assertEq(bal3, 10 * 1e18, "receipt doesn't match");
    }
}
