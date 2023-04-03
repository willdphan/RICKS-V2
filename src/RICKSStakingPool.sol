// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StakingPool is ERC721Holder {

    /// @notice NFT contract which is allowed to be staked
    IERC721 public stakingNFT;

    /// @notice token that is paid as a reward
    IERC20 public rewardToken;

    /// @notice total supply of staked NFTs
    uint256 public totalSupply;

    /// @notice sum of (reward_k / totalSupply_k) for every distribution period k   
    uint256 public rewardFactor;

    /// @notice staked NFTs per user   
    mapping(address => uint256[]) public stakedNFTs;

    /// @notice reward factor per user at time of staking    
    mapping(address => uint256) public rewardFactorAtStakeTime;

    /// @notice An event emitted when a user stakes their NFTs
    event Stake(address indexed staker, uint256[] nftIds);

    /// @notice An event emitted when a user unstakes their NFTs and claims a reward
    event Unstake(address indexed staker, uint256[] nftIds, uint256 rewardAmount);

    /// @notice An event emitted when a reward is deposited
    event DepositReward(address indexed depositor, uint256 amount);


    constructor(address _stakingNFT, address _rewardToken) {
        stakingNFT = IERC721(_stakingNFT);
        rewardToken = IERC20(_rewardToken);
    }

    /// @notice stake NFTs to claim rewards 
    function stake(uint256[] calldata nftIds) external {
        uint256[] memory tokenIds = new uint256[](nftIds.length);
        for (uint256 i = 0; i < nftIds.length; i++) {
            require(stakingNFT.ownerOf(nftIds[i]) == msg.sender, "sender does not own NFT");
            stakingNFT.safeTransferFrom(msg.sender, address(this), nftIds[i]);
            tokenIds[i] = nftIds[i];
        }
        stakedNFTs[msg.sender] = tokenIds;
        totalSupply += nftIds.length;
        rewardFactorAtStakeTime[msg.sender] = rewardFactor;
        emit Stake(msg.sender, nftIds);
    } 

    /// @notice unstake NFTs and claim rewards
    function unstakeAndClaimRewards() external {
        uint256[] memory tokenIds = stakedNFTs[msg.sender];
        uint256 rewardAmount = (rewardFactor - rewardFactorAtStakeTime[msg.sender]) * tokenIds.length;
        totalSupply -= tokenIds.length;
        delete stakedNFTs[msg.sender];
        for (uint256 i = 0; i < tokenIds.length; i++) {
            stakingNFT.safeTransferFrom(address(this), msg.sender, tokenIds[i]);
        }
        rewardToken.transfer(msg.sender, rewardAmount);
        emit Unstake(msg.sender, tokenIds, rewardAmount);
    }

    /// @notice deposit reward to be split by stakers 
    function depositReward(uint256 amount) external {
        rewardToken.transferFrom(msg.sender, address(this), amount);
        // we only perform this calculation when there are stakers to claim reward, else
        // we receive payment but can't assign it to any staker.
        if(totalSupply != 0) {
        rewardFactor += (amount / totalSupply);
        }
        emit DepositReward(msg.sender, amount);
    }
}