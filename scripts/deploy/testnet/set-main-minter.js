const hre = require("hardhat");

async function main() {
    const addresses = hre.config.projectAddresses;
    const collection = addresses.TESTNET_NFT_COLLECTION;
    const mainMinter = addresses.TESTNET_MAIN_MINTER;

    const signer = (await hre.ethers.getSigners())[0]
    const contract = await hre.ethers.getContractAt('NFT', collection, signer)
    let succ = await contract.setMainMinterAddress(mainMinter);

    console.log("Result: %s", succ);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
