// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./CarbonBase.sol";

contract ToCToken is ERC20 {
    CarbonBase public baseContract;
    mapping(bytes32 => bool) public coinageRecords;

    constructor(address baseAddress) ERC20("ToC Green Carbon Token", "ToC") {
        baseContract = CarbonBase(baseAddress);
    }

    function Coinage(
        bytes32 business,
        bytes32 place,
        bytes32 dev,
        bytes32 targetCode,
        bytes32 targetName,
        bytes32 targetMode,
        bytes32 targetType,
        uint targetNums,
        address businessAddr,
        address targetAddr
    ) public returns (bool) {
        require(baseContract.validCoinageAddress(address(this), msg.sender), "Not authorized coinage address");
        require(!coinageRecords[targetCode], "Coinage already recorded for this target");

        uint businessShare = (targetNums * 5) / 100;
        uint targetShare = targetNums - businessShare;

        _mint(businessAddr, businessShare);
        _mint(targetAddr, targetShare);

        coinageRecords[targetCode] = true;
        return true;
    }

    function ShowCoinage(uint beginTime, uint endTime) public view /*returns ()*/ {
        //todo
    }

    function StatsCoinage(uint beginTime, uint endTime) public view /*returns ()*/ {
        //todo
    }
}
