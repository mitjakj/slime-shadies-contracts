const hre = require("hardhat");

async function main() {
    const addresses = hre.config.projectAddresses;
    const mainMinter = addresses.MAINNET_MAIN_MINTER;
    const devAddress = addresses.MAINNET_DEPLOYER;
    const shadyAddress = addresses.MAINNET_SHADY_TOKEN;

    const GameContract = await hre.ethers.getContractFactory("Racing_Game");
    let contract = await GameContract.deploy(
        mainMinter,
        shadyAddress,
        devAddress,
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
