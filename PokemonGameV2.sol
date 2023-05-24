// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PokemonGame is Ownable, IERC721Receiver {

    using Counters for Counters.Counter;
    Counters.Counter private _matchIdCounter;

    IERC721Enumerable private NFTContract; 
    IERC20 private TokenContract;
    address public feeAddress;

    uint256 public fee = 500; //5%  

    uint public MIN_CARD_DECK = 10;

    bool public isInitialize; 

    uint256[] private matchIds; 

    struct PokemonStats {
        uint256 attack;
        uint256 defense;
        uint256 sp;
        uint256 hp;
        uint256 mp;
        uint256 battleType;
    }
    string[5] BattleType = ["WOOD","WATER","LAND","FIRE","AIR"] ;//Wood water land fire AIR
    string[5] StatType = ["ATTACK","DEFENSE","SP","HP","MP"] ;//ATTACK DEFENSE SP HP MP
    
    struct Battle {
        uint256 matchId;
        uint256[] nftids;
        address creatorAddress;
        uint256 stat;
        uint256 statIndex;
        uint256 battleamount;
    }
    enum BattleStatus {Close, Open, Cancel, Draw}

    mapping (uint256 => Battle) private _battle;
    mapping (address => uint256[]) private battleCreatedBy;
    mapping (address => uint256[]) private battleWonBy;
    mapping (uint256 => bool) public matchIdExist;
    

    mapping (uint256 => address) private winner;
    mapping (uint256 => bool) public winnerDeclared;
    mapping (uint256 => BattleStatus) private battleStatus;

    mapping (uint256 => PokemonStats) private _pokemonStats;
    mapping (address => bool) private isWhitelist;

    function isContract(address _addr) private view returns (bool isontract){
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    function initialize(address _nft, address _token) public {
        require(!isInitialize,"Already Initialize!");
        require(owner() == msg.sender, "Only owner can initialize");
        require(_nft != address(0) && _token != address(0));
        feeAddress = msg.sender;
        isWhitelist[_nft] = true;
        isWhitelist[_token] = true;
        NFTContract = IERC721Enumerable(_nft);
        TokenContract = IERC20(_token);
        isInitialize = true;
    }
    
    function createBattle(uint256 _tokenamount) external returns (uint256) {
        uint256 numNFTs = NFTContract.balanceOf(msg.sender);
        console.log(numNFTs);
        require(numNFTs >= MIN_CARD_DECK, "Insufficient Nfts balance to play!");
        require(TokenContract.balanceOf(msg.sender) >= _tokenamount, "Insufficient Token to play ");

        //getting random any 6 nfts from user's nftids balance
        uint256[] memory selectedNftIds = selectRandom();
        
        //Perform the transfer of nft from user to contract actions with the selected NFT IDs
        address creatoraddress;
        for (uint256 i = 0; i < 6; i++) {
            uint256 randomNftId = selectedNftIds[i];
            creatoraddress = NFTContract.ownerOf(randomNftId);
            NFTContract.safeTransferFrom(msg.sender, address(this), randomNftId);
        }
        // take token to create battle
        TokenContract.transferFrom(msg.sender, address(this), _tokenamount);
        uint256 statindex = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender))) % 5;
        uint256 stat;
        for (uint256 i = 0; i < 6; i++) {
            uint256 nft = selectedNftIds[i];
            PokemonStats memory nftstats = _pokemonStats[nft];
            if (statindex == 0) {
                stat += nftstats.attack;
            } else if (statindex == 1) {
                stat += nftstats.defense;
            } else if (statindex == 2) {
                stat += nftstats.sp;
            } else if (statindex == 3) {
                stat += nftstats.hp;
            }else {
                stat += nftstats.mp;
            }
        }
        // working with the selected NFT IDs and sum of stat...
        _matchIdCounter.increment();
        uint256 _matchId = _matchIdCounter.current();
        _battle[_matchId] = Battle(_matchId, selectedNftIds, creatoraddress, stat, statindex, _tokenamount);
        battleCreatedBy[msg.sender].push(_matchId);
        matchIds.push(_matchId);
        battleStatus[_matchId] = BattleStatus.Open;
        matchIdExist[_matchId] = true;
        return _matchId;
    }
      
    function play(uint _matchId, uint256 _tokenamount ) external {
        require(matchIdExist[_matchId],"Invalid MatchId!!");
        require(!winnerDeclared[_matchId],"MatchId closed");
        uint256 numNFTs = NFTContract.balanceOf(msg.sender);
        console.log(numNFTs);
        require(numNFTs >= MIN_CARD_DECK, "Insufficient Nfts balance to play!");
        require(TokenContract.balanceOf(msg.sender) >= _tokenamount, "Insufficient Token to play ");

        //getting random any 6 nfts from user's nftids balance
        uint256[] memory selectedNftIds = selectRandom();

        Battle memory bt = _battle[_matchId];
        address playeraddress;

        for (uint256 i = 0; i < 6; i++) {
            uint256 randomNftId = selectedNftIds[i];
            playeraddress = NFTContract.ownerOf(randomNftId);
            NFTContract.safeTransferFrom(msg.sender, address(this), randomNftId);
        }
        // take token to play battle
        TokenContract.transferFrom(msg.sender, address(this), _tokenamount);
        uint statindex = bt.statIndex;
        uint stat;
        for (uint256 i = 0; i < 6; i++) {
            uint256 nft = selectedNftIds[i];
            PokemonStats memory nftstats = _pokemonStats[nft];
            
            if (statindex == 0) {
                stat += nftstats.attack;
                console.log("Selected Stat",stat);
            } else if (statindex == 1) {
                stat += nftstats.defense;
                console.log("Selected Stat",stat);
            } else if (statindex == 2) {
                stat += nftstats.sp;
                console.log("Selected Stat",stat);
            } else if (statindex == 3) {
                stat += nftstats.hp;
                console.log("Selected Stat",stat);
            }else {
                stat += nftstats.mp;
                console.log("Selected Stat",stat);
            }
        }
        //Winning conditions        
        if (bt.stat > stat) {
            console.log("Winner is ",bt.creatorAddress);
            // winner[_matchId] = string(abi.encodePacked(matchnftId," is the winner..."));
            winner[_matchId] = bt.creatorAddress;
            battleWonBy[bt.creatorAddress].push(_matchId);
            battleStatus[_matchId] = BattleStatus.Close;
            calculateFee(bt.battleamount, _tokenamount, bt.creatorAddress);
        } else if (bt.stat < stat) {
            console.log("Winner is ",msg.sender);
            winner[_matchId] = msg.sender;
            battleWonBy[msg.sender].push(_matchId);
            battleStatus[_matchId] = BattleStatus.Close;
            calculateFee(bt.battleamount, _tokenamount, playeraddress);
        } else {
            console.log("NO ONE IS WINNER");
            winner[_matchId] = address(0);
            battleStatus[_matchId] = BattleStatus.Draw;
        }
        winnerDeclared[_matchId] = true;
         // nfts giving back to battle creator
        for (uint256 i = 0; i < bt.nftids.length; i++) {
            NFTContract.safeTransferFrom(address(this), bt.creatorAddress, bt.nftids[i]);
        }
         // nfts giving back to player
        for (uint256 i = 0; i < selectedNftIds.length; i++) {
            NFTContract.safeTransferFrom(address(this), msg.sender, selectedNftIds[i]);
        }
    }

    function cancelBattle(uint _matchId) external {
        require(matchIdExist[_matchId],"Invalid MatchId!!");
        require(!winnerDeclared[_matchId],"MatchId closed");
        require(battleStatus[_matchId] != BattleStatus.Cancel,"Battle is already Closed");
        require(battleStatus[_matchId] == BattleStatus.Open,"Battle is not Open");
        Battle memory bt = _battle[_matchId];
        TokenContract.transfer(msg.sender, bt.battleamount);
        console.log("Cancel function- NFT balance before - ",NFTContract.balanceOf(msg.sender));
        for (uint256 i = 0; i < bt.nftids.length; i++) {
            NFTContract.safeTransferFrom(address(this), msg.sender, bt.nftids[i]);
        }
        TokenContract.transfer(msg.sender, bt.battleamount);
        console.log("Cancel functon- NFT balance after transfer - ",NFTContract.balanceOf(msg.sender));
        battleStatus[_matchId] = BattleStatus.Cancel;
        delete(_battle[_matchId]);
        matchIdExist[_matchId] = false;
    }

    //internal functions
    function selectRandom() internal returns(uint256[] memory) {
        (bool success, bytes memory result) = address(NFTContract).call(abi.encodeWithSignature("tokensOfOwner(address)", msg.sender));
        require(success, "Call to 'tokensOfOwner()' function failed");
        uint256[] memory nftIds = abi.decode(result, (uint256[]));
        require(nftIds.length >= 6, "Insufficient NFTs balance to select 6.");
        uint256[] memory selectedNftIds = new uint256[](6);
        //Select 6 random NFT IDs
        for (uint256 i = 0; i < 6; i++) {
            uint256 randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender, i))) % nftIds.length;
            selectedNftIds[i] = nftIds[randomIndex];
            // Remove the selected NFT ID from the array by shifting elements
            for (uint256 j = randomIndex; j < nftIds.length - 1; j++) {
                nftIds[j] = nftIds[j + 1];
            }
            // Resize the array by creating a new array with length-1
            uint256[] memory resizedArray = new uint256[](nftIds.length - 1);
            for (uint256 j = 0; j < resizedArray.length; j++) {
                resizedArray[j] = nftIds[j];
            }
            nftIds = resizedArray;
            console.log("Selected NFT ID", selectedNftIds[i]);
        }
        return selectedNftIds;
    }

    function calculateFee(uint256 _battleamount, uint256 _tokenamount, address _winner) internal {
        uint256 winammount = _battleamount + _tokenamount;
        uint256 platformFee = winammount * fee / 100 / 100;
        TokenContract.transfer(feeAddress, platformFee);
        TokenContract.transfer(_winner, (winammount - platformFee));
    }

    //  SETTER FUNCTIONS
    function setInitialize(bool _bool) public onlyOwner {
        isInitialize = _bool;
    }
    function setMinCardDeck(uint256 _deck) external onlyOwner {
        (bool success, bytes memory result) = address(NFTContract).call(abi.encodeWithSignature("MAX_TO_MINT()"));
        require(success, "Call to 'MAX_TO_MINT()' function failed");
        uint256 mintlimit = abi.decode(result, (uint256));
        require(_deck < mintlimit, "minimum deck limit must be less than miniting limit!");
        MIN_CARD_DECK = _deck;
    }
    function setTokenaddress(address _token) public onlyOwner {
        require(isContract(address(_token)),"This address is not a contract!");
        TokenContract = IERC20(_token);
    }
    function setFeeAddress(address _feeCollector) public onlyOwner {
        require(_feeCollector != address(0),"Fee address can't be set to Zero!");
        feeAddress = _feeCollector;
    }
    function setFeePercent(uint256 _fee) public onlyOwner {
        require(_fee > 0,"Fee percent should be greater than Zero !");
        fee = _fee;
    }
    
    function setPokemonStats(uint256 tokenId, uint256 attack, uint256 defense, uint256 sp, uint256 hp, uint256 mp, uint _typeIndex) external {
        require(isWhitelist[msg.sender], "StatsContract: Only the whitelisted addresses can set Pokemon stats.");
        uint256 sumofstats = attack + defense + sp + hp + mp;
        require(sumofstats <= 150 && sumofstats >= 50, "StatsContract: Total stats can't exceed 150.");
        PokemonStats memory stats = PokemonStats({
            attack: attack,
            defense: defense,    
            sp: sp,                                                                                                             
            hp: hp,
            mp: mp,
            battleType: _typeIndex
        });
        _pokemonStats[tokenId] = stats;
    }

    //  GETTER FUNCTIONS
    function getPokemon(uint256 tokenId) external view returns (uint256, uint256, uint256, uint256, uint256) {
        PokemonStats storage stats = _pokemonStats[tokenId];
        return (stats.attack, stats.defense, stats.sp, stats.hp, stats.mp);  
    }
    function getStats() public view returns (string[5] memory) {
        return StatType;
    }
    function getBattle(uint256 _matchId) public view returns (uint256[] memory, address, uint256, uint256, uint256) {
        Battle memory bt = _battle[_matchId];
        return (bt.nftids, bt.creatorAddress, bt.stat, bt.statIndex, bt.battleamount);
    }
    function getCreatedBattle(address _creator) external view returns (uint256[] memory) {
        return battleCreatedBy[_creator];
    }
    function getWonBattle(address _player) external view returns (uint256[] memory) {
        return battleWonBy[_player];
    }

    function isWhitelisted(address _addr) public view returns (bool) {
        return isWhitelist[_addr];
    }
    function getNFTContract() public view returns (IERC721Enumerable) {
        return NFTContract;
    }
    function getTokenContract() public view returns (IERC20) {
        return TokenContract;
    }
    function getWinner(uint256 _matchId) public view returns (address) {
        return winner[_matchId];
    }
    function getMatchIds() external view returns (uint[] memory) {
        return matchIds;
    }
    function getBattleStatus(uint256 _matchId) external view returns(string memory) {
        if (battleStatus[_matchId] == BattleStatus.Close) {
            return "Close";   //Close, Open, Cancel, Draw
        } else if (battleStatus[_matchId] == BattleStatus.Open) {
            return "Open";
        } else if (battleStatus[_matchId] == BattleStatus.Cancel) {
            return "Cancel";
        } else {
            return "Draw";
        }
    }
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
		return IERC721Receiver.onERC721Received.selector;
	} 
}


