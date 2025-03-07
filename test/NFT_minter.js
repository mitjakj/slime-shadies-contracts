const { expect } = require("chai");

// TODO: for test set premint to 1, presale to 3, max to 10
describe("NFT_Minter", function () {
  let nft, minter, owner, account1, account2, account3;
  const baseWeight = 3250;
  const price = ethers.BigNumber.from("1250000000000000000"); // 1.25 AVAX
  const presalePrice = ethers.BigNumber.from("900000000000000000"); // 0.9 AVAX
  before(async () => {
    await hre.network.provider.send("hardhat_reset");
  });

  beforeEach(async () => {
    const NFTContract = await ethers.getContractFactory("NFT");
    const MinterContract = await ethers.getContractFactory("NFT_Minter");
    [owner, account1, account2, account3] = await ethers.getSigners();
    nft = await NFTContract.deploy(
      "Slime shadies",
      "SS",
      "https://api.test.finance/NFT/metatadata/",
      account1.address,
      baseWeight,
    );
    await nft.deployed();

    minter = await MinterContract.deploy(nft.address);
    await minter.deployed();

    await nft.connect(owner).setMainMinterAddress(minter.address);
  });

  it("Reverts trying to buy before sale open.", async function () {
    await expect(
      minter.connect(account1).mint(1, { value: presalePrice }),
    ).to.be.revertedWith("Sale not opened.");
  });

  it("Reverts trying to in presale sale when not whitelisted.", async function () {
    await minter.connect(owner).setSaleState(1);
    await expect(
      minter.connect(account1).mint(1, { value: presalePrice }),
    ).to.be.revertedWith("Not whitelisted.");
  });

  it("Successfully freemints", async function () {
    await minter.connect(owner).mintReserve(1, owner.address);

    await minter.connect(owner).freelistUsers([account1.address]);
    await expect(minter.connect(account1).freeMint()).to.be.revertedWith(
      "Freemint not opened.",
    );
    await minter.connect(owner).setSaleState(1);

    await minter.connect(account1).freeMint();
    expect(await nft.ownerOf(2)).to.equal(account1.address);
    expect(await minter.nextId()).to.equal(3);
  });

  it("Reverts freemint when not freelisted.", async function () {
    await minter.connect(owner).mintReserve(1, owner.address);
    await minter.connect(owner).setSaleState(1);

    await expect(minter.connect(account1).freeMint()).to.be.revertedWith(
      "Not freelisted.",
    );
  });

  it("Successfully buys in presale", async function () {
    await minter.connect(owner).mintReserve(1, owner.address);
    await minter.connect(owner).setSaleState(1);
    await minter.connect(owner).whitelistUsers([account1.address]);
    await minter.connect(account1).mint(1, { value: presalePrice });
    expect(await nft.ownerOf(2)).to.equal(account1.address);
    expect(await minter.nextId()).to.equal(3);
    expect(await minter.provider.getBalance(minter.address)).to.equal(
      // 15%
      presalePrice
        .mul(ethers.BigNumber.from("15"))
        .div(ethers.BigNumber.from("100")),
    );
    await minter.connect(account1).mint(1, { value: presalePrice });
    await expect(
      minter.connect(account1).mint(1, { value: presalePrice }),
    ).to.be.revertedWith("Not whitelisted.");
  });

  it("Reverts exceeding presale amount", async function () {
    await minter.connect(owner).mintReserve(1, owner.address);
    await minter.connect(owner).setSaleState(1);
    await minter.connect(owner).whitelistUsers([account1.address]);
    await expect(
      minter.connect(account1).mint(3, { value: presalePrice }),
    ).to.be.revertedWith("Mint amount exceeded max presale mint amount.");
  });

  it("Successfully buys in sale for presale price and claim rewards by transfering nft", async function () {
    await minter.connect(owner).mintReserve(1, owner.address);
    await minter.connect(owner).freelistUsers([account1.address]);
    await minter.connect(owner).setSaleState(2);
    await minter
      .connect(account1)
      .mint(3, { value: presalePrice.mul(ethers.BigNumber.from("3")) });

    const pre = await minter.provider.getBalance(account1.address);
    await nft
      .connect(account1)
      .transferFrom(account1.address, account2.address, 2);

    const post = await minter.provider.getBalance(account1.address);
    console.log(
      presalePrice
        .mul(ethers.BigNumber.from("15"))
        .div(ethers.BigNumber.from("100")),
    );
    console.log(post.sub(pre));

    await nft
      .connect(account1)
      .transferFrom(account1.address, account2.address, 3);

    await minter.connect(account1).freeMint();

    await nft
      .connect(account1)
      .transferFrom(account1.address, account2.address, 4);

    await nft
      .connect(account2)
      .transferFrom(account2.address, account1.address, 4);
  });
});
