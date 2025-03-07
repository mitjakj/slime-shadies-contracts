const { expect } = require("chai");

// TODO: for test set premint to 1, presale to 3, max to 10
describe("NFT_Booster_Minter_OM_Claim", function () {
  let nft, minter, boosterMinter, owner, account1, account2, account3;
  const baseWeight = 3250;
  const price = ethers.BigNumber.from("1250000000000000000"); // 1.25 AVAX
  const presalePrice = ethers.BigNumber.from("900000000000000000"); // 0.9 AVAX
  const boosterPrice = ethers.BigNumber.from("10000000000000000000"); // 10 Shady tokens
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
    await minter.connect(owner).mintReserve(50, owner.address);
    await minter.connect(owner).setSaleState(2);

    const ShadyContact = await ethers.getContractFactory("Shady_token");
    shady = await ShadyContact.deploy();
    await shady.deployed();
    await shady
      .connect(owner)
      .transfer(account1.address, price.mul(ethers.BigNumber.from("2000")));

    const MinterBoosterContract = await ethers.getContractFactory(
      "NFT_Booster_Minter_OM_Claim",
    );
    boosterMinter = await MinterBoosterContract.deploy(
      nft.address,
      shady.address,
      account3.address,
      10001,
      10500,
      price,
      1,
      300,
      3,
      minter.address,
    );
    await boosterMinter.deployed();

    await nft.connect(owner).setAuthorizedAddress(boosterMinter.address, true);
  });

  it("Successfully claims", async function () {
    await minter.connect(account1).mint(1, { value: presalePrice });
    await minter.connect(account1).mint(1, { value: presalePrice });
    await boosterMinter.connect(account1).claim();
    expect(await nft.ownerOf(10001)).to.equal(account1.address);
    expect(await nft.balanceOf(account1.address)).to.equal(3);

    await expect(boosterMinter.connect(account1).claim()).to.be.revertedWith(
      "Already claimed",
    );
  });

  it("Claims nothing if not a minter", async function () {
    await boosterMinter.connect(account1).claim();
    expect(await nft.balanceOf(account1.address)).to.equal(0);
  });

  // SET next id to 2501 in nft_minter before running this test
  it("Claims nothing id above 2500", async function () {
    await minter.connect(account1).mint(1, { value: price });
    await boosterMinter.connect(account1).claim();
    expect(await nft.balanceOf(account1.address)).to.equal(1);
  });
});
