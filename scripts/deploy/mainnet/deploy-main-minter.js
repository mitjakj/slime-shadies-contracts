const hre = require("hardhat");

async function main() {
    const addresses = hre.config.projectAddresses;
    const collection = addresses.MAINNET_NFT_COLLECTION;

    const MinterContract = await ethers.getContractFactory("NFT_Minter");
    let minter = await MinterContract.deploy(collection);
    await minter.deployed();

    console.log("Main minter deployed to: %saddress/%s", hre.network.config.explorer, minter.address);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
