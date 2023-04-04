// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";
import {LinearVRGDA} from "VRGDAs/LinearVRGDA.sol";
import "src/interfaces/IWETH.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {CheckpointEscrow} from 'src/CheckpointEscrow.sol';
import {toDaysWadUnsafe} from "solmate/utils/SignedWadMath.sol";

contract RICKS is ERC721, ERC721Holder, LinearVRGDA {

    /// ---------------------------
    /// -------- Addresses --------
    /// ---------------------------

    /// @notice checkpoint address
    address public checkpointEscrow;

    /// -----------------------------------
    /// ------- ERC721 INFORMATION --------
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

    uint256 public auctionEndtime;

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

    address public buyoutBidder;

    mapping(address => uint) public buyoutBids;

    /// ------------------------
    /// -------- EVENTS --------
    /// ------------------------

    /// @notice An event emitted when someone deposits an NFT to be fractionalized
    event Depositor(address indexed initiatior);

    /// @notice An event emitted when a VRGDA auction starts
    event Start(address indexed buyer, uint price);

    /// @notice An event emitted when a VRGDA auction is won
    event Won(address indexed buyer, uint price);

    /// @notice An event emitted when a buyout has started
    event BuyoutStart(address indexed buyer, uint price);

    /// @notice An event emitted when a buyout is won
    event BuyoutWon(address indexed buyer, uint price);

    /// @notice An event emitted when a buyout has new bid
    event BuyoutBid(address indexed buyer, uint price);


    // VRGDA initialized at the constructor
    // RICKS token 
    // auction state empty
    // staking pool initialized
    constructor(string memory _name
               ,string memory _symbol
               // address of ERC1155 to be fractionalized
               ,address _token
               // The ID of the ERC1155 token being fractionalized.
               ,uint256 _id
                // target price
               ,int256 _targetPrice
                // percent price decays per unit of time with no sales, scaled by 1e18
               ,int256 _priceDecay
                // per unit of time, scaled by 1e18
               ,int256 _perUnitTime
     ) ERC721(_name, _symbol) 
    // set VRGDA parameters
     LinearVRGDA(
        // params could be hardcoded
        _targetPrice, _priceDecay, _perUnitTime) {

        token = _token;
        id = _id;

        // set empty auction state - auction not started
        auctionState = AuctionState.empty;

        // initialize checkpoint contract
        checkpointEscrow = address(new CheckpointEscrow(address(this)));
    }

    // used to activate the RICKS platform, transfer NFT to the contract
    // notice how it activates after ERC721 have been transfered to the contract
    // depositor of NFT is emitted
    function activate() public {
        // require auction state to be empty
        require(auctionState == AuctionState.empty, "Auction already activated.");

        // transfers ERC721 to this contract
        ERC721(token).transferFrom(msg.sender, address(this), id);

        // require that the contract holds the NFT
        require(ERC721(token).ownerOf(id) == address(this), "The contract does not hold the NFT");

        // changes the auctionState to inactive, 
        // indicating that the contract is now ready for the start of the auction.
        auctionState = AuctionState.inactive;

        // The event Activate is emitted to indicate that the contract has been activated
        emit Depositor(msg.sender);
    }

    /// -------------------------------------
    /// -------- VRGDA FUNCTIONS ------------
    /// -------------------------------------

    // kick off the VRGDA
    // get VRGDA starting price, set auction to active
    // emit start event
    function startVRGDA() external payable {
        // require state to be inactive
        require(auctionState == AuctionState.inactive, "Auction not ready to start.");

        // set auction start time
        auctionStartTime = block.timestamp;

        // calculate the starting price based on the VRGDA pricing logic
        currentPrice = getVRGDAPrice(
            toDaysWadUnsafe(
                block.timestamp - auctionStartTime
            ), 
            // current number sold
            totalSold
        );

        // update auction state to active
        auctionState = AuctionState.active;

        // emit Start event to signal VRGDA auction has started
        emit Start(msg.sender, currentPrice);
    }

    // allows users to buy RICKS with ETH
    // gets price to buy (mint) RICKS with VRGDA pricing logic
    // set inactive auction state, mint 1 RICK, transfer ERC721 token to winner
    function buyRICK() external payable {
        // Ensure auction is active
        require(auctionState == AuctionState.active, "Auction not active");

        // Ensure buyer sends enough ETH to purchase a RICK
        require(msg.value >= currentPrice, "Insufficient funds");

        // Update the winner of the auction
        winner = payable(msg.sender);

        // set auction state to inactive
        auctionState = AuctionState.inactive;

        // mint 1 RICKS NFT directly to the winner with the id as the same as number of NFTs sold
        _mint(winner, totalSold);

        // deposit msg.value of NFT into the checkpoint contract
        SafeTransferLib.safeTransferETH(checkpointEscrow, msg.value);

        // increase this so that in next activate, price has been updated
        totalSold++;

        // Emit a Won event to signal a successful purchase
        emit Won(winner, currentPrice);
    }

    /// -------------------------------------
    /// -------- BUYOUT FUNCTIONS -----------
    /// -------------------------------------

    // user can trigger a buyout of the NFT/english auction
    // require user own 95% of total RICKs - can be changed
    function buyoutStart() external {
        require(auctionState == AuctionState.inactive, "can't buy out during auction");
        // requirements can be hardcoded and changed
        require((balanceOf(msg.sender) >= (95 * totalSold) / 100), "need 95% of total RICKS to start buyout");


        // set VRGDA auction state
        auctionState = AuctionState.finalized;

        // set auction start time to now
        buyoutStartTime = block.timestamp;

        // reserve price is set at the last price of the VRGDA auction
        buyoutPrice = currentPrice;

        // set auction end time to 7 days from now - can be changed
        buyoutEndTime = block.timestamp + 7 days;

         // if msg.sender does not = 0, then emit buyout start event
        if (msg.sender != address(0)) {
         emit BuyoutStart(msg.sender, buyoutPrice);
        }
    }

    // bid on the buyout of the NFT/english auction
    function buyoutBid () external payable {
        require(block.timestamp < buyoutEndTime, "buyout has ended");
        require(msg.value > buyoutPrice, "bid must be higher than current bid");

        // update buyout price
        buyoutPrice = msg.value;
        // update buyout bidder
        buyoutBidder = msg.sender;

        if (msg.sender != address(0)) {
            // track the amount of ETH the bidder has put in
            buyoutBids[buyoutBidder] += msg.value;
        }

        // emit event to signal a new bid
        emit BuyoutBid(msg.sender, msg.value);
    }

     function withdraw() external {
        uint bidAmount =  buyoutBids[msg.sender];
        // reset bid to 0 for the user
        buyoutBids[msg.sender] = 0;
        // refund the user's ETH
        SafeTransferLib.safeTransferETH(msg.sender, bidAmount);
    }

    // user can end the buyout once time has expired
    function buyoutEnd () external {
        // require buyout to have ended
        require(block.timestamp >= buyoutEndTime, "buyout is still active");
        require(auctionState == AuctionState.finalized, "buyout not started");

        // set different auction state
        auctionState = AuctionState.empty;

        // transfer NFT to the highest bidder if the address is not 0
        if (buyoutBidder != address(0)) {
            ERC721(token).safeTransferFrom(address(this), buyoutBidder, id);

            // deposit msg.value of NFT into the checkpoint contract
            SafeTransferLib.safeTransferETH(checkpointEscrow, buyoutPrice);

            // emit event to signal the end of the buyout
            emit Won(buyoutBidder, buyoutPrice);
        }
    }
}

