//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./PokemonGameV3.sol";

contract PokemonStatV3 is Ownable {
    
    address public pokemonGameAddress;
    struct Stats {
        uint256 attack;
        uint256 defense;
        uint256 sp;
        uint256 hp;
        uint256 mp;
        uint256 battletype;
    }

    mapping(uint256 => Stats) private _pokemonStats;

    constructor(address _pokemongameaddress) {
        pokemonGameAddress = _pokemongameaddress;
        _transferOwnership(pokemonGameAddress);
    }

    function setPokemonStats(
        uint256 tokenId,
        uint256 attack,
        uint256 defense,
        uint256 sp,
        uint256 hp,
        uint256 mp,
        uint256 battletype
    ) external onlyOwner {
        uint256 sumofstats = attack + defense + sp + hp + mp;
        require(sumofstats <= 150 && sumofstats >= 50, "StatsContract: Total stats can't exceed 150.");
        Stats storage stats = _pokemonStats[tokenId];
        stats.attack = attack;
        stats.defense = defense;
        stats.sp = sp;
        stats.hp = hp;
        stats.mp = mp;
        stats.battletype = battletype;
    }

    function getPokemonStats(uint256 tokenId)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        Stats storage stats = _pokemonStats[tokenId];
        return (
            stats.attack,
            stats.defense,
            stats.sp,
            stats.hp,
            stats.mp,
            stats.battletype
        );
    }
}

