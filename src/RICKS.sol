// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";
import {LinearVRGDA} from "VRGDAs/LinearVRGDA.sol";
import "src/interfaces/IWETH.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {CheckpointEscrow} from 'src/CheckpointEscrow.sol';
import {toDaysWadUnsafe} from "solmate/utils/SignedWadMath.sol";



/// @notice RICKS -- https://www.paradigm.xyz/2021/10/ricks/. Auction design based off fractional TokenVault.sol.
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

    // kick off the VRGDA with one NFT
    // get VRGDA starting price, set auction to active, mint 1 RICK
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

        // mint 1 NFT with the id as the same as number of NFTs sold
        _mint(address(this), totalSold);

        // emit Start event to signal VRGDA auction has started
        emit Start(msg.sender, currentPrice);
    }

    // INCLUDE TRANSFERS
    // allows users to buy RICKS with ETH
    // gets price to buy RICKS with VRGDA pricing logic
    // set inactive auction state, transfer ERC721 token to winner
    function buyRICK() external payable {
        // Ensure auction is active
        require(auctionState == AuctionState.active, "Auction not active");


        // Calculate the price of the tokens being bought with time left
        // and with the number of auctions that have taken place/number of RICKs minted
        uint256 price = getVRGDAPrice(
            toDaysWadUnsafe(
                block.timestamp - auctionStartTime
            ), 
            // increase number of Ricks sold
            totalSold++
        );

        // Ensure buyer sends enough ETH to purchase a RICK
        require(msg.value >= price, "Insufficient funds");

        // Update the winner of the auction
        winner = payable(msg.sender);

        // set auction state to inactive
        auctionState = AuctionState.inactive;

        // transfer ERC721 token to the buyer
        ERC721(token).safeTransferFrom(address(this), winner, totalSold, "");

        // deposit msg.value of NFT into the checkpoint contract
        SafeTransferLib.safeTransferETH(checkpointEscrow, msg.value);

        // Emit a Won event to signal a successful purchase
        emit Won(winner, price);
    }

    /// -------------------------------------
    /// -------- BUYOUT FUNCTIONS -----------
    /// -------------------------------------

    // user can trigger a buyout of the NFT/english auction
    // require user own 95% of total RICKs - can be changed
    function buyoutStart() external {
        require(auctionState == AuctionState.inactive, "can't buy out during auction");
        // requirements can be hardcoded and changed
        require(balanceOf(msg.sender) * 100 / totalSold >= 95, "need 95% of total RICKS to buyout");

        // set VRGDA auction state
        auctionState = AuctionState.finalized;

        // set auction start time to now
        buyoutStartTime = block.timestamp;

        // reserve price is set at the last price of the VRGDA auction
        buyoutPrice = currentPrice;

         // if msg.sender does not = 0, then emit buyout start event
        if (msg.sender != address(0)) {
         emit BuyoutStart(msg.sender, buyoutPrice);
        }

        // set auction end time to 7 days from now - can be changed
        buyoutEndTime = block.timestamp + 7 days;
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
        payable(msg.sender).transfer(bidAmount);
    }

    // user can end the buyout once time has expired
    function buyoutEnd () external {
        // require buyout to have ended
        require(block.timestamp >= buyoutEndTime, "buyout is still active");
        require(auctionState == AuctionState.finalized, "buyout not started");
        // require contract holds the NFT to be fractionalized
        require(ERC721(token).ownerOf(id) == address(this), "The contract does not hold the NFT being sold");

        // set different auction state
        auctionState = AuctionState.empty;

        // transfer NFT to the highest bidder if the address is not 0
        if (buyoutBidder != address(0)) {
            ERC721.safeTransferFrom(address(this), buyoutBidder, totalSold);

            // deposit msg.value of NFT into the checkpoint contract
            SafeTransferLib.safeTransferETH(checkpointEscrow, buyoutPrice);

            // emit event to signal the end of the buyout
            emit Won(msg.sender, buyoutPrice);
        }
    }
}

