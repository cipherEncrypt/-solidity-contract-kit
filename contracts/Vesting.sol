// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title Vesting
/// @notice Releases a locked ERC-20 balance to one beneficiary, linearly over
///         time. An optional cliff means nothing can be claimed until a certain
///         point; after the cliff, the beneficiary can claim whatever has vested
///         so far, topping up as more unlocks.
///
/// Fund it by simply transferring tokens to this contract's address. It vests
/// whatever it holds (plus whatever has already been released).
///
/// Learning template — get an audit before mainnet.
contract Vesting {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    address public immutable beneficiary;

    uint64 public immutable start;    // when vesting begins
    uint64 public immutable cliff;    // absolute timestamp; nothing before this
    uint64 public immutable duration; // total length of the schedule, in seconds

    uint256 public released;

    event Released(uint256 amount);

    /// @param token_        The ERC-20 to vest.
    /// @param beneficiary_  Who ultimately receives the tokens.
    /// @param start_        Timestamp the schedule starts from.
    /// @param cliffSeconds_ Seconds after `start` before anything can be claimed.
    /// @param duration_     Total vesting length in seconds (must cover the cliff).
    constructor(
        address token_,
        address beneficiary_,
        uint64 start_,
        uint64 cliffSeconds_,
        uint64 duration_
    ) {
        require(token_ != address(0), "zero token");
        require(beneficiary_ != address(0), "zero beneficiary");
        require(duration_ > 0, "zero duration");
        require(cliffSeconds_ <= duration_, "cliff longer than duration");

        token = IERC20(token_);
        beneficiary = beneficiary_;
        start = start_;
        cliff = start_ + cliffSeconds_;
        duration = duration_;
    }

    /// @notice How many tokens have vested in total by now (claimed or not).
    function vestedAmount() public view returns (uint256) {
        // Everything the schedule is responsible for: current balance plus
        // whatever has already been paid out.
        uint256 total = token.balanceOf(address(this)) + released;

        if (block.timestamp < cliff) {
            return 0;
        }
        if (block.timestamp >= start + duration) {
            return total;
        }
        return (total * (block.timestamp - start)) / duration;
    }

    /// @notice What the beneficiary can withdraw right now.
    function releasable() public view returns (uint256) {
        return vestedAmount() - released;
    }

    /// @notice Send all currently-releasable tokens to the beneficiary.
    function release() external {
        uint256 amount = releasable();
        require(amount > 0, "nothing to release");
        released += amount;
        token.safeTransfer(beneficiary, amount);
        emit Released(amount);
    }
}
