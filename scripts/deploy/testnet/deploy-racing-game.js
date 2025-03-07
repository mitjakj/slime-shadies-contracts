const hre = require("hardhat");

async function main() {
    const addresses = hre.config.projectAddresses;
    const mainMinter = addresses.TESTNET_MAIN_MINTER;
    const devAddress = addresses.TESTNET_DEPLOYER;
    const shadyAddress = addresses.TESTNET_SHADY_TOKEN;
    const collection = addresses.TESTNET_NFT_COLLECTION;
    const staking = addresses.TESTNET_NFT_STAKING;

    const GameContract = await hre.ethers.getContractFactory("Racing_Game");
    let contract = await GameContract.deploy(
        mainMinter,
        shadyAddress,
        devAddress,
        collection,
        staking
    );
    await contract.deployed();

    console.log("GameContract deployed to: %saddress/%s", hre.network.config.explorer, contract.address);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
