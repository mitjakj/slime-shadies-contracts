const hre = require("hardhat");

async function main() {
    const addresses = hre.config.projectAddresses;
    const collection = addresses.MAINNET_NFT_COLLECTION;
    const shady_token = addresses.MAINNET_SHADY_TOKEN;
    const dev_address = addresses.MAINNET_DEPLOYER;

    const NFTStaking = await hre.ethers.getContractFactory("NFT_Staking");
    let contract = await NFTStaking.deploy(
        collection,
        shady_token,
        dev_address,
    );
    await contract.deployed();

    console.log("NFTStaking deployed to: %saddress/%s", hre.network.config.explorer, contract.address);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
