import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

describe("NFTVault Contract", function () {
  let NFTVault: Contract;
  let FractionalNFT: Contract;
  let MockNFT: Contract;
  let owner: SignerWithAddress;
  let user: SignerWithAddress;
  let anotherUser: SignerWithAddress;

  beforeEach(async function () {
    // Lấy danh sách signers
    [owner, user, anotherUser] = await ethers.getSigners();

    // Deploy MockNFT (ERC-721)
    const MockNFTFactory = await ethers.getContractFactory("MockNFT");
    MockNFT = (await MockNFTFactory.deploy()) as Contract;
    await MockNFT.deployed();

    // Deploy FractionalNFT (ERC-1155)
    const FractionalNFTFactory = await ethers.getContractFactory("FractionalNFT");
    FractionalNFT = (await FractionalNFTFactory.deploy("https://metadata.example.com/")) as Contract;
    await FractionalNFT.deployed();

    // Deploy NFTVault
    const NFTVaultFactory = await ethers.getContractFactory("NFTVault");
    NFTVault = (await NFTVaultFactory.deploy(FractionalNFT.address)) as Contract;
    await NFTVault.deployed();
  });

  it("should allow a user to deposit an NFT", async function () {
    await MockNFT.connect(user).mint(1);
    await MockNFT.connect(user).approve(NFTVault.address, 1);

    await NFTVault.connect(user).depositNFT(MockNFT.address, 1);

    const vaultItem = await NFTVault.vaultItems(0);
    expect(vaultItem.owner).to.equal(user.address);
    expect(vaultItem.nftContract).to.equal(MockNFT.address);
    expect(vaultItem.tokenId).to.equal(1);
    expect(vaultItem.isRedeemed).to.be.false;

    expect(await MockNFT.ownerOf(1)).to.equal(NFTVault.address);
  });

  it("should mint FNFTs upon depositing an NFT", async function () {
    await MockNFT.connect(user).mint(1);
    await MockNFT.connect(user).approve(NFTVault.address, 1);

    await NFTVault.connect(user).depositNFT(MockNFT.address, 1);

    const fractionCount = 100;
    const balance = await FractionalNFT.balanceOf(user.address, 0);
    expect(balance).to.equal(fractionCount);

    const totalSupply = await FractionalNFT.totalSupply(0);
    expect(totalSupply).to.equal(fractionCount);
  });

  it("should allow redemption of NFT by burning FNFTs", async function () {
    await MockNFT.connect(user).mint(1);
    await MockNFT.connect(user).approve(NFTVault.address, 1);
    await NFTVault.connect(user).depositNFT(MockNFT.address, 1);

    await FractionalNFT.connect(user).setApprovalForAll(NFTVault.address, true);
    await NFTVault.connect(user).redeemNFT(0);

    const vaultItem = await NFTVault.vaultItems(0);
    expect(vaultItem.isRedeemed).to.be.true;
    expect(await MockNFT.ownerOf(1)).to.equal(user.address);

    const balance = await FractionalNFT.balanceOf(user.address, 0);
    expect(balance).to.equal(0);
  });

  it("should not allow redemption if user does not own all FNFTs", async function () {
    await MockNFT.connect(user).mint(1);
    await MockNFT.connect(user).approve(NFTVault.address, 1);
    await NFTVault.connect(user).depositNFT(MockNFT.address, 1);

    await FractionalNFT.connect(user).safeTransferFrom(
      user.address,
      anotherUser.address,
      0,
      50,
      "0x"
    );

    await expect(NFTVault.connect(user).redeemNFT(0)).to.be.revertedWith(
      "You do not own all fractions"
    );
  });

  it("should handle multiple deposits and redemptions correctly", async function () {
    await MockNFT.connect(user).mint(1);
    await MockNFT.connect(user).approve(NFTVault.address, 1);
    await MockNFT.connect(user).mint(2);
    await MockNFT.connect(user).approve(NFTVault.address, 2);

    await NFTVault.connect(user).depositNFT(MockNFT.address, 1);
    await NFTVault.connect(user).depositNFT(MockNFT.address, 2);

    const vaultItem1 = await NFTVault.vaultItems(0);
    const vaultItem2 = await NFTVault.vaultItems(1);
    expect(vaultItem1.tokenId).to.equal(1);
    expect(vaultItem2.tokenId).to.equal(2);

    await FractionalNFT.connect(user).setApprovalForAll(NFTVault.address, true);
    await NFTVault.connect(user).redeemNFT(0);

    expect(await MockNFT.ownerOf(1)).to.equal(user.address);
    expect(await MockNFT.ownerOf(2)).to.equal(NFTVault.address);
  });
});