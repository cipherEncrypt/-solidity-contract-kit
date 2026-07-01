// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title NFTCollection
/// @notice An ERC-721 collection anyone can mint into by paying a set price.
///         Each token carries its own metadata URI, the collection has a hard
///         supply cap, and the owner can adjust the price and withdraw proceeds.
///
/// Learning template — get an audit before mainnet.
contract NFTCollection is ERC721URIStorage, Ownable {
    /// Next id to hand out. Also doubles as the count minted so far.
    uint256 public nextTokenId;

    /// Maximum number of tokens that can ever be minted.
    uint256 public immutable MAX_SUPPLY;

    /// Price per mint, in wei. Owner can change it with setMintPrice().
    uint256 public mintPrice;

    event Minted(address indexed to, uint256 indexed tokenId, string uri);

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 maxSupply_,
        uint256 mintPrice_
    ) ERC721(name_, symbol_) Ownable(msg.sender) {
        require(maxSupply_ > 0, "supply must be > 0");
        MAX_SUPPLY = maxSupply_;
        mintPrice = mintPrice_;
    }

    /// @notice Mint the next token to yourself, paying at least `mintPrice` and
    ///         supplying its metadata URI. Returns the new token's id.
    /// @dev Overpayment is not refunded, so front-ends should send an exact amount.
    function mint(string calldata uri) external payable returns (uint256) {
        require(nextTokenId < MAX_SUPPLY, "sold out");
        require(msg.value >= mintPrice, "insufficient payment");

        uint256 tokenId = nextTokenId++;
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, uri);

        emit Minted(msg.sender, tokenId, uri);
        return tokenId;
    }

    /// @notice Update the mint price (in wei).
    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
    }

    /// @notice Send the contract's entire ETH balance to the owner.
    function withdraw() external onlyOwner {
        (bool sent, ) = payable(owner()).call{value: address(this).balance}("");
        require(sent, "withdraw failed");
    }
}
