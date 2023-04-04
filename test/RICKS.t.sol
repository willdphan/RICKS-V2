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
        assertEq(uint(ricks.auctionState()), uint(RICKS.AuctionState.active));
        assertEq(nft.balanceOf(address(ricks)), 1);
    }

    function testbuyRICK() public {
        vm.startPrank(bob);
        nft.mint(bob, 1);
        nft.approve(address(ricks), 1);

        ricks.activate();
        assertEq(uint(ricks.auctionState()), uint(RICKS.AuctionState.inactive));
        assertEq(uint(ricks.auctionStartTime()), 0);

        ricks.startVRGDA();
        assertEq(uint(ricks.auctionStartTime()), block.timestamp);
        assertEq(uint(ricks.auctionState()), uint(RICKS.AuctionState.active));
        assertEq(nft.balanceOf(address(ricks)), 1);
        vm.stopPrank();

        vm.startPrank(alice);
        uint256 price = ricks.getVRGDAPrice(toDaysWadUnsafe(
                block.timestamp - ricks.auctionStartTime()
            ), ricks.totalSold() );

        ricks.buyRICK{value: price + .01 ether}();
        assertEq(ricks.winner(), address(alice));
        assertEq(uint(ricks.auctionState()), uint(RICKS.AuctionState.inactive));
        assertEq(nft.balanceOf(address(ricks)), 0);
        assertEq(nft.balanceOf(address(alice)), 1);
        
        assertEq(ricks.checkpointEscrow().balance, price + .01 ether);
    }     


    
}