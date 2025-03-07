const { expect } = require("chai");

describe("NFT_Booster_Minter", function () {
  let shady, nft, minter, owner, account1, account2, account3;

  const baseWeight = 3250;
  const price = ethers.BigNumber.from("10000000000000000000"); // 10 Shady tokens

  before(async () => {
    await hre.network.provider.send("hardhat_reset");
  });

  beforeEach(async () => {
    [owner, account1, account2, account3] = await ethers.getSigners();
    const ShadyContact = await ethers.getContractFactory("Shady_token");
    shady = await ShadyContact.deploy();
    await shady.deployed();
    await shady
      .connect(owner)
      .transfer(account1.address, price.mul(ethers.BigNumber.from("10")));
    const NFTContract = await ethers.getContractFactory("NFT");
    nft = await NFTContract.deploy(
      "Slime shadies",
      "SS",
      "https://api.test.finance/NFT/metatadata/",
      account1.address,
      baseWeight,
    );
    await nft.deployed();
    const MinterContract = await ethers.getContractFactory(
      "NFT_Booster_Minter",
    );
    minter = await MinterContract.deploy(
      nft.address,
      shady.address,
      account3.address,
      10001,
      10500,
      price,
      1,
      300,
      3,
    );
    await minter.deployed();

    await nft.connect(owner).setAuthorizedAddress(minter.address, true);
  });

  it("Successfully buys", async function () {
    await minter.connect(owner).mintReserve(1, owner.address);
    await minter.connect(owner).flipPauseStatus(); // open sale
    await shady.connect(account1).approve(minter.address, price);
    await minter.connect(account1).mint(1);
    expect(await shady.balanceOf(account3.address)).to.equal(price);
    expect(await nft.ownerOf(10002)).to.equal(account1.address);
    expect(await minter.nextId()).to.equal(10003);
  });

  it("Successfully mints 3", async function () {
    await minter.connect(owner).mintReserve(1, owner.address);
    await minter.connect(owner).flipPauseStatus(); // open sale
    await shady
      .connect(account1)
      .approve(minter.address, price.mul(ethers.BigNumber.from("4")));
    await minter.connect(account1).mint(2);
    await minter.connect(account1).mint(1);
    expect(await shady.balanceOf(account3.address)).to.equal(
      price.mul(ethers.BigNumber.from("3")),
    );
    expect(await nft.ownerOf(10002)).to.equal(account1.address);
    expect(await minter.nextId()).to.equal(10005);
    await expect(minter.connect(account1).mint(1)).to.be.revertedWith(
      "Exceeds max mint amount",
    );
  });

  it("Reverts minting pass mint amount", async function () {
    await minter.connect(owner).mintReserve(1, owner.address);
    await minter.connect(owner).flipPauseStatus(); // open sale
    await shady
      .connect(account1)
      .approve(minter.address, price.mul(ethers.BigNumber.from("4")));
    await expect(minter.connect(account1).mint(4)).to.be.revertedWith(
      "Exceeds max mint amount",
    );
  });
});
