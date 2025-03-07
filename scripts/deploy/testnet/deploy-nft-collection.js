const hre = require("hardhat");

async function main() {
    const addresses = hre.config.projectAddresses;
    const royalties = addresses.TESTNET_ROYALTIES;

    const NFTContract = await hre.ethers.getContractFactory("NFT");
    let nft = await NFTContract.deploy(
        "SlimeShadies",
        "SlimeShadies",
        "https://slimeshadies.com/api-details/",
        royalties, // Royalties
        3250, //baseWeight
    );
    await nft.deployed();

    console.log("NFT Collection deployed to: %saddress/%s", hre.network.config.explorer, nft.address);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
