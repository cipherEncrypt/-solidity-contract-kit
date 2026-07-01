// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Token
/// @notice A straightforward ERC-20 with a fixed supply ceiling. The owner can
///         mint new tokens up to that ceiling, and anyone can burn tokens they
///         hold. Built on OpenZeppelin's audited ERC20 and Ownable.
///
/// Heads up: this is a learning template. Have it audited before you put real
/// money behind it on mainnet.
contract Token is ERC20, Ownable {
    /// The most this token can ever exist. Fixed at deploy time and never changes.
    uint256 public immutable MAX_SUPPLY;

    /// @param name_        Human-readable name, e.g. "My Token".
    /// @param symbol_      Ticker symbol, e.g. "MYT".
    /// @param maxSupply_   Supply cap in whole tokens (we scale by decimals for you).
    /// @param initialMint_ Whole tokens minted to the deployer right away.
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 maxSupply_,
        uint256 initialMint_
    ) ERC20(name_, symbol_) Ownable(msg.sender) {
        require(initialMint_ <= maxSupply_, "initial mint exceeds cap");

        // Callers think in whole tokens; the contract works in base units.
        MAX_SUPPLY = maxSupply_ * 10 ** decimals();
        _mint(msg.sender, initialMint_ * 10 ** decimals());
    }

    /// @notice Mint `amount` (base units) to `to`, as long as we stay under the cap.
    function mint(address to, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "cap exceeded");
        _mint(to, amount);
    }

    /// @notice Destroy `amount` of the caller's own tokens.
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
