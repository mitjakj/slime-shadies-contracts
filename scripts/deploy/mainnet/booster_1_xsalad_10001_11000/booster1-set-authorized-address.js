const hre = require("hardhat");

async function main() {
    const addresses = hre.config.projectAddresses;
    const collection = addresses.MAINNET_NFT_COLLECTION;
    const boosterMinter = addresses.MAINNET_BOOSTER_MINTER_1;

    const signer = (await hre.ethers.getSigners())[0]
    const contract = await hre.ethers.getContractAt('NFT', collection, signer)
    let succ = await contract.setAuthorizedAddress(boosterMinter, true);

    console.log("Result: %s", succ);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
