const hre = require("hardhat");

async function main() {
    const addresses = hre.config.projectAddresses;
    const collection = addresses.MAINNET_NFT_COLLECTION;
    const staking = addresses.MAINNET_NFT_STAKING;

    const signer = (await hre.ethers.getSigners())[0]
    const contract = await hre.ethers.getContractAt('NFT', collection, signer)
    let succ = await contract.setStakingAddress(staking);

    console.log("Result: %s", succ);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
