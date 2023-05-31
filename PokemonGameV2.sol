// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IPokemonStatV2.sol";

contract PokemonGame is Ownable, IERC721Receiver {

    using Counters for Counters.Counter;
    Counters.Counter private _matchIdCounter;

    IERC721Enumerable private NFTContract; 
    IERC20 private TokenContract;
    IPokemonStatV2 public StatContract;
    address public feeAddress;

    uint256 public fee = 500; //5%  

    uint256 public MIN_CARD_DECK = 10;
    uint256 public SELECT_CARD_FROM_DECK = 6;

    bool public isInitialize; 

    uint256[] private matchIds; 

    struct PokemonStats {
        uint256[] stats;
    }
    
    struct Battle {
        uint256 matchId;
        uint256[] nftids;
        uint256[] nftstats;
        address creatorAddress;
        uint256 stat;
        uint256 statIndex;
        uint256 battleamount;
        uint256 fee;
        uint256 reward;
    }
    enum BattleStatus {Close, Open, Cancel, Draw}

    struct Player {
        uint256 matchId;
        uint256[] nftids;
        uint256[] nftstats;
        address playerAddress;
        uint256 stat;
        uint256 statIndex;
        bool isWon;
    }

    mapping (uint256 => Battle) private _battle;
    mapping (uint256 => Player) private _player;
    mapping (address => uint256[]) private battleCreatedBy;
    mapping (address => uint256[]) private battleWonBy;
    mapping (address => uint256[]) private playedBattleBy;
    mapping (uint256 => bool) public matchIdExist;
    
    mapping (uint256 => address) private winner;
    mapping (uint256 => bool) public winnerDeclared;
    mapping (uint256 => BattleStatus) private battleStatus;

    mapping (uint256 => PokemonStats) private _pokemonStats;
    mapping (address => bool) private isWhitelist;

    function isContract(address _addr) private view returns (bool iscontract){
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    function initialize(address _nft, address _token, address statContractAddress) public {
        require(!isInitialize,"Already Initialize!");
        require(owner() == msg.sender, "Only owner can initialize");
        require(_nft != address(0) && _token != address(0));
        require(isContract(statContractAddress),"Stat Address is not contract");
        feeAddress = msg.sender;
        isWhitelist[_nft] = true;
        isWhitelist[statContractAddress];
        NFTContract = IERC721Enumerable(_nft);
        TokenContract = IERC20(_token);
        StatContract = IPokemonStatV2(statContractAddress);
        isInitialize = true;
    }
    
    function createBattle(uint256 _tokenamount) external returns (uint256) {
        uint256 numNFTs = NFTContract.balanceOf(msg.sender);
        console.log(numNFTs);
        require(numNFTs >= MIN_CARD_DECK, "Insufficient Nfts balance to play!");
        require(TokenContract.balanceOf(msg.sender) >= _tokenamount, "Insufficient Token to play ");

        //getting random any 6 nfts from user's nftids balance
        uint256[] memory selectedNftIds = selectRandom();
        uint256[] memory selectedNftStats = new uint256[](SELECT_CARD_FROM_DECK);
        
        //Perform the transfer of nft from user to contract actions with the selected NFT IDs
        address creatoraddress;
        for (uint256 i = 0; i < SELECT_CARD_FROM_DECK; i++) {
            uint256 randomNftId = selectedNftIds[i];
            creatoraddress = NFTContract.ownerOf(randomNftId);
            NFTContract.safeTransferFrom(msg.sender, address(this), randomNftId);
        }
        // take token to create battle
        TokenContract.transferFrom(msg.sender, address(this), _tokenamount);

        string[] memory stattype = StatContract.getStatsArray();
        uint256 statindex = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender))) % stattype.length;
        uint256 stat;
        for (uint256 i = 0; i < SELECT_CARD_FROM_DECK; i++) {
            uint256 nft = selectedNftIds[i];
            PokemonStats memory nftstats = _pokemonStats[nft];
            for (uint256 j = 0; j < stattype.length; j++) {
                if (statindex == j) {
                    stat += nftstats.stats[j];
                    selectedNftStats[i] = nftstats.stats[j];
                }
            }
        }
        // working with the selected NFT IDs and sum of stat...
        _matchIdCounter.increment();
        uint256 _matchId = _matchIdCounter.current();
        (uint256 fees, uint256 reward) = calculateFeeAndReward(_tokenamount);
        _battle[_matchId] = Battle(_matchId, selectedNftIds, selectedNftStats, creatoraddress, stat, statindex, _tokenamount, fees, reward);
        battleCreatedBy[msg.sender].push(_matchId);
        matchIds.push(_matchId);
        battleStatus[_matchId] = BattleStatus.Open;
        matchIdExist[_matchId] = true;
        return _matchId;
    }
      
    function joinBattle(uint _matchId, uint256 _tokenamount ) external {
        require(matchIdExist[_matchId],"Invalid MatchId!!");
        require(!winnerDeclared[_matchId],"MatchId closed");
        uint256 numNFTs = NFTContract.balanceOf(msg.sender);
        console.log(numNFTs);
        require(numNFTs >= MIN_CARD_DECK, "Insufficient Nfts balance to play!");
        Battle memory bt = _battle[_matchId];
        require(bt.battleamount == _tokenamount,"Insufficient tokens to play");
        require(TokenContract.balanceOf(msg.sender) >= _tokenamount, "Insufficient Tokens Balance!");
        playedBattleBy[msg.sender].push(_matchId);
        //getting random any 6 nfts from user's nftids balance
        uint256[] memory selectedNftIds = selectRandom();
        uint256[] memory selectedNftStats = new uint256[](SELECT_CARD_FROM_DECK);
        address playeraddress;
        bool isplayerwin;
        for (uint256 i = 0; i < SELECT_CARD_FROM_DECK; i++) {
            uint256 randomNftId = selectedNftIds[i];
            playeraddress = NFTContract.ownerOf(randomNftId);
            NFTContract.safeTransferFrom(msg.sender, address(this), randomNftId);
        }
        // take token to play battle
        TokenContract.transferFrom(msg.sender, address(this), _tokenamount);

        uint statindex = bt.statIndex;
        uint stat;
        for (uint256 i = 0; i < SELECT_CARD_FROM_DECK; i++) {
            uint256 nft = selectedNftIds[i];
            PokemonStats memory nftstats = _pokemonStats[nft];
            stat += nftstats.stats[statindex];
            selectedNftStats[i] = nftstats.stats[statindex];
        }
        //Winning conditions        
        if (bt.stat > stat) {
            console.log("Winner is ",bt.creatorAddress);
            // winner[_matchId] = string(abi.encodePacked(matchnftId," is the winner..."));
            winner[_matchId] = bt.creatorAddress;
            battleWonBy[bt.creatorAddress].push(_matchId);
            battleStatus[_matchId] = BattleStatus.Close;
            isplayerwin = false;
            sendReward(bt.battleamount, _tokenamount, bt.creatorAddress);
        } else if (bt.stat < stat) {
            console.log("Winner is ",msg.sender);
            winner[_matchId] = msg.sender;
            battleWonBy[msg.sender].push(_matchId);
            battleStatus[_matchId] = BattleStatus.Close;
            isplayerwin = true;
            sendReward(bt.battleamount, _tokenamount, playeraddress);
        } else {
            console.log("NO ONE IS WINNER");
            winner[_matchId] = address(0);
            isplayerwin = false;
            battleStatus[_matchId] = BattleStatus.Draw;
        }
        winnerDeclared[_matchId] = true;
        _player[_matchId] = Player(_matchId, selectedNftIds, selectedNftStats, playeraddress, stat, statindex, isplayerwin);
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
        require(bt.creatorAddress == msg.sender, "You are not the creator!");
        TokenContract.transfer(msg.sender, bt.battleamount);
        console.log("Cancel function- NFT balance before - ",NFTContract.balanceOf(msg.sender));
        for (uint256 i = 0; i < bt.nftids.length; i++) {
            NFTContract.safeTransferFrom(address(this), msg.sender, bt.nftids[i]);
        }
        console.log("Cancel functon- NFT balance after transfer - ",NFTContract.balanceOf(msg.sender));
        battleStatus[_matchId] = BattleStatus.Cancel;
        matchIdExist[_matchId] = false;
    }

    //internal functions
    function selectRandom() internal returns(uint256[] memory) {
        (bool success, bytes memory result) = address(NFTContract).call(abi.encodeWithSignature("tokensOfOwner(address)", msg.sender));
        require(success, "Call to 'tokensOfOwner()' function failed");
        uint256[] memory nftIds = abi.decode(result, (uint256[]));
        require(nftIds.length >= SELECT_CARD_FROM_DECK, "Insufficient NFTs balance to select.");
        uint256[] memory selectedNftIds = new uint256[](SELECT_CARD_FROM_DECK);
        //Select 6 random NFT IDs
        for (uint256 i = 0; i < SELECT_CARD_FROM_DECK; i++) {
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

    function sendReward(uint256 _battleamount, uint256 _tokenamount, address _winner) internal {
        uint256 amount = _battleamount + _tokenamount;
        uint256 platformFee = amount * fee / 100 / 100;
        uint256 winamount = amount - platformFee;
        TokenContract.transfer(feeAddress, platformFee);
        TokenContract.transfer(_winner, winamount);
    }

    function calculateFeeAndReward(uint256 _battleamount) internal view returns (uint256, uint256) {
        uint256 amount = _battleamount + _battleamount;
        uint256 platformFee = amount * fee / 100 / 100;
        uint256 winamount = amount - platformFee;
        return (platformFee, winamount);
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
    function setSelectCardFromDeck(uint256 _selectCard) external onlyOwner {
        SELECT_CARD_FROM_DECK = _selectCard;
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
    
    function setPokemonStats(uint256 tokenId, uint256[] memory _stats) external {
        require(isWhitelist[msg.sender], "StatsContract: Only the whitelisted addresses can set Pokemon stats.");
        uint256 sumofstats;
        for (uint256 i = 0; i < _stats.length; i++) {
            sumofstats += _stats[i];
        }
        console.log("sumofstats - ",sumofstats);
        // require(sumofstats <= 150 && sumofstats >= 50, "StatsContract: Total stats can't exceed 150.");
        require(sumofstats >= 50,"Error :- Sum of stats less than 50!");
        require(sumofstats <= 150,"Error :- Sum of stats greater than 150!");

        PokemonStats memory stat = PokemonStats({
            stats: _stats
        });
        _pokemonStats[tokenId] = stat;
    }

    //  GETTER FUNCTIONS
    function getPokemon(uint256 tokenId) external view returns (uint256[] memory) {
        PokemonStats storage stats = _pokemonStats[tokenId];
        return (stats.stats);  
    }

    function getBattle(uint256 _matchId) public view returns (uint256[] memory, uint256[] memory, address, uint256, uint256, uint256, uint256, uint256) {
        Battle memory bt = _battle[_matchId];
        return (bt.nftids, bt.nftstats, bt.creatorAddress, bt.stat, bt.statIndex, bt.battleamount, bt.fee, bt.reward);
    }
    function getPlayedBattle(uint256 _matchId) public view returns (uint256[] memory, uint256[] memory, address, uint256, uint256, bool) {
        Player memory pt = _player[_matchId];
        return (pt.nftids, pt.nftstats, pt.playerAddress, pt.stat, pt.statIndex, pt.isWon);
    }
    function getPlayedBattleBy(address _playeraddress) public view returns (uint256[] memory) {
        return playedBattleBy[_playeraddress];
    }
    function getCreatorBattle(address _creator) external view returns (uint256[] memory) {
        return battleCreatedBy[_creator];
    }
    function getWonBattle(address player) external view returns (uint256[] memory) {
        return battleWonBy[player];
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
    function getstatArrayfromStat() public view returns (string[] memory) {
        return StatContract.getStatsArray();
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

