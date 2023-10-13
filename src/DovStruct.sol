// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

    // 라운드에 대한 데이터
    struct RoundData {
        // 라운드 만기 여부 체크
        bool expired;
        // 라운드 시작 시간, 만기 시간 (unix timestamp)
        uint startTime;
        uint expiry;
        // 정산가
        uint settlementPrice;
        // 해당 라운드에 모인 총 담보금.
        uint256 totalCollateralBalance;
        uint[] strikes;
    }

    // 라운드의 행사가별로 모아야 하는 데이터
    struct RoundStrikeData {
        // 옵션매수시 발행해주는 토큰의 주소
        address purchaseReceipt;
        // 담보의 총 금액
        uint totalCollateral;
        // lock된 담보의 총 금액
        uint activeCollateral;
        // 행사가에 모인 프리미엄의 총 양
        uint totalPremium;
        // 옵션 가격
        uint optionPrice;
    }

    // 옵션 매도자의 포지션을 추적하는 구조체
    struct WritePosition {
        // 몇번째 라운드에서 매도했는지
        uint256 round;
        // 어떤 행사가에 매도했는지
        uint256 strike;
        // 얼마나 매도했는지
        uint256 collateralAmount;
    }