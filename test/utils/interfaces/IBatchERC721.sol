// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/interfaces/IERC721.sol";

interface IBatchERC721 is IERC721 {
    function tokenURI(uint256 tokenId) external;

    function mint(address to, uint256 tokenId) external;

    function burn(uint256 tokenId) external;

    function safeMint(address to, uint256 tokenId) external;

    function safeMint(
        address to,
        uint256 tokenId,
        bytes memory data
    ) external;

    function batchMint(address to, uint256[] memory ids) external;

    function batchTransferFrom(
        address from,
        address to,
        uint256[] memory ids
    ) external;

    function batchBurn(uint256[] memory ids) external;
}
