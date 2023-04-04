// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import {Test} from "lib/forge-std/src/Test.sol";
import {RICKS} from "src/RICKS.sol";
import {toDaysWadUnsafe} from "solmate/utils/SignedWadMath.sol";
import {MyToken} from "test/utils/mocks/MockERC721.sol";
import {CheckpointEscrow} from "src/CheckpointEscrow.sol";

contract RICKSTest is Test{
    // mock NFT
    MyToken nft;
    RICKS ricks;
    CheckpointEscrow checkpoint;

    address feeReceiver = vm.addr(111);
    address alice = vm.addr(222);
    address bob = vm.addr(333);

 receive() external payable {}

    function setUp() public {
        nft = new MyToken("NFT", "NFT");
        ricks = new RICKS("ricks", "RICKS", address(nft), 1, 1e18, 0.5e18, 25e18);

        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);

        vm.label(alice, "ALICE");
        vm.label(bob, "BOB");
    }

    function testActivate() public {
        assertEq(uint(ricks.auctionState()), uint(RICKS.AuctionState.empty));
        vm.startPrank(bob);
        nft.mint(bob, 1);
        nft.approve(address(ricks), 1);

        ricks.activate();
        assertEq(uint(ricks.auctionState()), uint(RICKS.AuctionState.inactive));
        assertEq(nft.balanceOf(address(ricks)), 1);
    }

    function teststartVRGDA() public {
        assertEq(uint(ricks.auctionState()), uint(RICKS.AuctionState.empty));
        vm.startPrank(bob);
        nft.mint(bob, 1);
        nft.approve(address(ricks), 1);

        ricks.activate();
        assertEq(uint(ricks.auctionState()), uint(RICKS.AuctionState.inactive));
        assertEq(uint(ricks.auctionStartTime()), 0);

        ricks.startVRGDA();
        assertEq(uint(ricks.auctionStartTime()), block.timestamp);
        assertEq(ricks.currentPrice(), ricks.getVRGDAPrice(
            toDaysWadUnsafe(
                block.timestamp - ricks.auctionStartTime()
            ), 
            // current number sold
            ricks.totalSold()
        ));
        assertEq(uint(ricks.auctionState()), uint(RICKS.AuctionState.active));
    }

    function testbuyRICK() public {
        vm.startPrank(bob);
        nft.mint(bob, 1);
        nft.approve(address(ricks), 1);

        ricks.activate();
        ricks.startVRGDA();
        vm.stopPrank();

        vm.startPrank(alice);
        uint256 price = ricks.getVRGDAPrice(toDaysWadUnsafe(
                block.timestamp - ricks.auctionStartTime()
            ), ricks.totalSold() );

        assertEq(uint(ricks.auctionState()), uint(RICKS.AuctionState.active));
        ricks.buyRICK{value: ricks.currentPrice() + .01 ether}();
        assertEq(ricks.winner(), address(alice));
        assertEq(uint(ricks.auctionState()), uint(RICKS.AuctionState.inactive));
        // check if ricks have been minted and transferred to alice
        assertEq(ricks.balanceOf(address(ricks)), 0);
        assertEq(ricks.balanceOf(address(alice)), 1);
        // check if funds have been sent to escrow
        assertEq(ricks.checkpointEscrow().balance, price + .01 ether);
    }     

    function testBuyoutStart () public {
        vm.startPrank(bob);
        nft.mint(bob, 1);
        nft.approve(address(ricks), 1);

        ricks.activate();
        ricks.startVRGDA();
        vm.stopPrank();

        vm.startPrank(alice);
    
        ricks.buyRICK{value: ricks.currentPrice() + .01 ether}();

        assertEq(ricks.totalSold(), 1);
        assertEq(ricks.balanceOf(address(alice)), 1);
        ricks.buyoutStart();

        assertEq(uint(ricks.auctionState()), uint(RICKS.AuctionState.finalized));
        assertEq(uint(ricks.buyoutStartTime()), block.timestamp);
        assertEq(ricks.buyoutPrice(), ricks.currentPrice());
        assertEq(ricks.buyoutEndTime(), block.timestamp + 7 days);
    }

    function testBuyoutBid() public {
        vm.startPrank(bob);
        nft.mint(bob, 1);
        nft.approve(address(ricks), 1);

        ricks.activate();
        ricks.startVRGDA();
        vm.stopPrank();

        vm.startPrank(alice);
        uint256 price = ricks.getVRGDAPrice(toDaysWadUnsafe(
                block.timestamp - ricks.auctionStartTime()
            ), ricks.totalSold() );

    
        ricks.buyRICK{value: ricks.currentPrice() + .01 ether}();

        ricks.buyoutStart();

        vm.stopPrank();
        // bob bids
        vm.startPrank(bob);
        assertEq(ricks.buyoutPrice(), ricks.currentPrice());
        ricks.buyoutBid{value:price + .01 ether}(); 
        // bob is currently the buyout bidder
        assertEq(ricks.buyoutBidder(), bob);
    }

    function testBuyoutBidHigher () public {
        vm.startPrank(bob);
        nft.mint(bob, 1);
        nft.approve(address(ricks), 1);

        ricks.activate();
        ricks.startVRGDA();
        vm.stopPrank();

        vm.startPrank(alice);
        uint256 price = ricks.getVRGDAPrice(toDaysWadUnsafe(
                block.timestamp - ricks.auctionStartTime()
            ), ricks.totalSold() );

    
        ricks.buyRICK{value: ricks.currentPrice() + .01 ether}();

        ricks.buyoutStart();

        vm.stopPrank();
        // bob bids
        vm.startPrank(bob);
        ricks.buyoutBid{value:price + .01 ether}(); 
        // bob is currently the buyout bidder
        vm.stopPrank();

        // alice bids
        vm.startPrank(alice);
        assertEq(ricks.buyoutPrice(), ricks.buyoutPrice());
        ricks.buyoutBid{value:ricks.buyoutPrice() + .01 ether}(); 
        // alice is currently the buyout bidder
        assertEq(ricks.buyoutBidder(), alice);
    }

    function testBuyoutEnd() public {
        vm.startPrank(bob);
        nft.mint(bob, 1);
        nft.approve(address(ricks), 1);

        ricks.activate();
        ricks.startVRGDA();
        vm.stopPrank();

        vm.startPrank(alice);
        uint256 price = ricks.getVRGDAPrice(toDaysWadUnsafe(
                block.timestamp - ricks.auctionStartTime()
            ), ricks.totalSold() );

    
        ricks.buyRICK{value: ricks.currentPrice() + .01 ether}();

        ricks.buyoutStart();

        vm.stopPrank();
        // bob bids
        vm.startPrank(bob);
        ricks.buyoutBid{value:price + .01 ether}(); 
        // bob is currently the buyout bidder
        vm.stopPrank();

        // alice bids
        vm.startPrank(alice);
        ricks.buyoutBid{value:ricks.buyoutPrice() + .01 ether}(); 
        // alice is currently the buyout bidder
        assertEq(ricks.buyoutBidder(), alice);
        vm.warp(ricks.buyoutEndTime() + 1);
        assertEq(uint(ricks.auctionState()), uint(RICKS.AuctionState.finalized));

        // alice ends the buyout
        ricks.buyoutEnd();
        assertEq(uint(ricks.auctionState()), uint(RICKS.AuctionState.empty));
        // make sure alice gets 100% of the original NFT
        assertEq(nft.balanceOf(address(alice)), 1);
        // make sure ricks have been emptied
        assertEq(nft.balanceOf(address(ricks)), 0);
        assertEq(ricks.checkpointEscrow().balance, 2086227653312133016);
    }
}