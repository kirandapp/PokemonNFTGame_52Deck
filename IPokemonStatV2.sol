//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


interface IPokemonStatV2 {

    // string[] public StatType;

    function setStatsArray(string[] memory _statsArray) external returns(bool);

    function getStatsArray() external view returns (string[] memory);

    function getStatsArrayLength() external view returns (uint256);
    // function getStatsStruct() public view returns (PokemonStats memory) {
    //     PokemonStats memory ps = PokemonStats;
    //     return ps;
    // }
}

