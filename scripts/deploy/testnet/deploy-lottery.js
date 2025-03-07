const hre = require("hardhat");

async function main() {
    const addresses = hre.config.projectAddresses;
    const mainMinter = addresses.TESTNET_MAIN_MINTER;
    const devAddress = addresses.TESTNET_DEPLOYER;
    const shadyAddress = addresses.TESTNET_SHADY_TOKEN;

    const GameContract = await hre.ethers.getContractFactory("Lottery");
    let contract = await GameContract.deploy(
        mainMinter,
        shadyAddress,
        devAddress,
    );
    await contract.deployed();

    console.log("Lottery deployed to: %saddress/%s", hre.network.config.explorer, contract.address);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
