// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CheckpointedERC721, ERC721} from "src/CheckpointedERC721.sol";

contract CheckpointEscrow {
    address immutable token;

    event Deposited(uint256 indexed blockNumber, uint256 weiAmount);
    event Withdrawal(uint256 indexed blockNumber, uint256 weiAmount);

    ///     blockNumber => amount
    mapping(uint256 => uint256) private _deposits;
    mapping(uint256 => bool) private _isClaimed;

    constructor(address _token) {
        token = _token;
    }

    function pendingFor(uint32 blockNumber, address payee) public view returns (uint256) {
        uint256 balance = CheckpointedERC721(token).getPastBalance(payee, blockNumber);
        uint256 supply = CheckpointedERC721(token).getPastTotalSupply(blockNumber);
        uint256 escrowedAmount = _deposits[blockNumber];

        require(!_isClaimed[blockNumber], "already claimed");

        return (escrowedAmount * balance) / supply;
    }

    function withdraw(uint32 blockNumber) public virtual {
        uint256 amount = pendingFor(blockNumber, msg.sender);
        emit Withdrawal(blockNumber, amount);
    }

    receive() external payable {
        _deposits[block.number] = msg.value;
    }
}
