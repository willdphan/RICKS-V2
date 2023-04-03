// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "solmate/tokens/ERC721.sol";

contract MockBatchERC721 is ERC721 {
    constructor(string memory _name, string memory _symbol)
        ERC721(_name, _symbol)
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

    function batchTransferFrom(
        address from,
        address to,
        uint256[] memory ids
    ) public virtual {
        for (uint256 i; i < ids.length; i++) transferFrom(from, to, ids[i]);
    }

    function batchMint(address to, uint256[] memory ids) public virtual {
        for (uint256 i; i < ids.length; i++) mint(to, ids[i]);
    }

    function batchBurn(uint256[] memory ids) public virtual {
        for (uint256 i; i < ids.length; i++) burn(ids[i]);
    }
}
