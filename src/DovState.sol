// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {RoundData, RoundStrikeData, WritePosition} from "./DovStruct.sol";

abstract contract DovState {
    // collateralToken(USDC)의 주소
    IERC20 public collateralToken;

    // 기초자산의 symbol => ETH or ARB or something
    string public underlyingSymbol;

    // 담보의 symbol => USDC
    string public collateralSymbol;


    // 옵션 매수자의 포지션을 증명하는 토큰의 proxy target address
    address public receiptImplementation;

    // 현재 라운드
    uint public currentRound;

    // 담보금(USDC)의 precision
    uint256 internal constant COLLATERAL_PRECISION = 1e6;

    // 기초자산(ETH)의 precision
    uint256 internal constant UNDERLYING_PRECISION = 1e18;

    uint256 internal constant DEFAULT_PRECISION = 1e18;

    // round로 RoundData 조회
    // roundData[1] => round1의 라운드 정보 조회
    mapping(uint256 => RoundData) internal roundData;

    // round로 RoundStrikeData조회
    // roundStrikeData[1][2] => round1의 2번째 행사가에 대한 정보 조회
    mapping(uint256 => mapping(uint256 => RoundStrikeData)) internal roundStrikeData;

    // tokenId로 매도 포지션 조회
    // writePositions[1] => ERC-721(NFT)토큰의 토큰id가 1인 녀석의 WritePosition을 조회
    // tokenId는 validation이 필요함.
    mapping(uint256 => WritePosition) internal writePositions;

    // ERC-721 tokenId counter

    uint internal _counter;
}
