# RICKS V2
A fractionalized ERC721 auction contract that uses [VRGDA](https://www.paradigm.xyz/2022/08/vrgda) pricing logic and allows for buyouts.

RICKS.sol is a contract that allows a user to fractionalize an ERC721 token and sell fractionalized ownership of it via a VRGDA auction. It also allows for buyouts of the entire token through a separate English auction.

Uses [LinearVRGDA](https://github.com/transmissions11/VRGDAs/blob/master/src/LinearVRGDA.sol) for pricing logic of the distribution of RICKS.

## Functions
`activate()` Activates the RICKS platform by transferring the ERC721 token to the contract and changing the auction state to inactive.

`startVRGDA()` Kicks off the VRGDA auction by setting the auction state to active and calculating the starting price based on the VRGDA pricing logic.

`buyRICK()` Allows users to buy fractionalized ownership of the ERC721 token with ETH. Updates the winner of the auction, mints 1 RICK, and transfers the ERC721 token to the winner.

`buyoutStart()` Allows users to trigger a buyout of the entire token through a separate English auction. Sets the buyout auction state and reserve price.

`buyoutBid()` Allows users to bid on the buyout auction. Updates the buyout price and bidder.

`buyoutEnd()` Allows users to end the buyout auction once time has expired. Transfers the ERC721 token to the highest bidder and deposits the buyout price into the checkpoint contract.

`withdraw()` Allows bidders to withdraw their bid if they are not the highest bidder.


[Contract Source](src) • [Contract Tests](test)
