// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "src/CheckpointedERC721.sol";

contract MockCheckpointed is CheckpointedERC721 {
    constructor(string memory name, string memory symbol)
        CheckpointedERC721(name, symbol)
    {}

    function tokenURI(uint256)
        public
        pure
        virtual
        override
        returns (string memory)
    {}

    function mint(address to, uint256 tokenId) public virtual {
        _mint(to, tokenId);
    }

    function burn(uint256 tokenId) public virtual {
        _burn(tokenId);
    }

    function safeMint(address to, uint256 tokenId) public virtual {
        _safeMint(to, tokenId);
    }

    function safeMint(
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual {
        _safeMint(to, tokenId, data);
    }

    function batchMint(address to, uint256[] memory ids) public virtual {
        _batchMint(to, ids);
    }

    function batchBurn(uint256[] memory ids) public virtual {
        _batchBurn(ids);
    }
}
