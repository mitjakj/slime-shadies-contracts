const hre = require("hardhat");

async function main() {
    const ShadyToken = await hre.ethers.getContractFactory("Shady_token");
    let contract = await ShadyToken.deploy();
    await contract.deployed();

    console.log("Shady_token deployed to: %saddress/%s", hre.network.config.explorer, contract.address);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
