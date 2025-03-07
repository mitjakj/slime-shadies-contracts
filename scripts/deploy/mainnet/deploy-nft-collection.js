const hre = require("hardhat");

async function main() {
    const addresses = hre.config.projectAddresses;
    const royalties = addresses.MAINNET_ROYALTIES;

    const NFTContract = await hre.ethers.getContractFactory("NFT");
    let nft = await NFTContract.deploy(
        "Slime Shady",
        "SLIME",
        "https://slimeshadies.com/api-metadata/",
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
