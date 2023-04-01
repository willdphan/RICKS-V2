// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";
import "src/interfaces/IWETH.sol";
import "src/StakingPool.sol";

/// @notice RICKS -- https://www.paradigm.xyz/2021/10/ricks/. Auction design based off fractional TokenVault.sol.
contract RICKS is ERC20, ERC721Holder {

    /// ---------------------------
    /// -------- Addresses --------
    /// ---------------------------
    
    /// @notice weth address
    address public constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// @notice staking pool address
    address public stakingPool;

    /// -----------------------------------
    /// -------- ERC721 INFORMATION --------
    /// -----------------------------------

    /// @notice the ERC721 token address being fractionalized
    address public token;

    /// @notice the ERC721 token ID being fractionalized
    uint256 public id;

    /// -------------------------------------
    /// -------- AUCTION INFORMATION --------
    /// -------------------------------------

    /// @notice the unix timestamp end time of auction
    uint256 public auctionEndTime;

    /// @notice minimum amount of time between auctions 
    uint256 public auctionInterval;

    /// @notice minimum % increase between bids. 3 decimals, ie. 100 = 10%
    uint256 public minBidIncrease;

    /// @notice the minumum length of auctions
    uint256 public auctionLength;

    /// @notice the current price of the winning Bid during auction
    uint256 public currentPrice;

    /// @notice the current user winning the token auction
    address payable public winning;

     /// @notice the amount of tokens being sold in current auction
    uint256 public tokenAmountForAuction;

    /// @notice possible states for the auction
    enum AuctionState {empty, inactive, active, finalized }

    /// @notice auction's current state 
    AuctionState public auctionState;

    /// @notice price per shard for the five most recent auctions
    uint256[5] public mostRecentPrices;

    /// @notice number of auctions that have taken place 
    uint256 public numberOfAuctions;

    /// @notice price per token when buyout is completed
    uint256 public finalBuyoutPricePerToken;

    /// -------------------------------------
    /// -------- Inflation Parameters -------
    /// -------------------------------------

    /// @notice rate of daily RICKS issuance. 3 decimals, ie. 100 = 10%
    uint256 public dailyInflationRate;

    /// @notice initial supply of RICKS tokens
    uint256 public initialSupply;

    /// ------------------------
    /// -------- EVENTS --------
    /// ------------------------

    /// @notice An event emitted when an auction is activated
    event Activate(address indexed initiatior);

    /// @notice An event emitted when an auction starts
    event Start(address indexed buyer, uint price);

    /// @notice An event emitted when a bid is made
    event Bid(address indexed buyer, uint price);

    /// @notice An event emitted when an auction is won
    event Won(address indexed buyer, uint price);

    /// @notice An event emitted when someone redeems all tokens for the NFT
    event Redeem(address indexed redeemer);

     /// @notice An event emitted with the price per token required for a buyout
    event BuyoutPricePerToken(address indexed buyer, uint price);

    // daily inflation rate initialized at constructor
    // steps set token addres
    constructor(string memory _name
               ,string memory _symbol
               ,address _token
               ,uint256 _id
               ,uint256 _supply
               ,uint256 _dailyInflationRate
    ) ERC20(_name, _symbol) {
                    
        token = _token;
        id = _id;
        // empty auction state
        auctionState = AuctionState.empty;

        //default parameters
        auctionLength = 3 hours;
        auctionInterval = 1 days;
        minBidIncrease = 50; // 5%

        require(_dailyInflationRate > 0, "inflation rate cannot be negative");
        dailyInflationRate = _dailyInflationRate;
        initialSupply = _supply;

        stakingPool = address(new StakingPool(address(this), weth));
    }

 
}