// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {ERC721Burnable} from "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {Clones} from "openzeppelin-contracts//contracts/proxy/Clones.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";


import {RoundData, RoundStrikeData, WritePosition} from "./DovStruct.sol";
import {DovState} from "./DovState.sol";
import {DovReceiptERC20} from "./DovReceiptERC20.sol";

import "forge-std/Test.sol";


// 기본적으로 PUT 옵션
contract Dov is
    ERC721,
    ERC721Burnable,
    AccessControl,
    DovState
{
    constructor(
        string memory _name,
        string memory _symbol,
        string memory _underlyingSymbol,
        string memory _collateralSymbol,
        address _collateralToken
    ) ERC721(_name, _symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        underlyingSymbol = _underlyingSymbol;
        collateralSymbol = _collateralSymbol;
        collateralToken = IERC20(_collateralToken);
        
        receiptImplementation = address(new DovReceiptERC20());
    }

    /* Admin functions */

    /**
    strikes = [???, ???, ???, ??]
    expirySymbol = ddMMyy
    expiry = 1696512398
     */
    function bootstrap(
        uint256[] memory strikes,
        uint256 expiry,
        string memory expirySymbol
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint nextRound = currentRound + 1;

        // ADMIN이 실수로 expiry가 이미 끝난 상태로 만기설정을 하는것을 방지.
        _validate(block.timestamp < expiry);
        // 첫번째 라운드가 아닐경우 이전 라운드가 만기되었는지 확인
        if(currentRound > 0) {
            _validate(roundData[currentRound].expired);
        }

        // 다음 라운드 정보 설정
        roundData[nextRound].strikes = strikes;
        roundData[nextRound].startTime = block.timestamp;
        roundData[nextRound].expiry = expiry;

        // 다음 라운드로 진행
        currentRound = nextRound;

        // 다음 라운드의 행사가별 옵션 매수 토큰 컨트랙트 배포 및 초기화
        DovReceiptERC20 _receiptToken;
        uint strike;
        for (uint i = 0; i < strikes.length; i++) {
            strike = strikes[i];
            _receiptToken = DovReceiptERC20(
                Clones.clone(receiptImplementation)
            );

            _receiptToken.initialize(
                address(this),
                true,
                strike,
                expiry,
                underlyingSymbol,
                collateralSymbol,
                expirySymbol
            );

            roundStrikeData[currentRound][i].purchaseReceipt = address(_receiptToken);
        }
    }

    // 행사가별 옵션 가격 설정
    function updateOptionPrice(
        uint256[] memory optionPrices
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _roundNotExpired();
        _validate(block.timestamp < roundData[currentRound].expiry);

        for (uint i = 0; i < optionPrices.length; i++) {
            roundStrikeData[currentRound][i].optionPrice = optionPrices[i];
        }
    }

    // 옵션 만기 설정, 행사가 설정
    function expire(
        uint256 _settlementPrice
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // 한번만 만기 설정을 할 수 있고, 만기 전에는 만기 설정을 할 수 없음.
        // TODO: 테스트용으로 배포할때는 언제든 만기설정을 할 수 있도록 수정
        _roundNotExpired();
        require(block.timestamp > roundData[currentRound].expiry, "Optoin Not Expired Yet");
        
        // 만기 설정
        roundData[currentRound].expired = true;
        roundData[currentRound].settlementPrice = _settlementPrice;


    }

    /* User functions */
    // 옵션 매도 함수
    function deposit(
        uint _strikeIndex,
        uint amount,
        address to
    ) external returns (uint tokenId) {
        // validation
        _roundNotExpired();
        _isEligible();
        _valueNotZero(amount);

        uint strike = roundData[currentRound].strikes[_strikeIndex];
        _valueNotZero(strike);

        // 옵션 매도자로부터 담보 입금
        collateralToken.transferFrom(msg.sender, address(this), amount * 1e6 / 1e18);

        // roundData, roundStrikeData 업데이트
        roundData[currentRound].totalCollateralBalance += amount;
        roundStrikeData[currentRound][_strikeIndex].totalCollateral += amount;

        // 포지션 영수증 발급 (ERC-721)
        tokenId = _counter;
        _counter += 1;
        _safeMint(to, tokenId);

        // 매도 포지션 조회 구조체 업데이트
        writePositions[tokenId] = WritePosition({
            round: currentRound,
            strike: strike,
            collateralAmount: amount,
            strikeIndex: _strikeIndex
        });
    }

    // 옵션 매수 함수, amount precision: 1e18
    function purchase(
        uint strikeIndex,
        uint amount,
        address to
    ) external returns (uint premium) {
        // validation
        _roundNotExpired();
        _isEligible();
        _valueNotZero(amount);
        _optionPriceSet(strikeIndex);

        uint expiry = roundData[currentRound].expiry;
        _validate(expiry > block.timestamp);

        uint strike = roundData[currentRound].strikes[strikeIndex];
        _valueNotZero(strike);

        // 옵션 매수를 위한 담보금이 충분히 존재하는지 확인
        uint availableCollateral = roundStrikeData[currentRound][strikeIndex].totalCollateral 
                - roundStrikeData[currentRound][strikeIndex].activeCollateral;
        
        // lock해야 하는 금액의 양 (PUT)
        // 옵션 매수자의 max profit: strike * amount
        // round down발생 가능..
        uint toLockCollateral = (strike * amount) / UNDERLYING_PRECISION;
        
        require(availableCollateral > toLockCollateral, "DOV: not enough collateral");

        // premium 입금
        premium = roundStrikeData[currentRound][strikeIndex].optionPrice * amount / DEFAULT_PRECISION;
        collateralToken.transferFrom(msg.sender, address(this), premium * 1e6 / 1e18);

        // roundStrikeData 업데이트
        roundStrikeData[currentRound][strikeIndex].totalPremium += premium;
        roundStrikeData[currentRound][strikeIndex].activeCollateral += toLockCollateral;
        // 자본의 효율을 위해서 옵션 매수로 받은 프리미엄도 담보로 사용
        roundStrikeData[currentRound][strikeIndex].totalCollateral += premium;

        // 옵션 매수 영수증 발급
        DovReceiptERC20(roundStrikeData[currentRound][strikeIndex].purchaseReceipt).mint(
            to,
            amount
        );
    }

    function withdraw(
        uint tokenId, 
        address to
    ) external returns(uint256 writerPnl){
        _isEligible();
        
        uint round = writePositions[tokenId].round;
        uint strikePrice = writePositions[tokenId].strike;
        uint strikeIndex = writePositions[tokenId].strikeIndex;
        uint collateralAmount = writePositions[tokenId].collateralAmount;
        
        uint settlementPrice = roundData[round].settlementPrice;
        uint expiry = roundData[round].expiry;

        uint totalCollateral = roundStrikeData[round][strikeIndex].totalCollateral;
        uint totalPremium = roundStrikeData[round][strikeIndex].totalPremium;
        uint activeCollateral = roundStrikeData[round][strikeIndex].activeCollateral;
        
        // 올바른 상황에 withdraw가 되고 있는지 validate
        _roundExpired(round);
        _valueNotZero(strikePrice);
        _valueNotZero(settlementPrice);
        _validate(block.timestamp > expiry) ;
        
        // 포지션에 대한 NFT를 소각, 내부 로직에 msg.sender가 해당 NFT소유자인지 검증하는 로직이 존재
        burn(tokenId);

        uint share = collateralAmount * 1e18 / (totalCollateral - (totalPremium));
        uint buyerPnl = 0;

        if (settlementPrice < strikePrice) {
            uint amount = activeCollateral *  UNDERLYING_PRECISION / strikePrice;
            buyerPnl = (strikePrice - settlementPrice) * amount / 1e18;
        }

        // 매도자의 PnL송금
        writerPnl = (totalCollateral - buyerPnl) * share / 1e18 / 1e12;
        collateralToken.transfer(to, writerPnl);
    }

    function settle(
        uint strikeIndex,
        uint amount,
        uint round,
        address to
    ) external returns (uint pnl) {
        _isEligible();
        _roundExpired(round);

        uint strikePrice = roundData[round].strikes[strikeIndex];
        DovReceiptERC20 strikeToken = DovReceiptERC20(
            roundStrikeData[round][strikeIndex].purchaseReceipt
        );

        // msg.sender가 amount만큼을 매수했는지 확인 및 소각
        _validate(strikeToken.balanceOf(msg.sender) >= amount);
        strikeToken.burnFrom(msg.sender, amount);

        // PUT옵션 기준
        uint settlementPrice = roundData[round].settlementPrice;
        require(settlementPrice < strikePrice, "DOV: Your pnl is 0");

        pnl = (strikePrice - settlementPrice) * amount / 1e18;
        collateralToken.transfer(to, pnl / 1e12);
    }


    /* Validation functions */
    function _roundExpired(uint round) internal view {
        require(roundData[round].expired, "DOV: round not expired");
    }

    function _roundExpired() internal view {
        require(roundData[currentRound].expired, "DOV: round not expired");
    }
    
    function _optionPriceSet(uint strikeIndex) internal view {
        require(roundStrikeData[currentRound][strikeIndex].optionPrice != 0, "DOV: strike not active");
    }

    function _valueNotZero(uint value) internal view {
        require(value > 0, "DOV: value must greater than 0");
    }

    function _roundNotExpired() internal view {
        require(!roundData[currentRound].expired, "DOV: round expired");
    }

    function _isEligible() internal view {
        require(msg.sender == tx.origin, "DOV: This contract only interact with EOA");
    }


    function _validate(bool _condition) private pure {
        require(_condition, "DOV: condition doesn't match");
    }


    /* Status functions */
    function getRoundData(uint round) external view returns(RoundData memory) {
        return roundData[round];
    }

    function getRoundStrikeData(uint round, uint strike) external view returns(RoundStrikeData memory){
        return roundStrikeData[round][strike];
    }

    function getWritePosition(uint tokenId) external view returns(WritePosition memory) {
        return writePositions[tokenId];
    }


    // AccessControl을 사용하기 위해서 오버라이드 해야함.
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
