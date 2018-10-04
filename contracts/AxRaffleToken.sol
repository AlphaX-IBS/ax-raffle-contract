pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

// Use for remix editor
// import "github.com/OpenZeppelin/openzeppelin-solidity/contracts/ownership/Ownable.sol";
// import "github.com/OpenZeppelin/openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
// import "github.com/OpenZeppelin/openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
// import "github.com/OpenZeppelin/openzeppelin-solidity/contracts/math/SafeMath.sol";

// User for truffle and vscode editor
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract AxRaffle is Ownable, Pausable {
    using SafeMath for uint;

    // Pot player info
    struct AxPotPlayerInfo {
        // Pot player info
        address player_; // player address
        uint totalOwnedTickets_; // total tickets owned in pot
        uint totalUsedWeiAmt_; // total wei amt used to buy tickets
        address[] usedTokens_; // list of tokens player used to buy tickets
        uint[] totalUsedTokenAmts_; // amount of tokens players buyed tickets
        uint[] ticketStartNumbers_; // list of ticket start numbers player buyed
        uint[] ticketEndNumbers_; // list of ticket end numbers player buyed
        // Pot winner info
        uint potPrizeWeiAmt_; // total wei in pot for prize excluded fee
        address[] potPrizeTokens_; // list of tokens in pot for prize
        uint[] potPrizeTokenAmts_; // amount of tokens in pot for prize excluded fee
        uint potEndedTimeStamp_; // pot ended timestamp kept 
    }

    // Token info
    struct AxTokenInfo {
        address contract_;
        bytes32 symbol_;
        uint decimals_;
        uint amountPerTicket_;
    }
    
    // Variables
    address public operatorAddress; // Operator wallet address

    uint public weiPerTicket; // Single sale price for ticket in wei
    uint public weiFeeRate; // fee rate (extracted from total prize) for game operator, input 10 <=> 10%
    bool public gameIsActive; // Active flag for Raffle game

    AxPotPlayerInfo[] public gameWinners; // List of winners in game
    uint public lengthOfgameWinners; // Length of game winner list

    uint public potSellingPeriod; // Pot selling period (s) for calculating pot closed timestamp
    uint public potOpeningPeriod; // Pot opening period (s) for calculating next open timestamp

    uint public potOpenedTimestamp; // Pot opened timestamp, unix timestamp UTC
    uint public potClosedTimestamp; // Pot opened timestamp, unix timestamp UTC
    uint public potEndedTimestamp; // Pot ended timestamp, unix timestamp UTC
    
    uint public ticketNumberCeiling; // current latest of ticket number
    AxPotPlayerInfo[] public potPlayers; // List of pot players
    mapping(address => uint) public potPlayerIndexes; // index of player in pot player list
    uint public lengthOfPotPlayers; // Total players in pot

    uint public totalWeiPot; // Total wei in pot

    // For token payment
    bool public isActiveTokenPayment; // status of token payment method
    uint public tokenFeeRate; // fee for using token payment
    mapping(address => AxTokenInfo) public gameTokens; // List of tokens accepted in game
    uint public lengthOfGameTokens; // Total tokens accepted as payment in game
    address[] public potTokens; // List of tokens used in pot
    uint[] public potTokenAmts; // Amount of tokens used in pot
    mapping(address => uint) public potTokenIndexes; // List of token indexes used in pot
    uint public lengthOfPotTokens; // Total tokens used as payment in pot

    ERC20  public ERC20Interface; // ERC20 token interface

    // Events
    event ActivateGame(bool _active);
    event DeactivateGame(bool _deactive);
    event PurchaseTicketsByWei(address indexed playerAddress, uint weiAmount, uint startTicketNumber, uint endTicketNumber);
    event DrawTicket(address indexed winnerAddress, uint winnerTicketNumber, uint potEndedTimestamp);
    event TokenTransferFailed(address indexed from_, address indexed to_, address indexed token_, uint tokenAmount_);
    event TokenTransferSuccessful(address indexed from_, address indexed to_, address indexed token_, uint tokenAmount_);

    // Modifiers
    modifier activatedGame() {
        require(gameIsActive == true, "game is not activated");
        _;
    }

    modifier potIsOpened() {
        require(potOpenedTimestamp > 0 && now >= potOpenedTimestamp && now <= potClosedTimestamp, "game is not active");
        _;
    }

    modifier potIsClosed() {
        require(potOpenedTimestamp > 0 && now > potClosedTimestamp && potEndedTimestamp == 0, "pot is not closed");
        _;
    }

    modifier potIsNotExecuted() {
        require(potOpenedTimestamp == 0 || now < potOpenedTimestamp, "pot is not excuted");
        _;
    }

    modifier activatedTokenPayment() {
        require(isActiveTokenPayment == true, "Token payment is not active");
        _;
    }    

    // Constructor function
    constructor(
        address _operatorAddress,
        uint _potSellingPeriod, 
        uint _potOpeningPeriod, 
        uint _weiPerTicket, 
        uint _weiFeeRate,
        uint _tokenFeeRate
    ) public {

    // Just for testing
    // constructor() public {

        require (_operatorAddress != address(0), "operator address is 0");
        operatorAddress = _operatorAddress;
        potSellingPeriod = _potSellingPeriod;
        potOpeningPeriod = _potOpeningPeriod;
        weiPerTicket = _weiPerTicket;
        weiFeeRate = _weiFeeRate;
        tokenFeeRate = _tokenFeeRate;
        // Init variable value
        gameIsActive = false;
        potOpenedTimestamp = 0;
        potClosedTimestamp = 0;
        potEndedTimestamp = 0;
        lengthOfgameWinners = 0;
        ticketNumberCeiling = 0;
        lengthOfPotPlayers = 0;
        totalWeiPot = 0;
        isActiveTokenPayment = false;
        lengthOfGameTokens = 0;
        lengthOfPotTokens = 0;

        // just for testing
        // operatorAddress = address(0x7da4907fc6bd5d6939f2954cf4eb0989c5726d16);
        // potSellingPeriod = 28800;
        // potOpeningPeriod = 86400;
        // weiPerTicket = 1000000000000000;
        // weiFeeRate = 10;
        // tokenFeeRate = 10;
        // gameIsActive = true;
        // isActiveTokenPayment = true;
        // potOpenedTimestamp = now;
        // potClosedTimestamp = potOpenedTimestamp + potSellingPeriod;
        // gameTokens[address(0xf6425fab636a8065e0c625d52b17cb07c6839f77)] = AxTokenInfo(address(0xf6425fab636a8065e0c625d52b17cb07c6839f77),"GEX",18,6000000000000000000);
        // lengthOfGameTokens++;
    }

    // Set operator wallet address
    function setOperatorWalletAddress (address _operatorAddress) external onlyOwner {
        require(_operatorAddress != address(0), "new operator address is 0");
        require(_operatorAddress != operatorAddress, "new and old address are the same");
        operatorAddress = _operatorAddress;
    }

    // Activate / Deactive token payment method
    function setTokenPaymentStatus(bool _isActiveTokenPayment) external onlyOwner {
        require(isActiveTokenPayment != _isActiveTokenPayment);
        isActiveTokenPayment = _isActiveTokenPayment;
    }

    // Add new token payment list
    function addNewTokenPaymentInfo(address[] _tokens, bytes32[] _tokenSymbols, uint[] _tokenDecimals, uint[] _amountPerTicket) external activatedTokenPayment potIsNotExecuted onlyOwner {
        require(_tokens.length > 0 && _tokens.length == _tokenSymbols.length && _tokens.length == _tokenDecimals.length && _tokens.length == _amountPerTicket.length);
        for (uint i = 0; i < _tokens.length; i++) {            
            if (gameTokens[_tokens[i]].contract_ == address(0)) {
                AxTokenInfo memory axToken = AxTokenInfo(_tokens[i],_tokenSymbols[i],_tokenDecimals[i],_amountPerTicket[i]);
                gameTokens[_tokens[i]] = axToken;
                lengthOfGameTokens = lengthOfGameTokens + 1;
            }
        }
    }

    // Remove token payment list
    function removeTokenPaymentInfo(address[] _tokens) external activatedTokenPayment potIsNotExecuted onlyOwner {
        require(_tokens.length > 0);
        for (uint i = 0; i < _tokens.length; i++) {
            if (gameTokens[_tokens[i]].contract_ != address(0)) {
                delete(gameTokens[_tokens[i]]);
                lengthOfGameTokens = lengthOfGameTokens - 1;
            }            
        }
    }

    // Set ticket price by wei, wei fee rate and token fee rate
    function setTicketSales(uint _weiPerTicket, uint _weiFeeRate, uint _tokenFeeRate) external onlyOwner {
        weiPerTicket = _weiPerTicket;
        weiFeeRate = _weiFeeRate;
        tokenFeeRate = _tokenFeeRate;
    }

    // Activate game
    function activateGame() external onlyOwner {
        gameIsActive = true;
        emit ActivateGame(true);
    }

    // Deactive game
    function deactivateGame() external activatedGame onlyOwner {
        gameIsActive = false;
        emit DeactivateGame(false);
    }

    // Open pot
    function openPot(uint _potOpenedTimestamp, uint _potSellingPeriod, uint _potOpeningPeriod) external onlyOwner {
        potOpenedTimestamp = _potOpenedTimestamp;
        potSellingPeriod = _potSellingPeriod;
        potOpeningPeriod = _potOpeningPeriod;
        potClosedTimestamp = potOpenedTimestamp + potSellingPeriod;
        potEndedTimestamp = 0;
    }

    // Close pot
    function closePot(uint _potClosedTimestamp) external potIsOpened onlyOwner {
        if (_potClosedTimestamp == 0) {
            potClosedTimestamp = now;
            return;
        }
        potClosedTimestamp = _potClosedTimestamp;
    }

    // Buy tickets by ERC20 tokens
    // - Require which token must registered in payment list
    // - Assume that sender approved allowance for contract before
    // - Validate the allowance amount
    // - Complete tx as being successful or failed
    // - Update pot plater list
    // - Update pot token amount
    // Note: token amount here will be received amount in its smallest unit based on its decimal
    function PurchaseTicketsByTokens(address[] _tokens, uint[] _tokenAmts) external activatedGame potIsOpened activatedTokenPayment {
        require(_tokens.length > 0 && _tokens.length == _tokenAmts.length);
        for (uint i = 0; i < _tokens.length; i++) {
            require(gameTokens[_tokens[i]].contract_ == _tokens[i] && _tokenAmts[i] > 0);
            // Purchase tickets by tokens
            address player = msg.sender;
            ERC20Interface = ERC20(_tokens[i]);
            if (_tokenAmts[i] > ERC20Interface.allowance(player,address(this))) {
                emit TokenTransferFailed(player, address(this), _tokens[i], _tokenAmts[i]);
                revert();
            }
            ERC20Interface.transferFrom(player, address(this), _tokenAmts[i]);
            uint ticketPrice = gameTokens[_tokens[i]].amountPerTicket_;
            uint numberOfTickets = _tokenAmts[i].div(ticketPrice);
            // Update pot player list
            uint playerIdx = potPlayerIndexes[player];
            // In case of existed player
            if (potPlayers.length > 0 && potPlayers[playerIdx].player_ == player) {
                potPlayers[playerIdx].totalOwnedTickets_ += numberOfTickets;
                // Update relevant used token amount
                bool isUpdated = false;
                for (uint j = 0; j < potPlayers[playerIdx].usedTokens_.length; j++) {
                    if (potPlayers[playerIdx].usedTokens_[j] == _tokens[i]) {
                        potPlayers[playerIdx].totalUsedTokenAmts_[j] = potPlayers[playerIdx].totalUsedTokenAmts_[j].add(_tokenAmts[i]);
                        isUpdated = true;
                        break;
                    }
                }
                if (isUpdated == false) {
                    potPlayers[playerIdx].usedTokens_.push(_tokens[i]);
                    potPlayers[playerIdx].totalUsedTokenAmts_.push(_tokenAmts[i]);
                }
                // Update range of tickets
                potPlayers[playerIdx].ticketStartNumbers_.push(ticketNumberCeiling + 1);
                potPlayers[playerIdx].ticketEndNumbers_.push(ticketNumberCeiling + numberOfTickets);
            } 
            // In case of non-existed player
            else {                
                AxPotPlayerInfo memory axPotPlayer = AxPotPlayerInfo(player,numberOfTickets,0,new address[](0),new uint[](0),new uint[](0),new uint[](0),0,new address[](0),new uint[](0),0);
                potPlayers.push(axPotPlayer);
                potPlayers[potPlayers.length - 1].usedTokens_.push(_tokens[i]);                
                potPlayers[potPlayers.length - 1].totalUsedTokenAmts_.push(_tokenAmts[i]);
                potPlayers[potPlayers.length - 1].ticketStartNumbers_.push(ticketNumberCeiling + 1);
                potPlayers[potPlayers.length - 1].ticketEndNumbers_.push(ticketNumberCeiling + numberOfTickets);
                potPlayerIndexes[player] = potPlayers.length - 1;
                lengthOfPotPlayers++;
            }
            // Update pot tokens amount
            uint tokenIdx = potTokenIndexes[_tokens[i]];
            // In case of existed tokens
            if (potTokens.length > 0 && potTokens[tokenIdx] == _tokens[i]) {
                potTokenAmts[tokenIdx] = potTokenAmts[tokenIdx].add(_tokenAmts[i]);
            } 
            // In case of non-existed tokens
            else {
                potTokens.push(_tokens[i]);
                potTokenAmts.push(_tokenAmts[i]);
                potTokenIndexes[_tokens[i]] = potTokens.length - 1;
                lengthOfPotTokens = potTokens.length;
            }
            // Update ticket ceiling number
            ticketNumberCeiling += numberOfTickets;

            emit TokenTransferSuccessful(player, address(this), _tokens[i], _tokenAmts[i]);
        }
    }

    // Fallback function for buy tickets by Ether
    function () external payable activatedGame potIsOpened {
        purchaseTicketsByWei();
    }
    
    // Purchase tickets to players by ETH
    // - Validate tx by pot open timestamp range
    // - Receive ether amount
    // - Calculate relevant number of tickets
    // - Update pot player list
    // - Update pot total wei
    function purchaseTicketsByWei() public activatedGame potIsOpened {
        address player = msg.sender;
        uint totalWeiAmt = msg.value;
        uint numberOfTickets = totalWeiAmt.div(weiPerTicket);
        // Update pot player list
        uint playerIdx = potPlayerIndexes[player];
        // In case of existed players
        if (potPlayers.length > 0 && potPlayers[playerIdx].player_ == player) {
            potPlayers[playerIdx].totalOwnedTickets_ += numberOfTickets;
            potPlayers[playerIdx].totalUsedWeiAmt_ = potPlayers[playerIdx].totalUsedWeiAmt_.add(totalWeiAmt);
            // Update range of tickets
            potPlayers[playerIdx].ticketStartNumbers_.push(ticketNumberCeiling + 1);
            potPlayers[playerIdx].ticketEndNumbers_.push(ticketNumberCeiling + numberOfTickets);
        }
        // In case of non-existed players
        else {
            uint[] ticketStartNumbers;
            uint[] ticketEndNumbers;
            ticketStartNumbers.push(ticketNumberCeiling + 1);
            ticketEndNumbers.push(ticketNumberCeiling + numberOfTickets);            
            AxPotPlayerInfo memory axPotPlayer = AxPotPlayerInfo(player,numberOfTickets,totalWeiAmt,new address[](0),new uint[](0),ticketStartNumbers,ticketEndNumbers,0,new address[](0),new uint[](0),0);
            potPlayers.push(axPotPlayer);
            potPlayerIndexes[player] = potPlayers.length - 1;        
            lengthOfPotPlayers++;
        }
        // Update total pot wei amount
        totalWeiPot = totalWeiPot.add(totalWeiAmt);

        emit PurchaseTicketsByWei(player, totalWeiAmt, ticketNumberCeiling + 1, ticketNumberCeiling + numberOfTickets);

        // Update ticket ceiling number
        ticketNumberCeiling += numberOfTickets;
    }

    // Draw ticket
    // - Require pot closed
    // - Randow ticket number for prize
    // - Set end pot timestamp
    // - Update game winner list
    // - Allocate prize and fee
    // - Prepare opening next pot
    function drawTicket() external onlyOwner activatedGame potIsClosed {
        // Draw ticket
        uint winnerTicket = ticketNumberRandom();
        address winnerAddress = lookUpPlayerAddressByTicketNumber(winnerTicket);
        uint totalWeiFeeAmt = (totalWeiPot.mul(weiFeeRate)).div(100);
        uint totalWeiPrizeAmt = totalWeiPot.sub(totalWeiFeeAmt);
        uint[] tokenFeeAmts;
        uint[] tokenPrizeAmts;
        for (uint i = 0; i < potTokenAmts.length; i++) {
            uint tokenFeeAmt = (potTokenAmts[i].mul(tokenFeeRate)).div(100);
            tokenFeeAmts.push(tokenFeeAmt);
            tokenPrizeAmts.push(potTokenAmts[i].sub(tokenFeeAmt));
        }
        // End pot
        potEndedTimestamp = now;
        // Update winner list
        AxPotPlayerInfo memory winner = potPlayers[potPlayerIndexes[winnerAddress]];
        winner.potPrizeWeiAmt_ = totalWeiPrizeAmt;
        winner.potPrizeTokens_ = potTokens;
        winner.potPrizeTokenAmts_ = tokenPrizeAmts;
        winner.potEndedTimeStamp_ = potEndedTimestamp;
        gameWinners.push(winner);
        lengthOfgameWinners++;
        // Allocate prize and fee
        // Allocate wei
        winnerAddress.transfer(totalWeiPrizeAmt);
        operatorAddress.transfer(totalWeiFeeAmt);
        // Allocate tokens
        for (i = 0; i < potTokens.length; i++) {
            ERC20Interface = ERC20(potTokens[i]);
            ERC20Interface.transfer(winnerAddress,tokenPrizeAmts[i]);
            ERC20Interface.transfer(operatorAddress,tokenFeeAmts[i]);
        }
        // Prepare opening next pot
        prepareOpeningNextPot();

        emit DrawTicket(winnerAddress,winnerTicket,potEndedTimestamp);
    }

    // Prepare for opening next pot
    function prepareOpeningNextPot() {
        potOpenedTimestamp = potOpenedTimestamp + potOpeningPeriod;
        potClosedTimestamp = potOpenedTimestamp + potSellingPeriod;
        potEndedTimestamp = 0;
        totalWeiPot = 0;
        ticketNumberCeiling = 0;
        // Reset pot player list
        delete potPlayers;
        lengthOfPotPlayers = 0;
        // Reset pot token list
        delete potTokens;
        delete potTokenAmts;
        lengthOfPotTokens = 0;
    }

    // Look up owner by ticket number
    function lookUpPlayerAddressByTicketNumber(uint _ticketNumber) public view returns (address) {
        for (uint i = 0; i < potPlayers.length; i++) {            
            uint[] ticketStartNumbers = potPlayers[i].ticketStartNumbers_;
            uint[] ticketEndNumbers = potPlayers[i].ticketEndNumbers_;
            for (uint j = 0; j < ticketStartNumbers.length; j++) {
                if (_ticketNumber >= ticketStartNumbers[j] && _ticketNumber <= ticketEndNumbers[j]) {
                    return potPlayers[i].player_;
                }
            }
        }
        return address(0);
    }

    // Look up ticket numbers by player address
    function lookUpTicketNumbersByPlayerAddress(address _playerAddress) public view returns (uint[1000]) {
        uint[1000] memory potTicketList;
        for (uint i = 0; i < potPlayers.length; i++) {
            address player = potPlayers[i].player_;
            uint[] ticketStartNumbers = potPlayers[i].ticketStartNumbers_;
            uint[] ticketEndNumbers = potPlayers[i].ticketEndNumbers_;
            if (player == _playerAddress) {
                for (uint j = 0; j < ticketStartNumbers.length; j++) {
                    potTicketList[j] = ticketStartNumbers[j];
                    potTicketList[j+1] = ticketEndNumbers[j];                    
                }
                break;
            }
        }
        return potTicketList;
    }

    // Check current timestamp in smart contract
    function checkCurrentTimestamp() external view returns (uint) {
        return now;
    }

    // Random ticket number
    function ticketNumberRandom() private view returns (uint) {
        return LCGRandom() % ticketNumberCeiling;
    }

    // Linear Congruential Generator algorithm
    function LCGRandom() private view returns (uint) {
        uint seed = block.number;
        uint a = 1103515245;
        uint c = 12345;
        uint m = 2 ** 32;

        return (a * seed + c) % m;
    }

    // Get game paramters
    function getRaffleParams() public view returns (uint,uint,uint,uint,uint,uint,uint,uint,uint,uint,uint) {
        return (weiPerTicket,weiFeeRate,lengthOfgameWinners,potOpenedTimestamp,potClosedTimestamp,ticketNumberCeiling,lengthOfPotPlayers,totalWeiPot,tokenFeeRate,lengthOfGameTokens,lengthOfPotTokens);
    }

    // Get 100 pot players by index
    function get100PotPlayers(uint _from, uint _noPlayers) external view returns(AxPotPlayerInfo[100]) {
        require(_noPlayers <= 100);
        AxPotPlayerInfo[100] memory potPlayerList;
        for (uint i = 0; i <=  _noPlayers; i++) {
            potPlayerList[i] = potPlayers[i+_from];
        }
        return potPlayerList;
    }

    // Get pot player info by player address
    function getPotPlayerInfoByAddress(address _player) public view returns(AxPotPlayerInfo) {
        return potPlayers[potPlayerIndexes[_player]];
    }

    // Get pot player total owned tickets and used wei by player address
    function getPotPlayerTotalOwnedTicketsAndUsedWeiByAddress(address _player) public view returns(uint,uint) {
        return (potPlayers[potPlayerIndexes[_player]].totalOwnedTickets_,potPlayers[potPlayerIndexes[_player]].totalUsedWeiAmt_);
    }

    // Get pot player used tokens by address
    function getPotPlayerUsedTokensByAddress(address _player) public view returns (address[1000]) {
        address[1000] memory usedTokenList;
        for (uint i = 0; i < potPlayers[potPlayerIndexes[_player]].usedTokens_.length; i++) {
            usedTokenList[i] = potPlayers[potPlayerIndexes[_player]].usedTokens_[i];
        }
        return usedTokenList;
    }

    // Get pot player used amount of tokens by address
    function getPotPlayerUsedTokenAmtsByAddress(address _player) public view returns (uint[1000]) {
        uint[1000] memory totalUsedTokenAmts;
        for (uint i = 0; i < potPlayers[potPlayerIndexes[_player]].totalUsedTokenAmts_.length; i++) {
            totalUsedTokenAmts[i] = potPlayers[potPlayerIndexes[_player]].totalUsedTokenAmts_[i];
        }        
        return totalUsedTokenAmts;
    }

    // Get 100 winners by index
    function get100Winners(uint _from, uint _noWinners) external view returns(AxPotPlayerInfo[100]) {
        require(_noWinners <= 100);
        AxPotPlayerInfo[100] memory winnerList;
        for (uint i = 0; i < _noWinners; i++) {
            winnerList[i] = gameWinners[i+_from];
        }
        return winnerList;
    }

    // Get winner info by address and won time
    function getWinnerInfoByAddressAndIndex(address _winner, uint _time) external view returns(AxPotPlayerInfo) {
        require(_time <= lengthOfgameWinners);
        uint wonTime = 0;
        for (uint i = 0; i < lengthOfgameWinners; i++) {
            if (gameWinners[i].player_ == _winner) {
                wonTime++;
                if (wonTime == _time) {
                    return gameWinners[i];
                }
            }
        }
        return AxPotPlayerInfo(address(0),0,0,new address[](0),new uint[](0),new uint[](0),new uint[](0),0,new address[](0),new uint[](0),0);
    }

    // Get pot prize wei amount and ended timestamp by winner address and won time
    function getWinnerPotWeiAndTimestampByAddressAndIndex(address _winner, uint _time) external view returns(uint,uint) {
        require(_time <= lengthOfgameWinners);
        uint wonTime = 0;
        for (uint i = 0; i < lengthOfgameWinners; i++) {
            if (gameWinners[i].player_ == _winner) {
                wonTime++;
                if (wonTime == _time) {
                    return (gameWinners[i].potPrizeWeiAmt_,gameWinners[i].potEndedTimeStamp_);
                }
            }
        }
        return (0,0);
    }

    // Get pot prize tokens by winner address and won time
    function getWinnerPotPrizeTokensByAddressAndIndex(address _winner, uint _time) external view returns(address[1000]) {
        require(_time <= lengthOfgameWinners);
        address[1000] memory potPrizeTokens;
        uint wonTime = 0;
        for (uint i = 0; i < lengthOfgameWinners; i++) {
            if (gameWinners[i].player_ == _winner) {
                wonTime++;
                if (wonTime == _time) {
                    for (uint j = 0; j < gameWinners[i].potPrizeTokens_.length; j++) {
                        potPrizeTokens[j] = gameWinners[i].potPrizeTokens_[j];
                    }
                    break;
                }
            }
        }
        return potPrizeTokens;
    }

    // Get pot prize amount of tokens by winner address and won time
    function getWinnerPotPrizeTokenAmtsByAddressAndIndex(address _winner, uint _time) external view returns(uint[1000]) {
        require(_time <= lengthOfgameWinners);
        uint[1000] memory potPrizeTokenAmts;
        uint wonTime = 0;
        for (uint i = 0; i < lengthOfgameWinners; i++) {
            if (gameWinners[i].player_ == _winner) {
                wonTime++;
                if (wonTime == _time) {
                    for (uint j = 0; j < gameWinners[i].potPrizeTokenAmts_.length; j++) {
                        potPrizeTokenAmts[j] = gameWinners[i].potPrizeTokenAmts_[j];
                    }                    
                    break;
                }
            }
        }
        return potPrizeTokenAmts;
    }

    // Get number of won times by winner address
    function getWonTimeByAddress(address _winner) external view returns(uint) {
        uint wonTime = 0;
        for (uint i = 0; i < lengthOfgameWinners; i++) {
            if (gameWinners[i].player_ == _winner) {
                wonTime++;
            }
        }
        return wonTime;
    }
}