// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";
import {LinearVRGDA} from "VRGDAs/LinearVRGDA.sol";
import "src/interfaces/IWETH.sol";
import "src/StakingPool.sol";

/// @notice RICKS -- https://www.paradigm.xyz/2021/10/ricks/. Auction design based off fractional TokenVault.sol.
contract RICKS is ERC721, ERC721Holder, LinearVRGDA {

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
    /// -------- VRGDA INFORMATION --------
    /// -------------------------------------

    /// @notice the unix timestamp start time of auction
    uint256 public auctionStartTime;

    /// @notice the current price of the winning Bid during auction
    uint256 public currentPrice;

    /// @notice the current user winner of the auction
    address payable public winner;

    /// @notice possible states for the auction
    enum AuctionState {empty, inactive, active, finalized}

    /// @notice auction's current state 
    AuctionState public auctionState;

    /// @notice number of totalSold
    /// used for the number of tokens sold so far
    /// starts at 0
    uint256 public totalSold;
    
    /// -------------------------------------
    /// -------- BUYOUT INFORMATION ---------
    /// -------------------------------------

    uint256 public buyoutStartTime;

    uint256 public buyoutEndTime;

    /// @notice price of token when buyout is completed
    uint256 public buyoutPrice;

    mapping(address => uint) public buyoutBids;

    /// @notice An event emitted when an auction is won
    event BuyoutStart(address indexed buyer, uint price);

    /// @notice An event emitted when an auction is won
    event BuyoutWon(address indexed buyer, uint price);

    /// @notice An event emitted when an auction is won
    event BuyoutBid(address indexed buyer, uint price);

    /// ------------------------
    /// -------- EVENTS --------
    /// ------------------------

    /// @notice An event emitted when an auction is activated
    event Activate(address indexed initiatior);

    /// @notice An event emitted when an auction starts
    event Start(address indexed buyer, uint price);

    /// @notice An event emitted when an auction is won
    event Won(address indexed buyer, uint price);

    /// @notice An event emitted when someone redeems all tokens for the NFT
    event Redeem(address indexed redeemer);

    // VRGDA initialized at the constructor
    // auction state empty
    // supply of RICKS initialized
    // staking pool initialized
    constructor(
                // uri of the token
                string memory _name,
                string memory _symbol,
               // address of ERC1155 to be fractionalized
               address _token
               // The ID of the ERC1155 token being fractionalized.
               ,uint256 _id
                // target price
               ,uint256 _targetPrice
                // percent price decays per unit of time with no sales, scaled by 1e18
               ,uint256 _priceDecay
                // per unit of time, scaled by 1e18
               ,uint256 _perUnitTime
               ) ERC721(_name, _symbol) 
    // set VRGDA parameters
     LinearVRGDA(
        // params could be hardcoded
        _targetPrice, _priceDecay, _perUnitTime) {

        token = _token;
        id = _id;

        // set empty auction state - auction not started
        auctionState = AuctionState.empty;

        // initialize staking pool
        stakingPool = address(new StakingPool(address(this), weth));
    }

    // used to activate the RICKS platform and start the inflation schedule
    // notice how it activates after ERC721s have been transfered to the contract
    function activate() public {
        // require auction state to be empty
        require(auctionState == AuctionState.empty, "Auction already activated.");

        // transfers ERC721 to this contract
        ERC721(token).transferFrom(msg.sender, address(this), id);

        // changes the auctionState to inactive, 
        // indicating that the contract is now ready for the start of the auction.
        auctionState = AuctionState.inactive;

        // The event Activate is emitted to indicate that the contract has been activated
        emit Activate(msg.sender);
    }

    /// -------------------------------------
    /// -------- VRGDA FUNCTIONS ------------
    /// -------------------------------------

    /// kick off the sale of 1 RICK with VRGDA
    function startVRGDA() external payable {
        // require state to be inactive
        require(auctionState == AuctionState.inactive, "Auction not ready to start.");

        // set auction start time
        auctionStartTime = block.timestamp;

        // calculate the current price based on the VRGDA pricing logic
        currentPrice = getVRGDAPrice(block.timestamp - auctionStartTime, totalSupply() - totalSold);

        // update auction state to active
        auctionState = AuctionState.active;

        // starts the auction and mint 1 NFT with the id as the same as number of NFTs sold
        _mint(address(this), totalSold);

        // emit Start event to signal VRGDA auction has started
        emit Start(msg.sender, currentPrice);
    }

    // allows users to buy RICKS with ETH
    // this decrements initial supply and increments the number of auctions
    // also updates the current price and emits winner
    function buyRICK() external payable {
        // Ensure auction is active
        require(auctionState == AuctionState.active, "Auction not active");

        // Calculate the price of the tokens being bought with time left
        // and with the number of auctions that have taken place/number of RICKs minted
        uint256 price = getVRGDAPrice(block.timestamp - auctionEndTime, totalSold);

        // Ensure buyer sends enough ETH to purchase a RICK
        require(msg.value >= price, "Insufficient funds");

        // Update the current price and the winning bidder
        currentPrice = totalPrice;
        winner = payable(msg.sender);

        // increase the number of auctions/RICKs sold
        totalSold++;

        // transfer ERC721 token to the winner
        ERC721(token).safeTransferFrom(address(this), winner, totalSold);

        // Emit a Won event to signal a successful purchase
        emit Won(winner, price);

        // Update the price for the next sale of RICKs
        VRGDA.updateTargetPrice(totalPrice);
    }

    /// -------------------------------------
    /// -------- BUYOUT FUNCTIONS ------------
    /// -------------------------------------

    // user can trigger a buyout of the NFT/english auction
    // require user own 99% of total RICKs
    function startBuyout() external {
        require(auctionState == AuctionState.inactive, "can't buy out during auction");
        // requirements can be hardcoded and changed
        require(balanceOf(msg.sender) - totalSold >= 95, "need 95% of total RICKS to buyout");

        // set different auction state
        auctionState = AuctionState.finalized;

        // set auction start time to now
        buyoutStartTime = block.timestamp;

        // reserve price is set at the last price of the VRGDA auction
        buyoutPrice = currentPrice;

        // set auction end time to 7 days from now
        buyoutEndTime = block.timestamp + 7 days;
    }

    function bidBuyout () external payable {
        require(block.timestamp < buyoutEndTime, "buyout has ended");
        require(msg.value > buyoutPrice, "bid must be higher than current bid");

        // update buyout price
        buyoutPrice = msg.value;
        // update buyout bidder
        buyoutBidder = msg.sender;

        // emit event to signal a new bid
        emit BuyoutBid(buyoutBidder, msg.value);

        if ( buyoutBidder != address(0)) {
            buyoutBids[buyoutBidder] += highestBid;
        }
    }

    // user can end the buyout once time has expired
    function endBuyout () external {
        // require buyout to have ended
        require(block.timestamp >= buyoutEndTime, "buyout is still active");
        require(auctionState == AuctionState.finalized, "buyout not started");

        // set different auction state
        auctionState = AuctionState.empty;

        // transfer NFT to the highest bidder if the address is not 0
        if (highestBidder != address(0)) {
            ERC721.safeTransferFrom(address(this), highestBidder, totalSold);

            // emit event to signal the end of the buyout
            emit Won(msg.sender, buyoutPrice);
        }
    }
}

