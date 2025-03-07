const { expect } = require("chai");

describe("NFT", function () {
  let nft, owner, account1;
  const baseWeight = 3250;
  before(async () => {
    await hre.network.provider.send("hardhat_reset");
  });

  beforeEach(async () => {
    const NFTContract = await ethers.getContractFactory("NFT");
    [owner, account1] = await ethers.getSigners();
    nft = await NFTContract.deploy(
      "Slime shadies",
      "SS",
      "https://api.test.finance/NFT/metatadata/",
      account1.address,
      baseWeight
    );
    await nft.deployed();
    await nft.mint(owner.address, 1);
    await nft.mint(owner.address, 2);
  });

  it("Cannot create if not authorized", async function () {
    await expect(
      nft.connect(account1).mint(account1.address, 1)
    ).to.be.revertedWith("Not authorized");
  });

  it("Transfers tokens", async function () {
    await nft.transferFrom(owner.address, account1.address, 1);
    expect(await nft.ownerOf(1)).to.equal(account1.address);
  });

  it("Get common weight", async function () {
    expect(await nft.getWeight(1)).to.equal(baseWeight);
    expect(await nft.getWeight(2)).to.equal(baseWeight);
  });

  it("Set weight", async function () {
    await nft.connect(owner).setWeight([
      {
        nftId: 1,
        weight: 2,
      },
      {
        nftId: 2,
        weight: 4,
      },
    ]);
    expect(await nft.getWeight(1)).to.equal(2);
    expect(await nft.getWeight(2)).to.equal(4);
  });
});
