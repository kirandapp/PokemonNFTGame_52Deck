// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./PokemonGameV2.sol";
import "./PokemonStatV2.sol";

contract PokemonNFTV2 is ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    PokemonStatV2 public StatContrat;

    uint constant MAX_STATS_SUM = 150;
    uint constant MIN_STATS_SUM = 50;
    uint public MAX_TO_MINT = 10000;
    uint public MAX_TO_MINT_WALLET = 20;
    bool public isInitialize; 

    string private _baseUri;
    PokemonGame private pg;

    mapping(uint256 => string) private _tokenURIs;
    mapping(address => bool) public _isBlacklisted;
    mapping(address => uint256) private _tokensMintedPerWallet;

    constructor() ERC721("PokemonNFT", "PKMN") {}

    function isContract(address _addr) private view returns (bool iscontract){
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    function initialize(address _pokemonGameAddress, address statContractAddress, string memory baseUri) public {
        require(!isInitialize,"Already Initialize!");
        require(owner() == msg.sender, "Only owner can initialize");
        require(isContract(_pokemonGameAddress),"Game Address is not contract!");
        require(isContract(statContractAddress),"Stat Address is not contract!");
        StatContrat = PokemonStatV2(statContractAddress);
        pg = PokemonGame(_pokemonGameAddress);
        _baseUri = baseUri;
        isInitialize = true;
    }

    function mintPokemon() public returns (uint256) {
        console.log("log 1");
        require(_tokenIdCounter.current() + 1 <= MAX_TO_MINT, "Minting Stopped!");
        require(_tokensMintedPerWallet[msg.sender] < MAX_TO_MINT_WALLET, "Exceeded maximum limit per wallet");
        console.log("log 2");
        // StatContrat.stattype.length;
        string[] memory stattype = StatContrat.getStatsArray(); 
        uint[] memory stats = new uint256[](stattype.length);
        // console.log(stats);
        console.log("log 3");
        uint statsSum;
        console.log("log 4");
        uint256 randomSeed = uint(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender))); //, totalSupply()
        console.log("log 5");
        // Generate random stats
        for (uint256 i = 0; i < stattype.length; i++) {
            stats[i] = (uint256(keccak256(abi.encodePacked(randomSeed, stattype[i]))) % 100) + 1;
             statsSum += stats[i];
        }
        console.log("log 6");
        uint battletype = (uint(keccak256(abi.encodePacked(randomSeed, "battleType"))) % 5);
        console.log("log 7");
        console.log("log 8");
        // Scale stats to match the required sum
        uint scaledStatsSum;
        for (uint i = 0; i < stats.length; i++) {  
            stats[i] = stats[i] * statsSum / 500;
            scaledStatsSum += stats[i];
        } 
        console.log("log 9");
        // console.log("Stats Sum 50 to 150 ",stats[0]);

        uint256 desiredSum = (50 + 150) / 2; // Desired sum between 50 and 150
        uint256 currentSum = statsSum;

        // Scale stats to match the desired sum
        for (uint256 i = 0; i < stats.length; i++) {
            console.log("log 10");
            uint256 scaledStat = (stats[i] * desiredSum * 100) / currentSum;
            stats[i] = scaledStat;
            scaledStatsSum += scaledStat;
        }

        if (scaledStatsSum != desiredSum) {
            console.log("log 11");
        // Find the index of the largest stat
            uint256 maxStatIndex;
            uint256 maxStatValue;
            bool foundMaxStat = false;
            for (uint256 i = 0; i < stats.length; i++) {
                console.log("log 12");
                if (stats[i] > maxStatValue) {
                    maxStatIndex = i;
                    console.log(maxStatIndex);
                    maxStatValue = stats[i];
                    console.log(maxStatValue);
                    foundMaxStat = true;
                }
            }
            // Adjust the largest stat to reach the desired sum
            if (foundMaxStat) {
                console.log("foundMaxStat - ",foundMaxStat);
                stats[maxStatIndex] -= (scaledStatsSum - desiredSum);
                scaledStatsSum = desiredSum;    // Update the statsSum to reflect the scaled and adjusted stats
            }
             console.log("scaledStatsSum - ",scaledStatsSum);
            // stats[maxStatIndex] -= scaledStatsSum - desiredSum;
            // console.log("log 13",stats[maxStatIndex]);
        }
        // Update the statsSum to reflect the scaled and adjusted stats
        // statsSum = desiredSum;
        // console.log("log 13",statsSum);
        
        // // Adjust stats if necessary to match the required sum exactly
        // if (scaledStatsSum != statsSum) {
        //     stats[3] += (statsSum - scaledStatsSum);
        // }
        console.log("log 13");
        console.log("Stats Sum 50 to 150 statsSum - ",statsSum);
        console.log("Stats Sum 50 to 150 statsSum - ",desiredSum);
        // Add stats to the stats contract
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();
        console.log("log 14");
        uint256 sumofstats;
        for (uint256 i = 0; i < stats.length; i++) {
            sumofstats += stats[i];
        }
        console.log("sumofstats - ",sumofstats);
        pg.setPokemonStats(tokenId, stats, battletype);      
        console.log("log 15");
        // Mint the NFT
        _mint(msg.sender, tokenId);
        _tokensMintedPerWallet[msg.sender] += 1; // Increment count of tokens minted for the wallet
        // _setTokenURI(tokenId, _tokenURI);
        console.log("log 16");
        return tokenId;
    }

    //  Be careful of gas spending!
    function batchMintPokemon(uint256 numberOfNftIds) public {
        require(_tokenIdCounter.current() + numberOfNftIds <= MAX_TO_MINT, "Minting Stopped!");
        require(_tokensMintedPerWallet[msg.sender] + numberOfNftIds <= MAX_TO_MINT_WALLET, "Exceeded maximum limit per wallet");
        for (uint i = 0; i < numberOfNftIds; i++) {
            mintPokemon();
        }
    }

    function tokensOfOwner(address _owner) public view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);
        if (tokenCount == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            for (uint256 index; index < tokenCount; index++) {
                result[index] = tokenOfOwnerByIndex(_owner, index);
            }
            return result;
        }
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId),"ERC721Metadata: URI query for nonexistent token");
        string memory base = _baseURI();
        return string(abi.encodePacked(base, uint2str(tokenId)));
    }

    function blacklistAddress(address account, bool value) external onlyOwner{
        _isBlacklisted[account] = value;
    }
    
    //setter
    function setInitialize(bool _bool) public onlyOwner {
        isInitialize = _bool;
    }

    function setMaxMintOverall(uint256 _maxToMint) public onlyOwner {
        require(MAX_TO_MINT > 0,"Max must be greater than 0 !");
        MAX_TO_MINT = _maxToMint;
    }

    function setBaseURI(string memory baseURI_) external onlyOwner {
        _baseUri = baseURI_;
    }

    function getGameAddress() external view returns (address) {
        return address(pg);
    }

    // internal functions
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseUri;
    }

    function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}
