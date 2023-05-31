//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract PokemonStatV2 is Ownable {

    string[] public StatType;

    function setStatsArray(string[] memory _statsArray) public returns(bool) {
        require(_statsArray.length > 0, "StatsContract: Empty stats array");
        StatType = _statsArray;
        return true;
    }

    function getStatsArray() public view returns (string[] memory) {
        return StatType;    //  [attack,defense,sp,hp,mp]
    }

    function getStatsArrayLength() public view returns (uint256) {
        return StatType.length;
    }
}

