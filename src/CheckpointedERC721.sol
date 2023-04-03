// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721, ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";

abstract contract ERC721Checkpointable is ERC721 {
    using SafeCastLib for uint256;

    struct Checkpoint {
        uint32 fromBlock;
        uint96 amount;
    }

    struct CheckpointsSlot {
        Checkpoint balance;
    }

    uint8 public constant decimals = 0;
    uint32 public numSupplyCheckpoints;
    mapping(uint32 => Checkpoint) public supplyCheckpoints;
    /// account -> #checkpoints
    mapping(address => uint32) public numBalanceCheckpoints;
    /// account -> checkpoint# -> checkpoint(fromBlock,#votes)
    mapping(address => mapping(uint32 => CheckpointsSlot)) public checkpoints;

    constructor(string memory _name, string memory _symbol)
        ERC721(_name, _symbol)
    {}

    function balanceOf(address owner)
        public
        view
        virtual
        override
        returns (uint256)
    {
        require(owner != address(0), "ZERO_ADDRESS");
        return getCurrentBalance(owner);
    }

    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual override {
        _transferFrom(from, to, id);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual override {
        _transferFrom(from, to, id);
        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(
                    msg.sender,
                    from,
                    id,
                    ""
                ) ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes calldata data
    ) public virtual override {
        _transferFrom(from, to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(
                    msg.sender,
                    from,
                    id,
                    data
                ) ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function batchTransferFrom(
        address from,
        address to,
        uint256[] memory ids
    ) public virtual {
        require(to != address(0), "INVALID_RECIPIENT");
        uint256 id;
        uint96 amount = ids.length.safeCastTo96();
        _moveBalances(from, to, amount);
        for (uint256 i; i < amount; i++) {
            id = ids[i];
            require(from == _ownerOf[id], "WRONG_FROM");
            require(
                msg.sender == from ||
                    isApprovedForAll[from][msg.sender] ||
                    msg.sender == getApproved[id],
                "NOT_AUTHORIZED"
            );

            _ownerOf[id] = to;
            delete getApproved[id];
            emit Transfer(from, to, id);
        }
    }

    function _batchMint(address to, uint256[] memory ids) internal virtual {
        require(to != address(0), "INVALID_RECIPIENT");
        uint256 id;
        uint96 amount = ids.length.safeCastTo96();
        require(amount > 0, "INVALID_AMOUNT");
        address owner;

        _moveBalances(address(0), to, amount);

        for (uint256 i; i < amount; i++) {
            id = ids[i];
            owner = _ownerOf[id];
            require(owner == address(0), "ALREADY_MINTED");
            _ownerOf[id] = to;
            emit Transfer(address(0), to, id);
        }
    }

    function _batchBurn(uint256[] memory ids) internal virtual {
        uint256 id;
        uint96 amount = ids.length.safeCastTo96();
        address owner;

        _moveBalances(msg.sender, address(0), amount);

        for (uint256 i; i < amount; i++) {
            id = ids[i];
            owner = _ownerOf[id];
            require(owner != address(0), "NOT_MINTED");
            require(
                msg.sender == owner ||
                    isApprovedForAll[owner][msg.sender] ||
                    msg.sender == getApproved[id],
                "NOT_AUTHORIZED"
            );

            delete _ownerOf[id];
            delete getApproved[id];

            emit Transfer(owner, address(0), id);
        }
    }

    function _mint(address to, uint256 id) internal virtual override {
        require(to != address(0), "INVALID_RECIPIENT");
        require(_ownerOf[id] == address(0), "ALREADY_MINTED");

        _moveBalances(address(0), to, 1);

        _ownerOf[id] = to;

        emit Transfer(address(0), to, id);
    }

    function _safeMint(
        address to,
        uint256 id,
        bytes memory data
    ) internal virtual override {
        _mint(to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(
                    msg.sender,
                    address(0),
                    id,
                    data
                ) ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function _safeMint(address to, uint256 id) internal virtual override {
        _safeMint(to, id, "");
    }

    function _burn(uint256 id) internal virtual override {
        address owner = _ownerOf[id];
        require(owner != address(0), "NOT_MINTED");
        require(
            msg.sender == owner ||
                isApprovedForAll[owner][msg.sender] ||
                msg.sender == getApproved[id],
            "NOT_AUTHORIZED"
        );

        _moveBalances(owner, address(0), 1);

        delete _ownerOf[id];
        delete getApproved[id];

        emit Transfer(owner, address(0), id);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function getCurrentBalance(address account) public view returns (uint96) {
        uint32 pos = numBalanceCheckpoints[account];
        return pos != 0 ? checkpoints[account][pos - 1].balance.amount : 0;
    }

    function getCurrentTotalSupply() public view returns (uint96) {
        uint32 pos = numSupplyCheckpoints;
        return pos != 0 ? supplyCheckpoints[pos - 1].amount : 0;
    }

    function getPastTotalSupply(uint256 blockNumber)
        public
        view
        virtual
        returns (uint256)
    {
        require(block.number > blockNumber, "UNDETERMINED");

        uint32 pos = numSupplyCheckpoints;
        if (pos == 0) return 0;

        if (supplyCheckpoints[pos - 1].fromBlock <= blockNumber) {
            return supplyCheckpoints[pos - 1].amount;
        }

        if (supplyCheckpoints[0].fromBlock > blockNumber) return 0;

        uint32 lower;
        uint32 upper = pos - 1;

        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2;
            Checkpoint memory cp = supplyCheckpoints[center];
            if (cp.fromBlock == blockNumber) return cp.amount;
            cp.fromBlock < blockNumber ? lower = center : upper = center - 1;
        }

        return supplyCheckpoints[lower].amount;
    }

    function getPastBalance(address account, uint256 blockNumber)
        public
        view
        virtual
        returns (uint256)
    {
        require(block.number > blockNumber, "UNDETERMINED");

        uint32 pos = numBalanceCheckpoints[account];
        if (pos == 0) return 0;

        if (checkpoints[account][pos - 1].balance.fromBlock <= blockNumber) {
            return checkpoints[account][pos - 1].balance.amount;
        }

        if (checkpoints[account][0].balance.fromBlock > blockNumber) return 0;

        uint32 lower;
        uint32 upper = pos - 1;

        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2;
            CheckpointsSlot memory cp = checkpoints[account][center];
            if (cp.balance.fromBlock == blockNumber) return cp.balance.amount;
            cp.balance.fromBlock < blockNumber ? lower = center : upper =
                center -
                1;
        }

        return checkpoints[account][lower].balance.amount;
    }

    function _moveBalances(
        address src,
        address dst,
        uint96 amount
    ) internal {
        if (src != dst && amount > 0) {
            if (src != address(0)) {
                uint96 srcOld;
                uint32 srcPos = numBalanceCheckpoints[src];

                srcOld = srcPos != 0
                    ? checkpoints[src][srcPos - 1].balance.amount
                    : 0;

                uint96 srcNew = srcOld - amount;

                _writeBalanceCheckpoint(src, srcPos, srcNew);
            }

            if (dst != address(0)) {
                uint32 dstPos = numBalanceCheckpoints[dst];
                uint96 dstOld;

                dstOld = dstPos != 0
                    ? checkpoints[dst][dstPos - 1].balance.amount
                    : 0;

                uint96 dstNew = dstOld + amount;

                _writeBalanceCheckpoint(dst, dstPos, dstNew);
            }

            if (dst == address(0)) {
                uint96 supplyOld;
                supplyOld = numSupplyCheckpoints != 0
                    ? supplyCheckpoints[numSupplyCheckpoints - 1].amount
                    : 0;

                uint96 newSupply = supplyOld - amount;
                _writeSupplyCheckpoint(numSupplyCheckpoints, newSupply);
            }

            if (src == address(0)) {
                uint96 supplyOld;
                supplyOld = numSupplyCheckpoints != 0
                    ? supplyCheckpoints[numSupplyCheckpoints - 1].amount
                    : 0;

                uint96 newSupply = supplyOld + amount;
                _writeSupplyCheckpoint(numSupplyCheckpoints, newSupply);
            }
        }
    }

    function _transferFrom(
        address from,
        address to,
        uint256 id
    ) internal {
        require(from == _ownerOf[id], "WRONG_FROM");
        require(to != address(0), "INVALID_RECIPIENT");
        require(
            msg.sender == from ||
                isApprovedForAll[from][msg.sender] ||
                msg.sender == getApproved[id],
            "NOT_AUTHORIZED"
        );

        _moveBalances(from, to, 1);
        _ownerOf[id] = to;

        delete getApproved[id];

        emit Transfer(from, to, id);
    }

    function _writeSupplyCheckpoint(uint32 pos, uint96 newSupply) internal {
        uint32 blockNumber = block.number.safeCastTo32();
        if (pos > 0 && supplyCheckpoints[pos - 1].fromBlock == blockNumber) {
            supplyCheckpoints[pos - 1].amount = newSupply;
        } else {
            supplyCheckpoints[pos] = Checkpoint(blockNumber, newSupply);
            numSupplyCheckpoints = pos + 1;
        }
    }

    function _writeBalanceCheckpoint(
        address account,
        uint32 pos,
        uint96 newBalance
    ) internal {
        uint32 blockNumber = block.number.safeCastTo32();
        if (
            pos > 0 &&
            checkpoints[account][pos - 1].balance.fromBlock == blockNumber
        ) {
            checkpoints[account][pos - 1].balance.amount = newBalance;
        } else {
            checkpoints[account][pos].balance = Checkpoint(
                blockNumber,
                newBalance
            );
            numBalanceCheckpoints[account] = pos + 1;
        }
    }
}
