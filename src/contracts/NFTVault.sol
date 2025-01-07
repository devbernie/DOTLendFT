// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTVault is Ownable {
    // Struct to store NFT and its fractions
    struct VaultItem {
        address owner; // Owner of the NFT
        address nftContract; // Address of the ERC-721 contract
        uint256 tokenId; // Token ID of the NFT
        bool isRedeemed; // Indicates if the NFT has been redeemed
    }

    // Mapping from NFT ID to vault item
    mapping(uint256 => VaultItem) public vaultItems;

    // Fractional NFT Contract (ERC-1155)
    ERC1155Supply public fractionalNFT;

    // Event definitions
    event NFTDeposited(address indexed owner, address indexed nftContract, uint256 tokenId);
    event FNFTMinted(uint256 indexed nftId, uint256 fractionCount);
    event NFTRedeemed(address indexed owner, uint256 indexed nftId);

    // Counter for NFT IDs in the vault
    uint256 public vaultCounter;

    constructor(address _fractionalNFT) {
        fractionalNFT = ERC1155Supply(_fractionalNFT);
    }

    /**
     * @dev Deposit an NFT into the vault.
     * @param nftContract Address of the ERC-721 contract.
     * @param tokenId Token ID of the NFT to deposit.
     */
    function depositNFT(address nftContract, uint256 tokenId) external {
        IERC721 nft = IERC721(nftContract);

        // Ensure the sender owns the NFT and has approved the vault
        require(nft.ownerOf(tokenId) == msg.sender, "You do not own this NFT");
        require(nft.isApprovedForAll(msg.sender, address(this)) || nft.getApproved(tokenId) == address(this), "Vault not approved");

        // Transfer NFT to vault
        nft.transferFrom(msg.sender, address(this), tokenId);

        // Create vault item
        vaultItems[vaultCounter] = VaultItem({
            owner: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            isRedeemed: false
        });

        emit NFTDeposited(msg.sender, nftContract, tokenId);

        // Mint fractional tokens
        _mintFNFT(vaultCounter, 100); // Example: Mint 100 fractions
        vaultCounter++;
    }

    /**
     * @dev Mint fractional tokens (FNFT) for a deposited NFT.
     * @param nftId ID of the NFT in the vault.
     * @param fractionCount Number of fractions to mint.
     */
    function _mintFNFT(uint256 nftId, uint256 fractionCount) internal {
        require(vaultItems[nftId].owner != address(0), "NFT does not exist");
        require(!vaultItems[nftId].isRedeemed, "NFT has been redeemed");

        // Mint fractions
        fractionalNFT.mint(msg.sender, nftId, fractionCount, "");

        emit FNFTMinted(nftId, fractionCount);
    }

    /**
     * @dev Redeem an NFT by burning all associated fractions.
     * @param nftId ID of the NFT in the vault.
     */
    function redeemNFT(uint256 nftId) external {
        VaultItem storage item = vaultItems[nftId];

        // Ensure the caller owns all fractions
        require(fractionalNFT.balanceOf(msg.sender, nftId) == fractionalNFT.totalSupply(nftId), "You do not own all fractions");
        require(!item.isRedeemed, "NFT has already been redeemed");

        // Burn all fractions
        fractionalNFT.burn(msg.sender, nftId, fractionalNFT.totalSupply(nftId));

        // Transfer NFT back to owner
        IERC721(item.nftContract).transferFrom(address(this), msg.sender, item.tokenId);

        // Mark as redeemed
        item.isRedeemed = true;

        emit NFTRedeemed(msg.sender, nftId);
    }
}