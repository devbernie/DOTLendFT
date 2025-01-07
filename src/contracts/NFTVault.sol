// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

contract FractionalNFT is ERC1155Supply {
    constructor(string memory uri) ERC1155(uri) {}

    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public {
        _mint(to, id, amount, data);
    }
}

contract NFTVault is Ownable {
    struct VaultItem {
        address owner;
        address nftContract;
        uint256 tokenId;
        bool isRedeemed;
    }

    mapping(uint256 => VaultItem) public vaultItems;
    FractionalNFT public fractionalNFT;
    uint256 public vaultCounter;

    event NFTDeposited(address indexed owner, address indexed nftContract, uint256 tokenId);
    event FNFTMinted(uint256 indexed nftId, uint256 fractionCount);
    event NFTRedeemed(address indexed owner, uint256 indexed nftId);

    constructor(address fractionalNFTAddress) Ownable(msg.sender) {
        fractionalNFT = FractionalNFT(fractionalNFTAddress);
    }

    function depositNFT(address nftContract, uint256 tokenId) external {
        IERC721 nft = IERC721(nftContract);
        require(nft.ownerOf(tokenId) == msg.sender, "You do not own this NFT");
        require(
            nft.isApprovedForAll(msg.sender, address(this)) || nft.getApproved(tokenId) == address(this),
            "Vault not approved"
        );

        nft.transferFrom(msg.sender, address(this), tokenId);

        vaultItems[vaultCounter] = VaultItem({
            owner: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            isRedeemed: false
        });

        emit NFTDeposited(msg.sender, nftContract, tokenId);

        _mintFNFT(vaultCounter, 100);
        vaultCounter++;
    }

    function _mintFNFT(uint256 nftId, uint256 fractionCount) internal {
        require(vaultItems[nftId].owner != address(0), "NFT does not exist");
        require(!vaultItems[nftId].isRedeemed, "NFT has been redeemed");

        fractionalNFT.mint(msg.sender, nftId, fractionCount, "");
        emit FNFTMinted(nftId, fractionCount);
    }

    function redeemNFT(uint256 nftId) external {
        VaultItem storage item = vaultItems[nftId];
        require(fractionalNFT.balanceOf(msg.sender, nftId) == fractionalNFT.totalSupply(nftId), "You do not own all fractions");
        require(!item.isRedeemed, "NFT has already been redeemed");

        fractionalNFT.burn(msg.sender, nftId, fractionalNFT.totalSupply(nftId));
        IERC721(item.nftContract).transferFrom(address(this), msg.sender, item.tokenId);

        item.isRedeemed = true;

        emit NFTRedeemed(msg.sender, nftId);
    }
}