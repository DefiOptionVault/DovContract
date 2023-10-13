// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
// 옵션 매수자의 영수증 역할을 할 ERC20 컨트랙트

contract DovReceiptERC20 is ERC20PresetMinterPauser {
    using Strings for uint256;
    // put or long
    bool public isPut;
    // 행사가 정보
    uint256 public strike;
    // 만기일 정보
    uint256 public expiry;
    // 옵션 매수 컨트랙트 주소
    address public dov;
    // 기초자산의 symbol
    string public underlyingSymbol;
    // 담보의 symbol
    string public collateralSymbol;

    constructor() ERC20PresetMinterPauser("", ""){
    }

    function initialize(
        address _dov,
        bool _isPut,
        uint256 _strike,
        uint256 _expiry,
        string memory _underlyingSymbol,
        string memory _collateralSymbol,
        string memory _expirySymbol
    ) public {
        require(block.timestamp < _expiry, "Can't deploy an expired contract");

        dov = _dov;
        underlyingSymbol = _underlyingSymbol;
        collateralSymbol = _collateralSymbol;
        isPut = _isPut;
        strike = _strike;
        expiry = _expiry;

        string memory symbol = concatenate(_underlyingSymbol, "-");
        symbol = concatenate(symbol, _expirySymbol);
        symbol = concatenate(symbol, "-");
        symbol = concatenate(symbol, (strike / 1e18).toString());
        symbol = concatenate(symbol, isPut ? "-P" : "-C");

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
    }

    /**
     * code from dopex
     * @notice Returns a concatenated string of a and b
     * @param _a string a
     * @param _b string b
     */
    function concatenate(string memory _a, string memory _b)
    internal
    pure
    returns (string memory)
    {
        return string(abi.encodePacked(_a, _b));
    }
}
