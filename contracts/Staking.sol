// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title Staking
/// @notice Stake one ERC-20 token and earn a second one as a reward that drips
///         out over time. Rewards are shared across everyone staking, in
///         proportion to how much (and how long) each person has staked.
///
/// This uses the well-known "reward per token" accounting made popular by
/// Synthetix: instead of looping over stakers, we track a single running
/// accumulator and settle each account whenever it touches the contract.
///
/// Learning template — get an audit before mainnet.
contract Staking is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardToken;

    /// Reward tokens released per second, split among all stakers.
    uint256 public rewardRate;

    /// Bookkeeping for the reward-per-token accumulator.
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public totalStaked;

    mapping(address => uint256) public balances;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    constructor(address stakingToken_, address rewardToken_, uint256 rewardRate_)
        Ownable(msg.sender)
    {
        require(stakingToken_ != address(0), "staking token is zero");
        require(rewardToken_ != address(0), "reward token is zero");
        stakingToken = IERC20(stakingToken_);
        rewardToken = IERC20(rewardToken_);
        rewardRate = rewardRate_;
    }

    /// Settle rewards up to the current block before running the body. Passing
    /// address(0) updates the global accumulator only (used when there's no
    /// specific account to credit, e.g. an owner changing the rate).
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    /// @notice Current value of the reward-per-token accumulator (scaled by 1e18).
    function rewardPerToken() public view returns (uint256) {
        // With nothing staked, rewards don't accrue to anyone.
        if (totalStaked == 0) return rewardPerTokenStored;

        uint256 elapsed = block.timestamp - lastUpdateTime;
        return rewardPerTokenStored + (elapsed * rewardRate * 1e18) / totalStaked;
    }

    /// @notice Total rewards `account` could claim right now.
    function earned(address account) public view returns (uint256) {
        uint256 accrued = rewardPerToken() - userRewardPerTokenPaid[account];
        return (balances[account] * accrued) / 1e18 + rewards[account];
    }

    /// @notice Deposit `amount` of the staking token.
    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        require(amount > 0, "cannot stake zero");
        totalStaked += amount;
        balances[msg.sender] += amount;
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    /// @notice Withdraw `amount` of your staked tokens (rewards stay put).
    function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
        require(amount > 0, "cannot withdraw zero");
        require(balances[msg.sender] >= amount, "insufficient stake");
        totalStaked -= amount;
        balances[msg.sender] -= amount;
        stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    /// @notice Claim whatever rewards you've earned so far.
    function claimReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    /// @notice Pull out your entire stake and claim rewards in one transaction.
    /// @dev Skips the withdraw when you have nothing staked, so someone who only
    ///      wants to sweep leftover rewards can still call this.
    function exit() external {
        uint256 staked = balances[msg.sender];
        if (staked > 0) {
            withdraw(staked);
        }
        claimReward();
    }

    /// @notice Change how fast rewards are distributed. Settles the accumulator
    ///         first so the new rate only affects time from here on.
    function setRewardRate(uint256 newRate) external onlyOwner updateReward(address(0)) {
        rewardRate = newRate;
    }
}
